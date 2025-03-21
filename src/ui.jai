// TODO(mizu): I am thinking ui layer has keys instead of ids.
// the editor layer can make use of owner, index, item, window id, etc. to make produce different keys. The question is, how do i resolve collisions? Since the ui layer wont know how the keys are produced? A) callback to resolve collisions. B) opaque ids?
// so UI_ID becomes u32[6] for eg. and high level layers can adjust as they see fit. I like this idea more.

// i did the write. there are leaks probably. will get to it when i run out of memory / next cleanup pass. whichever comes first.

// Ok, so I need to make discrete non composable types there own "kind"

// also, i have erraneously referred to some widgets as fully discrete
// Based on usage code, a text edit is really just a bg + border + label + extra stuff.
// Hmm. Some extra rendering like cursor required tho.
// Still, I can offload those to flags.

// Make this a module?

// take flags out of the widget alloc function
// then generate the styling function

// widgets outside of bounds should not be drawn or process input

UI_ID :: struct {
	v : [5]u64;
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

UI_Text_Align :: enum {
	Middle;
	Left;
	Right;
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
	Text_Edit;
	Color_Picker;
	Shadow;
	Offset;
}

UI_Floating :: UI_Flags.FloatingX | UI_Flags.FloatingY;

UI_Signal :: struct {
	widget : *UI_Widget;
	hot : bool;
	active : bool;
	toggle : bool;
	focus : bool;
	text_edit : string;
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
	color : Vector4;
	bg_color : Vector4;
	hover_color : Vector4;
	border_color : Vector4;
	border_thickness : float32;
	radius : float32;
	pref_size : [UI_Axis.COUNT]UI_Size;
	text_padding : float32;
	
	// TODO(mizu): Use a 2d array for x and y align
	text_align : UI_Text_Align;
	
	child_layout_axis : UI_Axis;
	text : string;
	font : r.Font;
	
	offset : [UI_Axis.COUNT]float32;
	scissor : RectF32;
	// ================
	
	// TODO(mizu):  These are discrete types. I am unsure if I want to
	// put this in a union. I can't think of good reason to do it, 
	// because .... there's no reason.
	// Maybe once I have lots of discrete types, the amount of data
	// would be so high that it would be wasteful.
	// Now, there is very little overlap atm, but it is important to note
	// that these are very different and very widgets. I am sure that with
	// time, there will be beautiful overlap
	
	// discrete types =========
	
	// checkbox
	checked : bool;
	
	// slider
	value : float;
	
	// image
	image : r.Handle;
	src : RectF32;
	image_color : Vector4;
	
	// text edit
	text_edit_pos : int;
	// =========================
	
	// calculated during hierearchy pass
	computed_pos : [UI_Axis.COUNT]float32;
	computed_size : [UI_Axis.COUNT]float32;
	
	// persistent
	dst : RectF32;
	pos : Vector2;
	size : Vector2;
	
	hot : bool;
	active : bool;
	toggle : bool;
	focus : bool;
	focus_last : bool;
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
	
	for key.v {
		hash = ((hash << 5) + hash) + xx it;
	}
	
	return hash;
}

widget_lookup :: (key : UI_ID) -> *UI_Widget {
	slot_index := hash_from_key(key) % xx active_cxt.slots.count;
	slot := active_cxt.slots.data + slot_index;
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

ui_widget_from_key :: (key : UI_ID) -> *UI_Widget {
	
	// check cache if widget already exists
	out := widget_lookup(key);
	
	// not found in cache, allocate
	if !out {
		// allocate from frame arena
		if key_is_null(key) {
			out = tzpush_struct(UI_Widget);
		}
		// don't
		else {
			// check free list, or allocate new
			out = active_cxt.free;
			if !out {
				out = push_struct(active_cxt.arena, UI_Widget);
			}
			else {
				active_cxt.free = active_cxt.free.next;
				<<out = .{};
			}
			
			// add to cache
			slot_index := hash_from_key(key) % xx active_cxt.slots.count;
			slot := active_cxt.slots.data + slot_index;
			
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
		if(out.last_frame_touched_index == active_cxt.frame_index)
		{
			out = tzpush_struct(UI_Widget);
		}
	}
	
	// per frame
	// NOTE(mizu): Which of these should be zeroed out, and which doesn't???
	{
		out.key = key;
		out.child_count = 0;
		out.first = xx 0;
		out.last = xx 0;
		out.next = xx 0;
		out.prev = xx 0;
		out.last_frame_touched_index = active_cxt.frame_index;
		out.computed_size[0] = 0;
		out.computed_size[1] = 0;
		
		out.computed_pos[0] = 0;
		out.computed_pos[1] = 0;
		
		if out.hot {
			active_cxt.atleast_one_hot = true;
		}
		
		out.hot = false;
		
		out.active = false;
		out.focus_last = out.focus;
		//out.text_edit_pos = 0;
	}
	
	// tree links
	
	{
		parent := active_cxt.parent_stack.top.v;
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
		out.bg_color = active_cxt.bg_color_stack.top.v;
		//out.color = active_cxt.color_stack.top.v;
		out.border_color = active_cxt.border_color_stack.top.v;
		//out.border_thickness = active_cxt.border_thickness_stack.top.v;
		//out.radius = active_cxt.radius_stack.top.v;
		out.pref_size[0] = active_cxt.size_x_stack.top.v;
		out.pref_size[1] = active_cxt.size_y_stack.top.v;
		
		out.offset = active_cxt.offset_stack.top.v;
		out.scissor = active_cxt.scissor_stack.top.v;
		out.flags |= active_cxt.flags_stack.top.v;
		out.text_padding = active_cxt.text_padding_stack.top.v;
		out.text_align = active_cxt.text_align_stack.top.v;
		out.hover_color = active_cxt.hover_color_stack.top.v;
	}
	
	// auto pop
	{
		ui_auto_pop();
	}
	
	return out;
}

ui_signal :: (widget : *UI_Widget) -> UI_Signal {
	out : UI_Signal;
	out.widget = widget;
	
	if point_in_rect(active_cxt.mpos, widget.dst) {
		widget.hot = true;
		
		if os.event(active_cxt.events, .LMB, .Pressed) {
			widget.active = true;
			widget.toggle = !widget.toggle;
			widget.focus = true;
		}
		
	}
	
	out.hot = widget.hot;
	out.active = widget.active;
	out.toggle = widget.toggle;
	out.focus = widget.focus;
	
	return out;
}

ui_widget_impl :: (flags : UI_Flags, key : UI_ID) -> UI_Signal {
	
	widget := ui_widget_from_key(key);
	widget.flags |= flags;
	
	return .{widget = widget};
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
		dst := r.get_text_rect(font, root.text, .{}, 1);
		
		if axis == .X {
			root.computed_size[axis] = dst.max.x;
			
		} else if axis == .Y {
			root.computed_size[axis] = dst.max.y;
		}
		
		case .Pixels;
		root.computed_size[axis] = root.pref_size[axis].value;
	}
	
	if root.flags & .Text {
		root.computed_size[axis] += root.text_padding;
	}
	
}

ui_layout_upward_dependent :: (root : *UI_Widget, axis : UI_Axis) {
	
	if root.pref_size[axis].kind == .PercentOfParent {
		
		fixed_parent : *UI_Widget;
		
		{
			p := root.parent;
			while p {
				
				if (p.pref_size[axis].kind == .Pixels) || (p.pref_size[axis].kind == .TextContent) || (p.pref_size[axis].kind == .ChildrenSum) {
					fixed_parent = p;
					break;
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

ui_enforce_constraints :: (root : *UI_Widget, axis : UI_Axis) {
	
	if axis != root.child_layout_axis {
		allowed_size := root.computed_size[axis];
		
		child := root.first;
		while child {
			defer child = child.next;
			
			if !(child.flags & UI_Floating) {
				child_size := child.computed_size[axis];
				violation := child_size - allowed_size;
				max_fixup := child_size;
				fixup := clamp(0., violation, max_fixup);
				
				if fixup > 0 {
					child.computed_size[axis] -= fixup;
				}
			}
		}
	}
	
	if axis == root.child_layout_axis {
		total_allowed_size := root.computed_size[axis];
		total_size := 0.;
		total_weighted_size := 0.;
		
		{
			child := root.first;
			while child {
				defer child = child.next;
				if !(child.flags & UI_Floating) {
					total_size += child.computed_size[axis];
					total_weighted_size += child.computed_size[axis] * (1 - child.pref_size[axis].strictness);
				}
			}
		}
		
		violation := total_size - total_allowed_size;
		
		if violation > 0 {
			fixup_sum := 0.;
			fixups :[]float32;
			fixups.data = talloc(size_of(float32) * root.child_count);
			fixups.count = root.child_count;
			
			{
				child_idx := 0;
				child := root.first;
				while child {
					defer child = child.next;
					defer child_idx += 1;
					if !(child.flags & UI_Floating) {
						
						fixed_child_size := child.computed_size[axis] * (1 - child.pref_size[axis].strictness);
						
						fixed_child_size = clamp_bot(0., fixed_child_size);
						fixups[child_idx] = fixed_child_size;
						fixup_sum += fixed_child_size;
					}
				}
			}
			
			{
				child_idx := 0;
				child := root.first;
				while child {
					defer child = child.next;
					defer child_idx += 1;
					
					if !(child.flags & UI_Floating) {
						fixup_pct := violation / total_weighted_size;
						fixup_pct = clamp(0., fixup_pct, 1.);
						
						child.computed_size[axis] -= fixups[child_idx] * fixup_pct;
					}
				}
			}
		}
	}
	
	{
		child := root.first;
		while child {
			ui_enforce_constraints(child, axis);
			child = child.next;
		}
	}
	
}

ui_layout_pos :: (root : *UI_Widget) {
	
	lay_pos : float32 = root.offset[root.child_layout_axis];
	
	{
		child := root.first;
		while child {
			defer child = child.next;
			
			child.computed_pos[0] += root.computed_pos[0];
			child.computed_pos[1] += root.computed_pos[1];
			
			if(!(child.flags & UI_Floating)) {
				axis := root.child_layout_axis;
				child.computed_pos[axis] += lay_pos;
				
				lay_pos += child.computed_size[axis];
			}
			
			pos := Vector2.{child.computed_pos[0], child.computed_pos[1]};
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
		ui_enforce_constraints(root, axis);
	}
	
	ui_layout_pos(root);
	//ui_print_nodes_pre_order(root, 0);
	//printf("\n");
}

active_cxt : *UI_State;

ui_begin :: (state : *UI_State, events : *os.EventList, mpos : Vector2) {
	state.mpos = mpos;
	state.frame_index+=1;
	state.events = events;
	active_cxt = state;
	
	widget : *UI_Widget = tzpush_struct(UI_Widget);
	widget.child_layout_axis = .X;
	widget_node : *UI_Parent_Node = tzpush_struct(UI_Parent_Node);
	widget.pref_size[0].kind = .ChildrenSum;
	widget.pref_size[1].kind = .ChildrenSum;
	widget_node.v = widget;
	state.parent_stack.top = widget_node;
	state.root = widget;
	
	state.root.child_count = 0;
	
	ui_push_offset_node(.[0, 0]);
	ui_push_size_node(ui_size_children_sum());
	ui_push_scissor_node(.{});
	ui_push_flags_node(0);
	ui_push_text_padding_node(0);
	ui_push_bg_color_node(.{0.678, 0.671, 0.631, 1});
	ui_push_text_align_node(.Middle);
	ui_push_border_color_node(r.COLOR_WHITE);
	ui_push_hover_color_node(r.COLOR_MAGENTA);
	
	if state.atleast_one_hot  && !state.atleast_one_hot_last {
		os.set_cursor(.Hand);
	}
	
	if !state.atleast_one_hot && state.atleast_one_hot_last {
		os.set_cursor(.Arrow);
	}
	
	state.atleast_one_hot_last = state.atleast_one_hot;
	state.atleast_one_hot = false;
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

ui_end :: () {
	ui_pop_parent_node();
	ui_pop_offset_node();
	ui_pop_size_node();
	ui_pop_scissor_node();
	ui_pop_flags_node();
	ui_pop_text_padding_node();
	ui_pop_bg_color_node();
	ui_pop_text_align_node();
	ui_pop_border_color_node();
	ui_pop_hover_color_node();
	
	for i : 0 .. active_cxt.slots.count - 1 {
		first_hash := (active_cxt.slots.data + i).first;
		if !first_hash {
			continue;
		}
		if first_hash {
			cur := first_hash;
			prev : *UI_Widget;
			
			while cur {
				if cur.last_frame_touched_index != active_cxt.frame_index {
					//print("pruned %\n", cur.text);
					
					if prev {
						prev.hash_next = cur.hash_next;
						if !cur.hash_next {
							(active_cxt.slots.data + i).last = prev;
						}
					}
					else {
						(active_cxt.slots.data + i).first = cur.hash_next;
						if (!cur.hash_next) {
							(active_cxt.slots.data + i).last = xx 0;
						}
					}
					
					to_free := cur;
					cur = cur.hash_next;
					
					to_free.next = active_cxt.free;
					active_cxt.free = to_free;
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

ui_push_size_node :: (v : UI_Size, auto : bool = false) {
	ui_push_size_x_node(v, auto);
	ui_push_size_y_node(v, auto);
}

ui_pop_size_node :: () {
	ui_pop_size_x_node();
	ui_pop_size_y_node();
}