// TODO(mizu): I am thinking ui layer has keys instead of ids.
// the editor layer can make use of owner, index, item, window id, etc. to make produce different keys. The question is, how do i resolve collisions? Since the ui layer wont know how the keys are produced? A) callback to resolve collisions. B) opaque ids?
// so UI_ID becomes u32[6] for eg. and high level layers can adjust as they see fit. I like this idea more.

// i did the write. there are leaks probably. will get to it when i run out of memory / next cleanup pass. whichever comes first.

UI_ID :: struct {
	v : [2]u64;
}

UI_Axis :: enum {
	X;
	Y;
	COUNT;
}

UI_Size_Kind :: enum {
	TextContent;
	Pixels;
	Null;
	PercentOfParent;
	ChildrenSum;
}

UI_Size :: struct {
	kind : UI_Size_Kind;
	value : float32;
	strictness : float32;
}

UI_Flags :: enum_flags u32 {
	Text;
	Bg;
	Border;
	BorderRadius;
	Clickable;
	CustomDraw;
	FloatingX;
	FloatingY;
	Check_Box;
	Image;
	Slider;
	Scissor;
}

UI_Floating :: UI_Flags.FloatingX | UI_Flags.FloatingY;

UI_Signal :: struct {
	widget : *UI_Widget;
	hot : bool;
	active : bool;
	toggle : bool;
}

UI_Widget :: struct {
	// tree
	first : *UI_Widget;
	last : *UI_Widget;
	next : *UI_Widget;
	prev : *UI_Widget;
	parent : *UI_Widget;
	child_count : u32;
	
	flags : UI_Flags;
	
	// cache info
	hash_next : *UI_Widget;
	key : UI_ID;
	last_frame_touched_index : u64;
	
	// styling =========
	
	// common
	color : Vector4;
	bg_color : Vector4;
	border_thickness : float32;
	radius : float32;
	pref_size : [UI_Axis.COUNT]UI_Size;
	fixed_size : Vector2;
	
	child_layout_axis : UI_Axis;
	text : string;
	font : r.Font;
	
	offset : [UI_Axis.COUNT]float32;
	scissor : RectF32;
	
	// checkbox
	checked : bool;
	
	// slider
	value : float;
	
	// image
	image : r.Handle;
	src : RectF32;
	
	// calculated after hierearchy pass
	computed_rel_position : [UI_Axis.COUNT]float32;
	computed_size : [UI_Axis.COUNT]float32;
	
	// persistant
	dst : RectF32;
	pos : Vector2;
	size : Vector2;
	
	hot : bool;
	active : bool;
	toggle : bool;
}

Slot :: struct {
	first : *UI_Widget;
	last : *UI_Widget;
}

ui_init :: () -> *UI_State {
	arena := arena_init();
	state : *UI_State= push_struct(arena, UI_State);
	state.arena = arena;
	
	state.slots.data = push_array(arena, Slot, 1024);
	state.slots.count = 1024;
	return state; 
}

operator == :: (a : UI_ID, b : UI_ID) -> bool {
	return (memcmp(*a, *b, size_of(UI_ID)) == 0);
}

hash_from_key :: (key : UI_ID) -> int {
	hash := 5381;
	
	for 0 .. 1 {
		hash = ((hash << 5) + hash) + xx key.v[it];
	}
	
	return hash;
}

widget_lookup :: (state : *UI_State, key : UI_ID) -> *UI_Widget {
	slot_index := hash_from_key(key) % xx state.slots.count;
	slot := state.slots.data + slot_index;
	out : *UI_Widget;
	
	cur := slot.first;
	while cur {
		if cur.key == key {
			out = cur;
			break;
		}
		
		cur = cur.hash_next;
	}
	
	return out;
}

key_is_null :: (key : UI_ID) -> bool {
	NULL_UI_ID : UI_ID : .{}; 
	return (memcmp(*key, *NULL_UI_ID, size_of(UI_ID)) == 0);
}

