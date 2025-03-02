// TODO(mizu):

// keys map to hashes and data
// hashes map to keys
// texture eviction happens when texture scope ends
// data eviction happens when key is returned
// I think I want to evolve this into an all purpose cache.

// Concepts borrowed (stolen) from the RAD debugger. I am trying to explore some ideas so I can make enough discoveries / possible improvements to be less of a leech.

// It is only so "async"
// submitting calls from different threads in opengl is pointless because they are still collected then submitted as one. The reading and freeing happens on a bg thread. For now, the worker loading happens on one bg thread, and the way the code works, I don't really need snyc.

// When I use vulkan, I will try again. For testing, I just use a very big image (40mb as png, 1.5gb loaded), and I see if the main thread stalls at all.

#import "Basic";
#import "String";
#import "meow_hash";
#import "Thread";

#import "mizu_base";
r :: #import "render";

Work_Entry :: struct {
	hash : u64;
}

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
	
	is_loading : bool;
	work_next : *Node;
	loaded_in_ram : bool;
	bmp : Bitmap;
	work_kind : Work_Kind;
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
	
	load_tex_thread : Thread;
	
	work_queue_first: *Node;
	work_queue_last: *Node;
	
	work_count : int;
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
		
		
		thread_init(*load_tex_thread, do_work);
		thread_start(*load_tex_thread);
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

handle_from_hash :: (scope : *Scope, hash : u128) -> r.Handle {
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
		
		if !node.loaded && !node.is_loading && !node.loaded_in_ram {
			node.is_loading = true;
			//print("CPU Load Request %\n", node.tag);
			push_work(node, .Load_From_Disk);
		}
		
		if node.loaded_in_ram && !node.loaded {
			node.v = r.image(node.bmp);
			
			//print("CPU Free Request%\n", node.tag);
			push_work(node, .Free_From_Ram);
			node.loaded = true;
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

Work_Kind ::enum {
	Null;
	Load_From_Disk;
	Free_From_Ram;
}

push_work :: (node : *Node, work_kind : Work_Kind) {
	using state;
	
	if !work_queue_first {
		work_queue_last = node;
		work_queue_first = node;
	} else {
		work_queue_last.work_next = node;
		work_queue_last = node;
	}
	
	node.work_kind = work_kind;
	
	work_count += 1;
}

pop_work :: () -> *Node {
	using state;
	assert(work_count > 0);
	
	out : *Node;
	
	out = work_queue_first;
	
	work_queue_first = work_queue_first.work_next;
	
	work_count -= 1;
	
	return out;
}

do_work :: (thread : *Thread) -> int {
	while true {
		if state.work_count {
			
			work_node := pop_work();
			
			if work_node.work_kind == {
				case .Load_From_Disk;
				work_node.bmp = bitmap(work_node.data);
				
				work_node.is_loading = false;
				work_node.loaded_in_ram = true;
				//print("loaded to ram %\n", work_node.tag);
				
				case .Free_From_Ram;
				bitmap_free(*work_node.bmp);
				work_node.loaded_in_ram = false;
				//print("Freed from ram %\n", work_node.tag);
				case;
				assert(false);
			}
			
		}
	}
	return 1;
}

evict_textures :: (thread : *Thread) -> int {
	while true {
		for slot : state.slots {
			node := slot.first;
			
			while node {
				defer node = node.next;
				
				if (node.scope_ref_count == 0) && (node.loaded) && (node.last_touched_tick + 10 < state.ticks) && !node.is_loading {
					r.free_image(node.v);
					node.loaded = false;
					print("% ; evicted % at %\n", state.ticks, node.tag, node.last_touched_tick);
				}
			}
		}
		
		if !thread {
			break;
		}
		
	}
	return 1;
}