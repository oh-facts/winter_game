editor_windows : [5]Editor_Window;
editor_windows_count : s32;
editor_ui_cxt : *UI_State;
active_window : *Editor_Window;
// TODO(mizu): in case text doesnt fit in a certain width, render ...

Editor_File_Id :: enum {
	Null;
	Scratch;
	Editor;
	Map_Editor;
}

Editor_File_Id_Node :: struct {
	next : *Editor_File_Id_Node;
	v : Editor_File_Id;
}

editor_push_file_id :: (win : *Editor_Window, v : Editor_File_Id) {
	node : *Editor_File_Id_Node;
	node = push_struct(win.arena, Editor_File_Id_Node);
	
	node.v = v;
	
	node.next = win.file_id_stack.top;
	win.file_id_stack.top = node;
}

editor_pop_file_id :: (win : *Editor_Window) {
	to_free := win.file_id_stack.top;
	
	win.file_id_stack.top = win.file_id_stack.top.next; 
	
	to_free.next = win.file_id_stack.free;
	win.file_id_stack.free = to_free;
}

Editor_Window :: struct {
	arena : *Arena;
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
	
	file_id_stack : struct {
		top : *Editor_File_Id_Node;
		free : *Editor_File_Id_Node;
	};
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
	
	if window.resize_grabbed || window.grabbed {
		return true;
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
	out.size = .{400, 300};
	out.arena = arena_init();
	return out;
}

editor_window_begin :: (window : *Editor_Window, events : *os.EventList) {
	window.last_touched = editor_clock;
	window.events = events;
	active_window = window;
	
	editor_push_file_id(window, .Editor);
	
	ui_push_flags_node(UI_Floating | .Bg | .Scissor);
	ui_push_size_x_node(ui_size_px(window.size.x));
	ui_push_size_y_node(ui_size_px(window.size.y));
	//ui_push_size_y_node(ui_size_children_sum());
	root := ui_widget_from_key(.{.[199, 99, 99]});
	root.scissor = root.dst;
	root.child_layout_axis = .Y;
	root.computed_pos = window.pos.component;
	window.dst = root.dst;
	
	ui_pop_size_node();
	ui_pop_flags_node();
	
	ui_push_parent_node(root);
	
	// titlebar
	{
		ui_push_flags_node(.Bg);
		ui_push_size_x_node(ui_size_pct(1.), true);
		ui_push_size_y_node(ui_size_px(32), true);
		ui_push_bg_color_node(r.COLOR_MAGENTA);
		editor_row_begin();
		ui_pop_bg_color_node();
		ui_pop_flags_node();
		
		ui_push_size_x_node(ui_size_pct(0.25, 0));
		ui_push_size_y_node(ui_size_pct(1, 0));
		
		if editor_button("hide").active {
			window.hide = !window.hide;
		}
		
		if editor_label("Title").active {
			window.grabbed = true;
		}
		
		editor_spacer(ui_size_pct(1, 0));
		
		editor_button("close");
		ui_pop_size_node();
		
		ui_pop_parent_node();
	}
	
	editor_pop_file_id(window);
	
	if window.grabbed {
		window.pos += mpos - window.last_mpos;
		if os.event(events, .LMB, .Released) {
			window.grabbed = false;
		}
	}
	
}

editor_window_end :: (window : *Editor_Window) {
	assert(window == active_window);
	
	editor_push_file_id(window, .Editor);
	
	editor_spacer(ui_size_pct(1, 0));
	
	ui_push_size_x_node(ui_size_pct(1, 1), true);
	editor_row_begin();
	
	editor_spacer(ui_size_pct(1, 0));
	ui_push_size_node(ui_size_px(32, 1));
	if editor_image(r.get_white_square()).active {
		window.resize_grabbed = true;
	}
	
	ui_pop_size_node();
	editor_row_end();
	
	if window.resize_grabbed {
		window.size += mpos - window.last_mpos;
		
		if os.event(window.events, .LMB, .Released) {
			window.resize_grabbed = false;
		}
	}
	
	ui_pop_parent_node();
	
	editor_pop_file_id(window);
	
	
	active_window = xx 0;
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

editor_label :: (text : string, index := 0, loc := #caller_location) -> UI_Signal {
	
	id := UI_ID.{};
	id.v[0] = xx loc.line_number;
	id.v[1] = xx index;
	id.v[2] = xx active_window_file_id();
	
	out := ui_widget_impl(.Text, id);
	out.widget.text = text;
	
	return out;
}

editor_button :: (text : string, index := 0, loc := #caller_location) -> UI_Signal {
	
	id := UI_ID.{};
	id.v[0] = xx loc.line_number;
	id.v[1] = xx index;
	id.v[2] = xx active_window_file_id();
	
	out := ui_widget_impl(.Text | .Clickable, id);
	out.widget.text = text;
	return out;
}

editor_check_box :: (checked : *bool, index := 0, loc := #caller_location) -> UI_Signal {
	id := UI_ID.{};
	id.v[0] = xx loc.line_number;
	id.v[1] = xx index;
	id.v[2] = xx active_window_file_id();
	
	out := ui_widget_impl(.Check_Box, id);
	
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
	id.v[2] = xx active_window_file_id();
	
	out := ui_widget_impl(.Slider, id);
	
	out.widget.value = << v;
	
	return out;
}

editor_image :: (image : r.Handle, src : RectF32 = .{.{0, 0}, .{1, 1}}, index := 0, loc := #caller_location) -> UI_Signal {
	
	id := UI_ID.{};
	id.v[0] = xx loc.line_number;
	id.v[1] = xx index;
	id.v[2] = xx active_window_file_id();
	
	out := ui_widget_impl(.Image, id);
	out.widget.image = image;
	out.widget.src = src;
	return out;
}

active_window_file_id :: () -> Editor_File_Id {
	return active_window.file_id_stack.top.v;
}

editor_row_begin :: (index := 0, loc := #caller_location) -> UI_Signal {
	id := UI_ID.{};
	id.v[0] = xx loc.line_number;
	id.v[1] = xx index;
	id.v[2] = xx active_window_file_id();
	
	out := ui_widget_from_key(id);
	ui_push_parent_node(out);
	out.child_layout_axis = .X;
	
	return .{};
}

editor_col_begin :: (index := 0, loc := #caller_location) -> UI_Signal {
	id := UI_ID.{};
	id.v[0] = xx loc.line_number;
	id.v[1] = xx index;
	id.v[2] = xx active_window_file_id();
	
	out := ui_widget_from_key(id);
	ui_push_parent_node(out);
	out.child_layout_axis = .Y;
	
	return .{};
}

editor_row_end :: () {
	ui_pop_parent_node();
}

editor_spacer :: (size : UI_Size, index := 0, loc := #caller_location) -> UI_Signal {
	id := UI_ID.{};
	id.v[0] = xx loc.line_number;
	id.v[1] = xx index;
	id.v[2] = xx active_window_file_id();
	
	ui_push_size_node(size);
	
	out := ui_widget_impl(0, id);
	ui_pop_size_node();
	
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
		color := root.bg_color;
		
		if root.hot {
			color = r.COLOR_BLUE;
		}
		
		bg := r.push_rect2(passes, dst, color);
		bg.border_thickness = 3;
		bg.border_color = root.border_color;
		bg.radius = 4;
	}
	
	if root.flags & .Image {
		color := r.COLOR_WHITE;
		if root.hot {
			color.y *= 0;
		}
		
		bg := r.push_rect2(passes, root.dst, r.COLOR_BLACK);
		bg.border_thickness = 3;
		bg.border_color = r.COLOR_WHITE;
		bg.radius = 4;
		
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
		
		if root.text_align == .Middle {
			text_width := text_rect.max.x - text_rect.min.x;
			if root.size.x > text_width {
				text_pos.x += (root.size.x - text_width) / 2;
			}
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
