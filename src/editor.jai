editor_windows : [5]Editor_Window;
editor_windows_count : s32;
editor_ui_cxt : *UI_State;
entry_count :: 5;

Editor_Window :: struct {
	hide : bool;
	events : *os.EventList;
	
	// titlebar
	title : string;
	grabbed : bool;
	titlebar_height :: 32;
	last_mpos : Vector2;
	id : s32;
	last_touched : int;
	
	root : *UI_Widget;
	tb : *UI_Widget;
	pos : Vector2;
	dst : RectF32;
	tb_dst : RectF32;
	
	resize_grabbed : bool;
	size : Vector2;
	
	offset : float;
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
	out.size = .{30, 40};
	
	return out;
}

editor_window_end :: (window : *Editor_Window) {
	
	/*
	if point_in_rect(mpos, window.root.dst) {
		os.event(window.events, .LMB, .Pressed);
		os.event(window.events, .RMB, .Pressed);
		
		os.event(window.events, .LMB, .Released);
		os.event(window.events, .RMB, .Released);
	}
	*/
	window.last_mpos = mpos;
	
}

editor_window_begin :: (window : *Editor_Window, events : *os.EventList) {
	window.last_touched = editor_clock;
	window.events = events;
	
	
}

editor_label :: (text : string, index := 0, loc := #caller_location) -> UI_Signal {
	
	id := UI_ID.{};
	id.v[0] = xx loc.line_number;
	id.v[1] = xx index;
	return ui_widget_impl(editor_ui_cxt, text, .Text, id);
}

editor_button :: (text : string, index := 0, loc := #caller_location) -> UI_Signal {
	
	id := UI_ID.{};
	id.v[0] = xx loc.line_number;
	id.v[1] = xx index;
	return ui_widget_impl(editor_ui_cxt, text, .Text | .Clickable, id);
}

editor_check_box :: (checked : *bool, index := 0, loc := #caller_location) -> UI_Signal {
	id := UI_ID.{};
	id.v[0] = xx loc.line_number;
	id.v[1] = xx index;
	out := ui_widget_impl(editor_ui_cxt, "", .Check_Box, id);
	
	if out.active {
		<< checked = ! << checked;
	}
	
	out.widget.checked = << checked;
	return out;
}

editor_slider :: (v : *float, index := 0, loc := #caller_location) -> UI_Signal {
	id := UI_ID.{};
	id.v[0] = xx loc.line_number;
	id.v[1] = xx index;
	out := ui_widget_impl(editor_ui_cxt, "", .Slider, id);
	
	out.widget.value = << v;
	
	return out;
}

editor_image :: (image : r.Handle, src : RectF32 = .{.{0, 0}, .{1, 1}}, index := 0, loc := #caller_location) -> UI_Signal {
	id := UI_ID.{};
	id.v[0] = xx loc.line_number;
	id.v[1] = xx index;
	out := ui_widget_impl(editor_ui_cxt, "", .Image, id);
	out.widget.image = image;
	out.widget.src = src;
	return out;
}

editor_row_begin :: (index := 0, loc := #caller_location) -> UI_Signal {
	
	id := UI_ID.{};
	id.v[0] = xx loc.line_number;
	id.v[1] = xx index;
	
	parent_id : UI_ID = .{.[xx loc.line_number, xx index]};
	tb := ui_widget_from_key(editor_ui_cxt, parent_id);
	ui_push_parent_node(editor_ui_cxt, tb);
	tb.child_layout_axis = .X;
	tb.pref_size[0].kind = .ChildrenSum;
	tb.pref_size[1].kind = .ChildrenSum;
	
	return ui_widget_impl(editor_ui_cxt, "", 0, id);
}

editor_col_begin :: (index := 0, loc := #caller_location) -> UI_Signal {
	
	id := UI_ID.{};
	id.v[0] = xx loc.line_number;
	id.v[1] = xx index;
	
	parent_id : UI_ID = .{.[xx loc.line_number, xx index]};
	tb := ui_widget_from_key(editor_ui_cxt, parent_id);
	ui_push_parent_node(editor_ui_cxt, tb);
	tb.child_layout_axis = .Y;
	tb.pref_size[0].kind = .ChildrenSum;
	tb.pref_size[1].kind = .ChildrenSum;
	
	return ui_widget_impl(editor_ui_cxt, "", 0, id);
}

