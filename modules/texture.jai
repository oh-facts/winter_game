// TODO(mizu):

// keys map to hashes and data
// hashes map to keys
// texture eviction happens when texture scope ends
// data eviction happens when key is returned
// I think I want to evolve this into an all purpose cache.

// Concepts borrowed (stolen) from the RAD debugger. I am trying to explore some ideas so I can make enough discoveries / possible improvements to be less of a leech.

// It is only so "async"
// submitting calls from different threads in opengl is pointless because they are still collected then submitted as one. The reading and freeing happens on a bg thread. For now, the worker loading (disk->ram) and freeing happens on one bg thread, and the way the code works, I don't really need much sync. I am probably wrong because I haven't explored multi threading alot and I have 0 people to discuss programming with. Everything I know about programming links back to RAD.

// When I use vulkan, I will try again. For testing, I just use a very big image (40mb as png, 1.5gb loaded), and I see if the main thread stalls at all.

#import "Basic";
#import "String";
#import "meow_hash";
#import "Thread";

#import "mizu_base";
r :: #import "render";

Key_Node :: struct {
	next : *Key_Node;
	prev : *Key_Node;
	key : u128;
	hash : u128;
}

Key_Slot :: struct {
	first : *Key_Node;
	last : *Key_Node;
}

Node :: struct {
	next : *Node;
	prev : *Node;
	hash : u128;
	
	v : r.Handle;
	
	tag : string;
	data : string;
	
	scope_ref_count : int;
	key_ref_count : int;
	loaded : bool;
	last_touched_tick : u64;
}

Slot :: struct {
	first : *Node;
	last : *Node;
}

Touch :: struct {
	next : *Touch;
	hash : u128;
}

Scope :: struct {
	next : *Scope;
	top_touch : *Touch;
}

State :: struct {
	arena : *Arena;
	
	slots : []Slot;
	key_slots : []Key_Slot;
	
	free : *Node;
	free_key : *Key_Node;
	free_scope : *Scope;
	free_touch : *Touch;
	
	ticks : u64;
}

state : *State;

init :: () {
	arena := arena_init();
	state = push_struct(arena, State);
	state.arena = arena;
	
	{
		using state;
		
		slots.count = 1024;
		slots.data = push_array(arena, Slot, xx slots.count);
		
		key_slots.count = 1024;
		key_slots.data = push_array(arena, Key_Slot, xx key_slots.count);
	}
	
}

hash_string :: (data : string) -> u128 {
	
#asm { hash: vec; }
	
	MeowHash(MeowDefaultSeed, xx data.count, data.data, hash);
	
	out : u128;
	out.U64[0] = MeowU64From(hash, 0);
	out.U64[1] = MeowU64From(hash, 1);
	
	return out;
}

scope_open :: () -> *Scope {
	out := state.free_scope;
	
	if !out {
		out = push_struct(state.arena, Scope);
	} else {
		state.free_scope = state.free_scope.next;
	}
	
	<< out = .{};
	
	return out;
}

scope_close :: (scope : *Scope) {
	touch := scope.top_touch;
	
	while touch {
		next := touch.next;
		
		defer touch = next;
		
		hash := touch.hash;
		slot_index := hash.U64[1] % xx state.slots.count;
		slot := state.slots.data + slot_index;
		
		node := slot.first;
		while node {
			defer node = node.next;
			
			if hash == node.hash {
				node.scope_ref_count -= 1;
				break;
			}
		}
		touch.next = state.free_touch;
		state.free_touch = touch;
	}
	scope.next = state.free_scope;
	state.free_scope = scope;
}

