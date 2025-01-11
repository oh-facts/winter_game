editor_windows : [5]Editor_Window;
editor_windows_count : s32;
editor_ui_cxt : *ui.State;
entry_count :: 5;

Editor_Scroll :: struct {
	entry_start : int;
	rect : RectF32;
}

Editor_Window :: struct {
	hide : bool;
	
	// titlebar
	title : string;
	grabbed : bool;
	titlebar_height :: 32;
	last_mpos : Vector2;
	id : s32;
	last_touched : int;
	entry_start : int;
	entity_scroll_region : RectF32;
	entity_scrolls : [30]Editor_Scroll;
	root : *ui.Widget;
	tb : *ui.Widget;
	pos : Vector2;
	dst : RectF32;
	tb_dst : RectF32;
}

editor_clock : int;

editor_tick_clock :: () {
	editor_clock += 1;
}

editor_in_focus :: (window : Editor_Window) -> bool {
	
	out : bool;
	
	if window.last_touched + 1 < editor_clock {
		return false;
	}
	
	return point_in_rect(mpos, window.dst);
}

any_editor_in_focus :: () -> bool {
	out : bool;
	
	for 0 .. editor_windows_count - 1 {
		res := editor_in_focus(*editor_windows[it]);
		
		if res {
			out = true;
			break;
		}
	}
	
	return out;
}

editor_set_window_pos :: (window : *Editor_Window, pos : Vector2) {
	window.pos = pos;
}

editor_init_window :: (title : string) -> *Editor_Window {
	out := *editor_windows[0] + editor_windows_count;
	out.id = editor_windows_count;
	editor_windows_count += 1;
	out.title = title;
	
	return out;
}

editor_window_end :: (window : *Editor_Window) {
	window.dst = window.root.dst;
	window.tb_dst = window.tb.dst;
	ui.pop_parent_node(editor_ui_cxt);
}

editor_window_begin :: (batches : *r.BatchList, window : *Editor_Window) {
	window.last_touched = editor_clock;
	
	root_id : ui.ID = .{.[100, 100]};
	root := ui.widget_from_key(editor_ui_cxt, root_id);
	ui.push_parent_node(editor_ui_cxt, root);
	root.child_layout_axis = .Y;
	root.pref_size[0].kind = .ChildrenSum;
	root.pref_size[1].kind = .ChildrenSum;
	root.computed_rel_position[0] = window.pos.x;
	root.computed_rel_position[1] = window.pos.y;
	
	window.root = root;
	
	{
		if lmb_down && point_in_rect(mpos, window.tb_dst) {
			window.grabbed = true;
		}
		
		if window.grabbed {
			window.pos += mpos - window.last_mpos;
			
			if lmb_up {
				window.grabbed = false;
			}
		}
		
	}
	
	window.last_mpos = mpos;
	
	// titlebar
	tb_id : ui.ID = .{.[200, 200]};
	tb := ui.widget_from_key(editor_ui_cxt, tb_id);
	ui.push_parent_node(editor_ui_cxt, tb);
	tb.child_layout_axis = .X;
	tb.pref_size[0].kind = .ChildrenSum;
	tb.pref_size[1].kind = .ChildrenSum;
	window.tb = tb;
	
	window.hide = editor_label("hide").toggle;
	editor_label(window.title);
	ui.pop_parent_node(editor_ui_cxt);
}

editor_label :: (text : string, index := 0, loc := #caller_location) -> ui.Signal {
	
	id := ui.ID.{};
	id.v[0] = xx loc.line_number;
	id.v[1] = xx index;
	return ui.widget_impl(editor_ui_cxt, text, id);
}


draw_children :: (ui_batches : *r.BatchList, root : *ui.Widget) {
	//print("%\n", root.dst);
	
	{
		dst := root.dst;
		color :: Vector4.{0, 0, 0, 0.8};
		bg := r.push_rect2(ui_batches, dst, color);
		bg.border_thickness = 2;
		bg.border_color = r.COLOR_WHITE;
		bg.radius = 4;
	}
	
	text_color := r.COLOR_WHITE;
	
	if root.hot {
		text_color = r.COLOR_BLUE;
	}
	
	text_pos := root.pos + .{8, 8};
	
	r.push_text(ui_batches, font, root.text, text_pos, 0.4, text_color);
	
	{
		child :=  root.first;
		while child {
			draw_children(ui_batches, child);
			child = child.next;
		}
	}
}
