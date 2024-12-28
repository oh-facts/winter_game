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

ParentNode :: struct {
	next : *ParentNode;
	v : *Widget;
}

push_parent_node :: (state : *State, parent : *Widget) {
	
	node : *ParentNode = xx tpush_struct(ParentNode);
	node.v = parent;
	
	state.parent_stack.top.next = node;
	state.parent_stack.top = node;
}

pop_parent_node :: (state : *State) {
	
	state.parent_stack.top = state.parent_stack.top.next;
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
	last_frame_touched_index : u64;
	
	// debug
	id : u32;
	
	// styling
	color : Vector4;
	border_thickness : float32;
	radius : float32;
	pref_size : [Axis2.COUNT]Size;
	text : string;
	
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
	
	parent_stack : struct {
		top : *ParentNode;
		free : *ParentNode;
		auto_pop : bool;
	};
	
	root : *Widget;
}

init :: () -> *State {
	arena := arena_init();
	state : *State= push_struct(arena, State);
	state.arena = arena;
	
	state.slots = cast, force([]Slot) push_array(arena, Slot, 1024);
	
	widget : *Widget = push_struct(arena, Widget);
	widget_node : *ParentNode = push_struct(arena, ParentNode);
	widget_node.v = widget;
	state.parent_stack.top = widget_node;
	state.root = widget;
	
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
				<<out = .{};
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
		if(out.last_frame_touched_index == state.frame_index)
		{
			out = tzpush_struct(Widget);
		}
	}
	
	// per frame
	{
		out.prev = xx 0;
		out.last = xx 0;
		out.next = xx 0;
		out.last_frame_touched_index = state.frame_index;
		out.computed_size[0] = 0;
		out.computed_size[1] = 0;
		
		out.computed_rel_position[0] = 0;
		out.computed_rel_position[1] = 0;
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
	widget.text = text;
	out := signal(widget);
	
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
		case .Pixels;
		root.computed_size[axis] = root.pref_size[axis].value;
	}
	
	//root.computed_size[axis] += root.padding[axis];
}

/*
function void ui_layout_upward_dependent(UI_Widget *root, Axis2 axis)
{
	if(root->pref_size[axis].kind == UI_SizeKind_PercentOfParent)
	{
		if(root->parent->pref_size[axis].kind != UI_SizeKind_ChildrenSum)
		{
			
		}
		
	}
	
	for(UI_Widget *child = root->first; child; child = child->next)
	{
		ui_layout_upward_dependent(child, axis);
	}
}

function void ui_layout_downward_dependent(UI_Widget *root, Axis2 axis)
{
	for(UI_Widget *child = root->first; child; child = child->next)
	{
		ui_layout_downward_dependent(child, axis);
	}
	
	if(root->pref_size[axis].kind == UI_SizeKind_ChildrenSum)
	{
		f32 size = 0;
		for(UI_Widget *child = root->first; child; child = child->next)
		{
			if(child->flags & UI_Flags_is_floating)
			{
				child->computed_size[1] += 10;
				continue;
			}
			if(root->child_layout_axis == axis)
			{
				size += child->computed_size[axis];
			}
			else
			{
				size = Max(size, child->computed_size[axis]);
			}
		}
		root->computed_size[axis] += size;
	}
}

function void ui_layout_pos(UI_Widget *root)
{
	f32 layout_pos = 0;
	
	for(UI_Widget *child = root->first; child; child = child->next)
	{
		child->computed_rel_position[0] += root->computed_rel_position[0];
		child->computed_rel_position[1] += root->computed_rel_position[1];
		
		child->computed_rel_position[0] += child->padding[0];
		child->computed_rel_position[1] += child->padding[1];
		
		if(!(child->flags & UI_Flags_is_floating))
		{
			Axis2 axis = root->child_layout_axis;
			child->computed_rel_position[axis] += layout_pos;
			
			layout_pos += child->computed_size[axis];
		}
		
		v2f pos = {{child->computed_rel_position[0], child->computed_rel_position[1]}};
		v2f size = {{child->computed_size[0], child->computed_size[1]}};
		
		child->dst = rect(pos, size);
	}
	
	for (UI_Widget *child = root->first; child; child = child->next)
	{
		ui_layout_pos(child);
	}
}
*/

layout :: (root : *Widget) {
	for axis : 0 .. Axis2.COUNT - 1 {
		layout_fixed_size(root, axis);
		//ui_layout_upward_dependent(root, axis);
		//ui_layout_downward_dependent(root, axis);
	}
	
	//ui_layout_pos(root);
	//ui_print_nodes_pre_order(root, 0);
	//printf("\n");
}

begin :: (state : *State) {
	//cxt->win = win;
	
	state.frame_index+=1;
}

end :: (state : *State) {
	//ui_pop_parent(state);
	
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