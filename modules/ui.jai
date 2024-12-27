#import "Math";
#import "mizu_base";

Axis2 :: enum {
	X;
	Y;
	COUNT;
}

AlignKind :: enum {
	Left;
	Center;
	Right;
}

SizeKind :: enum {
	Null;
	Pixels;
	TextContent;
	PercentOfParent;
	ChildrenSum;
}

Size :: struct {
	kind : SizeKind ;
	value : float32;
	strictness : float32;
}

Flags :: enum_flags u32 {
	Text :: 1 << 0;
	Bg :: 1 << 1;
	Border :: 1 << 2;
	BorderRadius :: 1 << 3;
	Clickable :: 1 << 4;
	CustomDraw :: 1 << 5;
	FloatingX :: 1 << 7;
	FloatingY :: 1 << 8;
}

Floating :: Flags.FloatingX | Flags.FloatingY;

Signal :: struct {
	widget : *Widget;
	hot : bool;
	active : bool;
	toggle : bool;
}

Widget :: struct {
	// tree
	first : *Widget;
	last : *Widget;
	next : *Widget;
	prev : *Widget;
	parent : *Widget;
	child_count : u32;
	
	flags : Flags;
	
	// cache info
	hash_next : *Widget;
	key : u64;
	last_frame_touched : u64;
	
	// debug
	id : u32;
	
	// styling
	color : Vector4;
	border_thickness : float32;
	radius : float32;
	
	// calculated after hierearchy pass
	computed_rel_position : [Axis2.COUNT]float32;
	computed_size : [Axis2.COUNT]float32;
	
	// persistant
	dst : RectF32;
	hot : bool;
	active : bool;
	toggle : bool;
}

Slot :: struct {
	first : *Widget;
	last : *Widget;
}

State :: struct {
	arena : *Arena;
	slots : []Slot;
	frame_index : u64;
	free : *Widget;
	count : u32;
}

init :: () -> *State {
	arena := arena_init();
	state : *State= push_struct(arena, State);
	state.arena = arena;
	
	state.slots = cast, force([]Slot) push_array(arena, Slot, 1024);
	
	return state; 
}

// djb2
key_from_string :: (str : string) -> u64 {
	hash : u64;
	if str.count > 0 {
		hash = 5381;
		c : u64;
		
		for i: 0 .. str.count - 1 {
			c = str.data[i];
			hash = xx (xx (xx ( xx hash << 5) + hash) + c); /* hash * 33 + c */
		}
	}
	return hash;
}

widget_lookup :: (state : *State, key : u64) -> *Widget {
	slot_index := key % xx state.slots.count;
	slot := state.slots.data + slot_index;
	out : *Widget;
	
	cur := slot.first;
	while cur {
		if cur.key == key {
			out = cur;
			break;
		}
		
		cur = cur.next;
	}
	
	return out;
}

widget_from_key :: (state : *State, key : u64) -> *Widget {
	
	// check cache if widget already exists
	out := widget_lookup(state, key);
	
	// not found in cache, allocate
	if !out {
		// allocate from frame arena
		if key == 0 {
			out = tzpush_struct(Widget);
		}
		// don't
		else
		{
			// check free list, or allocate new
			out = state.free;
			if !out {
				out = push_struct(state.arena, Widget);
			}
			else {
				state.free = state.free.next;
			}
			
			// add to cache
			slot_index := key % xx state.slots.count;
			slot := state.slots.data + slot_index;
			
			if !slot.last {
				slot.first = out;
				slot.last = out;
			}
			else {
				slot.last.hash_next = out;
				slot.last = out;
			}
		}
	}
	else
	{
		// duplicate, allocate new from frame arena
		if(out.last_frame_touched == state.frame_index)
		{
			out = tzpush_struct(Widget);
		}
	}
	
	// per frame
	{
		out.prev = xx 0;
		out.last = xx 0;
		out.next = xx 0;
		out.last_frame_touched = state.frame_index;
		out.computed_size[0] = 0;
		out.computed_size[1] = 0;
		
		out.computed_rel_position[0] = 0;
		out.computed_rel_position[1] = 0;
	}
	
	// tree links
	/*
	{
		parent := state.parent_stack.top.v;
		parent.child_count += 1;
		out.parent = parent;
		
		if(!parent.last)
		{
			parent.last = parent.first = out;
		}
		else
		{
			out.prev = parent.last;
			parent.last = parent.last.next = out;
		}
	}
	*/
	// styling
	{
		//out.color = state.color_stack.top.v;
		//out.border_color = state.border_color_stack.top.v;
		//out.border_thickness = state.border_thickness_stack.top.v;
		//out.radius = state.radius_stack.top.v;
	}
	
	//RectF32 extent = rectFromString(out->text, out->scale);
	
	return out;
}

signal :: (widget : *Widget) -> Signal {
	out : Signal;
	out.widget = widget;
	out.hot = widget.hot;
	out.active = widget.active;
	out.toggle = widget.toggle;
	return out;
}

label :: (state : *State, text : string) -> Signal {
	key := key_from_string(text);
	widget := widget_from_key(state, key);
	widget.flags |= .Text;
	
	out := signal(widget);
	
	return out;
}