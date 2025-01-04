editor_windows : [2]Editor_Window;
editor_windows_count : s32;

Editor_Window :: struct {
	layout : UI_Layout;
	hide : bool;
	// titlebar
	title : string;
	grabbed : bool;
	titlebar_height :: 32;
	last_mpos : Vector2;
	id : s32;
}

editor_in_focus :: (window : Editor_Window) -> bool {
	rect : RectF32;
	rect.min = window.layout.origin;
	rect.max = window.layout.rect_max;
	return point_in_rect(mpos, rect);
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
	window.layout.origin = pos;
}

editor_init_window :: (title : string) -> *Editor_Window {
	out := *editor_windows[0] + editor_windows_count;
	out.id = editor_windows_count;
	editor_windows_count += 1;
	out.title = title;
	
	return out;
}

editor_window_begin :: (batches : *r.BatchList, window : *Editor_Window) {
	ui_select_layout(*window.layout);
	
	ly := *window.layout;
	ly.text_pos = ly.origin + .{4, 4};
	
	// panel
	{
		ui_rect : RectF32;
		ui_rect.min = ly.origin;
		ui_rect.max = ly.rect_max + .{0, 4};
		
		bg := r.push_rect2(batches, ui_rect, .{0, 0, 0, 0.9});
		bg.border_color = r.COLOR_WHITE;
		bg.radius = 4;
		bg.border_thickness = 2;
	}
	
	{
		ui_rect : RectF32;
		ui_rect.min = ly.origin;
		ui_rect.max.x = ly.rect_max.x;
		ui_rect.max.y = ui_rect.min.y + window.titlebar_height;
		if ui_cxt.mouse_down && point_in_rect(mpos, ui_rect) {
			window.grabbed = true;
		}
		
		if window.grabbed {
			ly.origin += mpos - window.last_mpos;
			
			if ui_cxt.mouse_up {
				window.grabbed = false;
			}
		}
		
	}
	
	window.last_mpos = mpos;
	ly.rect_max = .{};
	
	// titlebar
	
	layout : UI_Layout;
	layout.text_pos = ly.text_pos;
	layout.axis = .X;
	ui_select_layout(*layout);
	
	window.hide = ui_button(.{200 + window.id, 0, 1}, "hide").toggle;
	ui_label(.{200 + window.id, 0, 0}, window.title);
	
	ui_select_layout(ly);
	ly.text_pos.y = layout.rect_max.y;
	ly.rect_max = layout.rect_max;
}