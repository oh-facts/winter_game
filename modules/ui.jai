// TODO(mizu): I am thinking ui layer has keys instead of ids.
// the editor layer can make use of owner, index, item, window id, etc. to make produce different keys. The question is, how do i resolve collisions? Since the ui layer wont know how the keys are produced? A) callback to resolve collisions. B) opaque ids?
// so UI_ID becomes u32[6] for eg. and high level layers can adjust as they see fit. I like this idea more.

// i did the write. there are leaks probably. will get to it when i run out of memory / next cleanup pass. whichever comes first.

#import "Math";
#import "mizu_base";
r :: #import "render";

padding : float32 : 8;

ID :: struct {
	v : [2]u64;
}

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
	TextContent;
	Pixels;
	Null;
	PercentOfParent;
	ChildrenSum;
}

Size :: struct {
	kind : SizeKind;
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

ParentNode :: struct {
	next : *ParentNode;
	v : *Widget;
}

PaddingNode :: struct {
	next : *PaddingNode;
	v : [2]float32;
}

push_parent_node :: (state : *State, parent : *Widget) {
	
	node : *ParentNode = xx tpush_struct(ParentNode);
	node.v = parent;
	
	node.next = state.parent_stack.top;
	state.parent_stack.top = node;
	
	i__i :: 0;
}

pop_parent_node :: (state : *State) {
	
	state.parent_stack.top = state.parent_stack.top.next;
}

push_padding_node :: (state : *State, padding : Vector2) {
	
	node : *PaddingNode = xx tpush_struct(PaddingNode);
	node.v = padding.component;
	
	node.next = state.padding_stack.top;
	state.padding_stack.top = node;
	
	i__i :: 0;
}

pop_padding_node :: (state : *State) {
	
	state.padding_stack.top = state.padding_stack.top.next;
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
	key : ID;
	last_frame_touched_index : u64;
	
	// styling
	color : Vector4;
	border_thickness : float32;
	radius : float32;
	pref_size : [Axis2.COUNT]Size;
	child_layout_axis : Axis2;
	text : string;
	font : r.Font;
	padding : [Axis2.COUNT]float32;
	// calculated after hierearchy pass
	computed_rel_position : [Axis2.COUNT]float32;
	computed_size : [Axis2.COUNT]float32;
	
	// persistant
	dst : RectF32;
	pos : Vector2;
	size : Vector2;
	font_size : float32;
	
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
	mpos : Vector2;
	mdown : bool;
	
	parent_stack : struct {
		top : *ParentNode;
		free : *ParentNode;
		auto_pop : bool;
	};
	
	padding_stack : struct {
		top : *PaddingNode;
		free : *PaddingNode;
		auto_pop : bool;
	};
	
	root : *Widget;
}

init :: () -> *State {
	arena := arena_init();
	state : *State= push_struct(arena, State);
	state.arena = arena;
	
	state.slots.data = push_array(arena, Slot, 1024);
	state.slots.count = 1024;
	return state; 
}

operator == :: (a : ID, b : ID) -> bool {
	return (memcmp(*a, *b, size_of(ID)) == 0);
}

hash_from_key :: (key : ID) -> int {
	hash := 5381;
	
	for 0 .. 1 {
		hash = ((hash << 5) + hash) + xx key.v[it];
	}
	
	return hash;
}

widget_lookup :: (state : *State, key : ID) -> *Widget {
	slot_index := hash_from_key(key) % xx state.slots.count;
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

key_is_null :: (key : ID) -> bool {
	NULL_ID : ID : .{}; 
	return (memcmp(*key, *NULL_ID, size_of(ID)) == 0);
}

widget_from_key :: (state : *State, key : ID) -> *Widget {
	
	// check cache if widget already exists
	out := widget_lookup(state, key);
	
	// not found in cache, allocate
	if !out {
		// allocate from frame arena
		if key_is_null(key) {
			out = tzpush_struct(Widget);
		}
		// don't
		else {
			// check free list, or allocate new
			out = state.free;
			if !out {
				out = push_struct(state.arena, Widget);
			}
			else {
				state.free = state.free.next;
				<<out = .{};
			}
			
			// add to cache
			slot_index := hash_from_key(key) % xx state.slots.count;
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
		if(out.last_frame_touched_index == state.frame_index)
		{
			out = tzpush_struct(Widget);
		}
	}
	
	// per frame
	{
		out.key = key;
		out.child_count = 0;
		out.prev = xx 0;
		out.last = xx 0;
		out.next = xx 0;
		out.last_frame_touched_index = state.frame_index;
		out.computed_size[0] = 0;
		out.computed_size[1] = 0;
		
		out.computed_rel_position[0] = 0;
		out.computed_rel_position[1] = 0;
		out.hot = false;
		out.active = false;
	}
	
	// tree links
	
	{
		parent := state.parent_stack.top.v;
		parent.child_count += 1;
		out.parent = parent;
		
		if(!parent.last)
		{
			parent.first = out;
			parent.last = out;
		}
		else
		{
			out.prev = parent.last;
			parent.last.next = out;
			parent.last = out;
		}
	}
	
	
	// styling
	{
		out.padding = state.padding_stack.top.v;
		//out.color = state.color_stack.top.v;
		//out.border_color = state.border_color_stack.top.v;
		//out.border_thickness = state.border_thickness_stack.top.v;
		//out.radius = state.radius_stack.top.v;
	}
	
	out.pref_size[0].value = 60;
	out.pref_size[1].value = 30;
	
	//RectF32 extent = rectFromString(out->text, out->scale);
	
	return out;
}

signal :: (state : *State, widget : *Widget) -> Signal {
	out : Signal;
	out.widget = widget;
	
	if point_in_rect(state.mpos, widget.dst) {
		widget.hot = true;
		
		if state.mdown {
			widget.active = true;
			widget.toggle = !widget.toggle;
		}
		
	}
	
	out.hot = widget.hot;
	out.active = widget.active;
	out.toggle = widget.toggle;
	return out;
}

widget_impl :: (state : *State, text : string, key : ID) -> Signal {
	
	widget := widget_from_key(state, key);
	widget.flags |= .Text;
	widget.text = text;
	
	out := signal(state, widget);
	
	return out;
}

layout_fixed_size :: (root : *Widget, axis : Axis2) {
	
	{
		child := root.first;
		while child {
			layout_fixed_size(child, axis);
			
			child = child.next;
		}
	}
	
	if root.pref_size[axis].kind == {
		case ;
		case .Null;
		case .TextContent;
		dst := r.get_text_rect(font, root.text, .{}, 0.4);
		
		if axis == .X {
			root.computed_size[axis] = dst.max.x;
		} else if axis == .Y {
			root.computed_size[axis] = dst.max.y;
		}
		
		case .Pixels;
		root.computed_size[axis] = root.pref_size[axis].value;
	}
	
	root.computed_size[axis] += 16 ;//root.padding[axis];
}

layout_downward_dependent :: (root : *Widget, axis : Axis2) {
	
	{
		child := root.first;
		while child {
			layout_downward_dependent(child, axis);
			child = child.next;
		}
	}
	
	if root.pref_size[axis].kind == .ChildrenSum {
		size := 0.;
		
		{
			child := root.first;
			
			while child {
				defer child = child.next;
				
				if child.flags & Floating {
					child.computed_size[1] += 10;
					continue;
				}
				if root.child_layout_axis == axis {
					size += child.computed_size[axis];
				}
				else {
					size = max(size, child.computed_size[axis]);
				}
			}
			root.computed_size[axis] += size;
		}
		
	}
	
}

layout_pos :: (root : *Widget) {
	lay_pos : float32;
	
	{
		child := root.first;
		while child {
			defer child = child.next;
			
			child.computed_rel_position[0] += root.computed_rel_position[0];
			child.computed_rel_position[1] += root.computed_rel_position[1];
			
			child.computed_rel_position[0] += child.padding[0];
			child.computed_rel_position[1] += child.padding[1];
			
			if(!(child.flags & Floating)) {
				axis := root.child_layout_axis;
				child.computed_rel_position[axis] += lay_pos;
				
				lay_pos += child.computed_size[axis];
			}
			
			pos := Vector2.{child.computed_rel_position[0], child.computed_rel_position[1]};
			size := Vector2.{child.computed_size[0], child.computed_size[1]};
			
			dst : RectF32;
			dst.min = pos;
			dst.max = dst.min + size;
			
			child.dst = dst;
			child.pos = pos;
			child.size = size;
		}
	}
	
	{
		child := root.first;
		while child {
			layout_pos(child);
			child = child.next;
		}
	}
	
}

layout :: (root : *Widget) {
	for axis : 0 .. Axis2.COUNT - 1 {
		layout_fixed_size(root, axis);
		//ui_layout_upward_dependent(root, axis);
		layout_downward_dependent(root, axis);
	}
	
	layout_pos(root);
	//ui_print_nodes_pre_order(root, 0);
	//printf("\n");
}

font : *r.Font;

set_font :: (fonta : *r.Font) {
	font = fonta;
}

begin :: (state : *State, mpos : Vector2, mdown : bool) {
	//cxt->win = win;
	state.mpos = mpos;
	state.mdown = mdown;
	state.frame_index+=1;
	
	widget : *Widget = push_struct(state.arena, Widget);
	widget.child_layout_axis = .X;
	widget_node : *ParentNode = push_struct(state.arena, ParentNode);
	
	widget_node.v = widget;
	state.parent_stack.top = widget_node;
	state.root = widget;
	
	padding_node : *PaddingNode = push_struct(state.arena, PaddingNode);
	
	state.padding_stack.top = padding_node;
	
	state.root.child_count = 0;
}

end :: (state : *State) {
	pop_parent_node(state);
	pop_padding_node(state);
	
	for i : 0 .. state.slots.count - 1 {
		first_hash := (state.slots.data + i).first;
		if !first_hash {
			continue;
		}
		if first_hash {
			cur := first_hash;
			prev : *Widget;
			
			while cur {
				if cur.last_frame_touched_index != state.frame_index {
					//printf("pruned %.*s\n", str8_varg(cur->text));
					
					if prev {
						prev.hash_next = cur.hash_next;
						if !cur.hash_next {
							(state.slots.data + i).last = prev;
						}
					}
					else {
						(state.slots.data + i).first = cur.hash_next;
						if (!cur.hash_next) {
							(state.slots.data + i).last = xx 0;
						}
					}
					
					to_free := cur;
					cur = cur.hash_next;
					
					to_free.next = state.free;
					state.free = to_free;
				}
				else {
					prev = cur;
					cur = cur.hash_next;
				}
			}
		}
	}
	//printf("\n");
}