editor_row_end :: () {
	ui_pop_parent_node(editor_ui_cxt);
}

editor_spacer :: (size : UI_Size, index := 0, loc := #caller_location) -> UI_Signal {
	id := UI_ID.{};
	id.v[0] = xx loc.line_number;
	id.v[1] = xx index;
	
	ui_push_size_node(editor_ui_cxt, size);
	
	out := ui_widget_impl(editor_ui_cxt, "", 0, id);
	ui_pop_size_node(editor_ui_cxt);
	
	return out;
}

draw_children :: (passes : *r.Pass_List, root : *UI_Widget) {
	
	if root.flags & .Scissor {
		r.push_scissor(passes, root.scissor);
	}
	
	if root.flags & .Slider {
		// bar
		{
			dst := root.dst;
			color := Vector4.{52. / 255, 70. / 255, 97. / 255, 1};
			
			if root.hot {
				color *= 1.2;
			}
			
			r.push_rect2(passes, dst, color);
		}
		
		// notch
		{
			dst := root.dst;
			dst.max.x = dst.min.x + root.size.y;
			dst.min.x += root.value * root.size.x;
			dst.max.x += root.value * root.size.x;
			
			dst.min.x -= 8;
			dst.max.x -= 8;
			r.push_rect2(passes, dst, .{0.1, 0.4, 0.8, 0.3});
		}
		
		// slider text value
		{
			text_pos := root.pos;
			text_pos.x += root.size.x / 2;
			text_pos.x -= 13;
			text_pos.y += 2;
			text := tprint("%", root.value);
			
			//r.push_scissor(passes, root.dst);
			r.push_text(passes, font, text, text_pos, 1., r.COLOR_WHITE);
			//r.pop_scissor(passes);
		}
		
	}
	
	if root.flags & .Bg {
		img := r.push_rect2(passes, root.dst, root.bg_color);
	}
	
	if root.flags & .Clickable {
		dst := root.dst;
		color := Vector4.{0, 0, 0, 0.8};
		
		
		if root.hot {
			color = r.COLOR_BLUE;
		}
		
		
		bg := r.push_rect2(passes, dst, color);
		bg.border_thickness = 3;
		bg.border_color = r.COLOR_WHITE;
		bg.radius = 4;
	}
	
	if root.flags & .Image {
		color := r.COLOR_WHITE;
		if root.hot {
			color.y *= 0;
		}
		
		img := r.push_rect2(passes, root.dst, color);
		img.tex_id = root.image.U64[1];
		img.src = root.src;
	}
	
	if root.flags & .Check_Box {
		dst := root.dst;
		color := Vector4.{52. / 255, 70. / 255, 97. / 255, 1};
		
		if root.hot {
			color *= 1.2;
		}
		
		r.push_rect2(passes, dst, color);
		
		if root.checked {
			r.push_rect2(passes, dst, r.COLOR_WHITE);
		}
		
	}
	
	if root.flags & .Text {
		text_color := r.COLOR_WHITE;
		
		if root.hot {
			text_color = r.COLOR_BLUE;
		}
		
		text_pos := root.pos;
		font_size := 1.;
		
		if root.flags & .Clickable {
			text_pos.x += root.text_padding / 2;
			font_size = 0.95;
		}
		
		/*
				if root.size.y >= xx (font.line_height * 0.4){
					
					 text_pos, 0.4);
					
					text_pos.y += (font.line_height * 0.2);
				}
				*/
		
		text_rect := r.get_text_rect(font, root.text, .{}, font_size);
		text_height := text_rect.max.y - text_rect.min.y;
		
		if root.size.y > text_height {
			text_pos.y += (root.size.y - text_height) / 2;
		}
		
		r.push_text(passes, font, root.text, text_pos, font_size, text_color);
	}
	
	{
		child :=  root.first;
		while child {
			draw_children(passes, child);
			child = child.next;
		}
	}
	
	if root.flags & .Scissor {
		r.pop_scissor(passes);
	}
}