hash_from_key_data :: (tag : string, key : u128, data : string) -> u128 {
	out := hash_string(data);
	slot_index := out.U64[1] % xx state.slots.count;
	slot := state.slots.data + slot_index;
	
	node : *Node;
	
	// check if node already exists
	{
		cur := slot.first;
		while cur {
			defer cur = cur.next;
			
			if cur.hash == out {
				node = cur;
				break;
			}
		}
	}
	
	// duplicate, so delete
	if node {
		free(data);
	}
	
	// store
	else {
		node = state.free;
		
		if node {
			state.free = state.free.next;
		} else {
			node = push_struct(state.arena, Node);
		}
		
		<< node = .{};
		
		node.hash = out;
		node.data = data;
		
		if !slot.first {
			slot.first = node;
			slot.last = node;
		} else {
			node.prev = slot.last;
			slot.last.next = node;
			slot.last = node;
		}
		
	}
	
	node.key_ref_count += 1;
	
	// store key
	{
		key_slot_index := key.U64[1] % xx state.key_slots.count;
		key_slot := state.key_slots.data + key_slot_index;
		
		key_node : *Key_Node;
		
		// check store first
		{
			cur := key_slot.first;
			while cur {
				defer cur = cur.next;
				if cur.key == key {
					key_node = cur;
					break;
				}
			}
		}
		
		// create if doesn't exist
		
		if !key_node {
			key_node = state.free_key;
			
			if key_node {
				state.free_key = state.free_key.next;
			}
			else {
				key_node = push_struct(state.arena, Key_Node);
			}
			
			key_node.key = key;
			
			if !key_slot.first {
				key_slot.first = key_node;
				key_slot.last = key_node;
			} else {
				key_node.prev = key_slot.last;
				key_slot.last.next = key_node;
				key_slot.last = key_node;
			}
		}
		
		key_node.hash = out;
	}
	
	node.tag = tag;
	
	return out;
}

hash_from_key :: (scope : *Scope, key : u128) -> u128 {
	out : u128;
	key_slot_index := key.U64[1] % state.key_slots.count;
	key_slot := state.key_slots.data + key_slot_index;
	
	{
		cur : *Key_Slot;
		while cur {
			defer cur = cur.next;
			
			if cur.key == key {
				out = cur.hash;
				break;
			}
		}
	}
	
	return out;
}

handle_from_hash :: (scope : *Scope, hash : u128, params := r.Tex_Params.Nearest) -> r.Handle {
	out : r.Handle;
	
	slot_index := hash.U64[1] % xx state.slots.count;
	slot := state.slots.data + slot_index;
	
	node : *Node;
	
	{
		cur := slot.first;
		
		while cur {
			defer cur = cur.next;
			
			if cur.hash == hash {
				node = cur;
				break;
			}
		}
	}
	
	if node {
		node.scope_ref_count += 1;
		
		touch := state.free_touch;
		
		if !touch {
			touch = push_struct(state.arena, Touch);
		} else {
			state.free_touch = state.free_touch.next;
		}
		
		<< touch = .{};
		touch.hash = hash;
		touch.next = scope.top_touch;
		scope.top_touch = touch;
		
		if !node.loaded {
			//print("CPU Load Request %\n", node.tag);
			
			//print("loaded to ram %\n", work_node.tag);
			bmp := bitmap(node.data);
			node.v = r.image(bmp, params);
			node.loaded = true;
			bitmap_free(*bmp);
		}
		
		node.last_touched_tick = state.ticks;
		
		out = node.v;
		
	} else {
		// log and use default texture
	}
	
	return out;
}

clock_tick :: () {
	state.ticks += 1;
	//print("%\n", state.ticks);
}

evict_textures :: () -> int {
	
	if (state.ticks % 1650) == 0 {
		
		for slot : state.slots {
			node := slot.first;
			
			while node {
				defer node = node.next;
				
				if (node.scope_ref_count == 0) && (node.loaded) && (node.last_touched_tick + 10 < state.ticks) {
					r.free_image(node.v);
					node.loaded = false;
					print("% ; evicted % at %\n", state.ticks, node.tag, node.last_touched_tick);
				}
			}
		}
	}
	
	return 1;
}