ui_widget_from_key :: (state : *UI_State, key : UI_ID) -> *UI_Widget {
	
	// check cache if widget already exists
	out := widget_lookup(state, key);
	
	// not found in cache, allocate
	if !out {
		// allocate from frame arena
		if key_is_null(key) {
			out = tzpush_struct(UI_Widget);
		}
		// don't
		else {
			// check free list, or allocate new
			out = state.free;
			if !out {
				out = push_struct(state.arena, UI_Widget);
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
			out = tzpush_struct(UI_Widget);
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
		//out.color = state.color_stack.top.v;
		//out.border_color = state.border_color_stack.top.v;
		//out.border_thickness = state.border_thickness_stack.top.v;
		//out.radius = state.radius_stack.top.v;
		out.pref_size[0] = state.size_x_stack.top.v;
		out.pref_size[1] = state.size_y_stack.top.v;
		
		out.fixed_size.x = state.width_stack.top.v;
		out.fixed_size.y = state.height_stack.top.v;
		out.offset = state.offset_stack.top.v;
		out.scissor = state.scissor_stack.top.v;
		out.flags |= state.flags_stack.top.v;
	}
	
	//RectF32 extent = rectFromString(out->text, out->scale);
	
	return out;
}

ui_signal :: (state : *UI_State, widget : *UI_Widget) -> UI_Signal {
	out : UI_Signal;
	out.widget = widget;
	
	if point_in_rect(state.mpos, widget.dst) {
		widget.hot = true;
		
		if os.event(state.events, .LMB, .Pressed) {
			widget.active = true;
			widget.toggle = !widget.toggle;
		}
		
	}
	
	out.hot = widget.hot;
	out.active = widget.active;
	out.toggle = widget.toggle;
	return out;
}

ui_widget_impl :: (state : *UI_State, text : string, flags : UI_Flags, key : UI_ID) -> UI_Signal {
	
	widget := ui_widget_from_key(state, key);
	widget.flags |= flags;
	widget.text = text;
	
	out := ui_signal(state, widget);
	
	return out;
}

ui_layout_fixed_size :: (root : *UI_Widget, axis : UI_Axis) {
	
	{
		child := root.first;
		while child {
			ui_layout_fixed_size(child, axis);
			
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
	
}

ui_layout_upward_dependent :: (root : *UI_Widget, axis : UI_Axis) {
	
	if root.pref_size[axis].kind == .PercentOfParent {
		
		fixed_parent : *UI_Widget;
		
		{
			p := root.parent;
			while p {
				
				if p.pref_size[axis].kind == .Pixels {
					fixed_parent = p;
				}
				
				p = p.parent;
			}
		}
		
		if fixed_parent {
			root.computed_size[axis] = fixed_parent.computed_size[axis] * root.pref_size[axis].value;
		}
		
	}
	
	
	{
		child := root.first;
		while child {
			ui_layout_upward_dependent(child, axis);
			child = child.next;
		}
	}
	
}

ui_layout_downward_dependent :: (root : *UI_Widget, axis : UI_Axis) {
	
	{
		child := root.first;
		while child {
			ui_layout_downward_dependent(child, axis);
			child = child.next;
		}
	}
	
	if root.pref_size[axis].kind == .ChildrenSum {
		size := 0.;
		
		{
			child := root.first;
			
			while child {
				defer child = child.next;
				
				if child.flags & UI_Floating {
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

ui_layout_pos :: (root : *UI_Widget) {
	
	lay_pos : float32 = root.offset[root.child_layout_axis];
	
	{
		child := root.first;
		while child {
			defer child = child.next;
			
			child.computed_rel_position[0] += root.computed_rel_position[0];
			child.computed_rel_position[1] += root.computed_rel_position[1];
			
			if(!(child.flags & UI_Floating)) {
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
			ui_layout_pos(child);
			child = child.next;
		}
	}
	
}

ui_layout :: (root : *UI_Widget) {
	for axis : 0 .. UI_Axis.COUNT - 1 {
		ui_layout_fixed_size(root, axis);
		ui_layout_upward_dependent(root, axis);
		ui_layout_downward_dependent(root, axis);
	}
	
	ui_layout_pos(root);
	//ui_print_nodes_pre_order(root, 0);
	//printf("\n");
}

ui_begin :: (state : *UI_State, events : *os.EventList, mpos : Vector2) {
	//cxt->win = win;
	state.mpos = mpos;
	state.frame_index+=1;
	state.events = events;
	
	widget : *UI_Widget = tzpush_struct(UI_Widget);
	widget.child_layout_axis = .X;
	widget_node : *UI_Parent_Node = tzpush_struct(UI_Parent_Node);
	
	widget_node.v = widget;
	state.parent_stack.top = widget_node;
	state.root = widget;
	
	state.root.child_count = 0;
	
	ui_push_offset_node(state, .[0, 0]);
	ui_push_width_node(state, 0);
	ui_push_height_node(state, 0);
	ui_push_size_node(state, ui_size_txt());
	ui_push_scissor_node(state, .{});
	ui_push_flags_node(state, 0);
}

ui_size_txt :: (strictness := 1.) -> UI_Size {
	return UI_Size.{.TextContent, 0, strictness};
}

ui_size_px :: (px : float, strictness := 1.) -> UI_Size {
	return UI_Size.{.Pixels, px, strictness};
}

ui_size_pct :: (px : float, strictness := 1.) -> UI_Size {
	return UI_Size.{.PercentOfParent, px, strictness};
}

ui_size_children_sum :: (strictness := 1.) -> UI_Size {
	return UI_Size.{.ChildrenSum, 0, strictness};
}

ui_end :: (state : *UI_State) {
	ui_pop_parent_node(state);
	ui_pop_offset_node(state);
	ui_pop_width_node(state);
	ui_pop_height_node(state);
	ui_pop_size_node(state);
	ui_pop_scissor_node(state);
	ui_pop_flags_node(state);
	
	for i : 0 .. state.slots.count - 1 {
		first_hash := (state.slots.data + i).first;
		if !first_hash {
			continue;
		}
		if first_hash {
			cur := first_hash;
			prev : *UI_Widget;
			
			while cur {
				if cur.last_frame_touched_index != state.frame_index {
					//print("pruned %\n", cur.text);
					
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

ui_push_size_node :: (state : *UI_State, v : UI_Size) {
	ui_push_size_x_node(state, v);
	ui_push_size_y_node(state, v);
}

ui_pop_size_node :: (state : *UI_State) {
	ui_pop_size_x_node(state);
	ui_pop_size_y_node(state);
}