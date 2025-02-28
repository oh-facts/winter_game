// TODO(mizu): complete texture hash
// Make it async
// Let art be a higher level layer that handles
// the frame x, frame y, etc. kind of stuff
// make an editor for it too?
// Later. Just ahrdcode for now.
// Look at other engines rq

#import "Basic";
#import "String";
#import "meow_hash";
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
	data : string;
	data_arena : *Arena;
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
	free_key : *Key_Slot;
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
		slots.data = push_array(arena, Slot, slots.count);
		
		key_slots.count = 1024;
		key_slots.data = push_array(arena, Key_Slot, key_slots.count);
	}
}

hash :: (data : string) -> u128 {
	
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
	next : *Touch;
	
	while touch {
		
		defer touch = next;
		next := touch.next;
		
		hash := touch.hash;
		slot_index := hash.U64[1] % state.slots.count;
		slot := state.slots + slot_index;
		
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

hash_from_key_data :: (key : u128, data : string, data_arena : *Arena) {
	hash := hash(data);
	slot_index := hash.U64[1] % state.slots.count;
	slot := state.slots.data + slot_index;
	
	node : *Node;
	
	// check if node already exists
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
	
	
	// duplicate, so delete
	if node {
		arena_free(data_arena);
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
		
		node.hash = hash;
		node.key = key;
		
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
		
		
	}
	
}