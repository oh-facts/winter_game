// ui todo :
// more styling
// text alignment
// more widgets
// 1. Slider
// 2. Color Picker
// panels

scratch_initialized : bool;
scratch_window : *Editor_Window;

checked : [2]bool;
slider : float = 0.5;
counter : int;

scratch_update :: (delta : float32, events : *os.EventList, 
									 passes : *r.Pass_List) {
	if !scratch_initialized {
		scratch_initialized = true;
		scratch_window = editor_init_window("editor window");
	}
	
	editor_window_begin(scratch_window, events);
	editor_push_file_id(scratch_window, .Scratch);
	text : string;
	
	ui_push_size_x_node(ui_size_px(1920));
	ui_push_size_y_node(ui_size_px(32));
	ui_push_flags_node(UI_Floating | .Bg);
	parent := ui_widget_from_key(.{.[99, 99]});
	parent.bg_color = r.COLOR_BLUE;
	ui_pop_flags_node();
	ui_pop_size_node();
	
	ui_push_parent_node(parent);
	
	ui_push_size_x_node(ui_size_pct(0.06, 0));
	ui_push_size_y_node(ui_size_pct(1, 0));
	
	if editor_button("File").toggle {
		
		ui_push_size_x_node(ui_size_px(256));
		ui_push_size_y_node(ui_size_px(300));
		ui_push_flags_node(UI_Floating);
		parent := ui_widget_from_key(.{.[199013, 99]});
		parent.offset[1] = parent.parent.size.y;
		parent.child_layout_axis = .Y;
		parent.bg_color = r.COLOR_BLUE;
		ui_pop_flags_node();
		ui_pop_size_node();
		
		ui_push_parent_node(parent);
		
		ui_push_size_x_node(ui_size_pct(1., 1));
		ui_push_size_y_node(ui_size_pct(1., 0));
		
		ui_push_bg_color_node(r.COLOR_ORANGE);
		editor_button("oooooooooooo");
		editor_button("oooooooooooo");
		editor_button("oooooooooooo");
		editor_button("oooooooooooo");
		editor_button("oooooooooooo");
		editor_button("oooooooooooo");
		editor_slider(*slider);
		editor_check_box(*checked[0]);
		
		ui_pop_bg_color_node();
		ui_pop_size_node();
		
		ui_pop_parent_node();
	}
	
	editor_button("Window");
	editor_button("Panel");
	editor_button("View");
	editor_button("Targets");
	editor_button("Control");
	editor_button("Help");
	
	editor_spacer(ui_size_pct(1, 0));
	ui_push_size_node(ui_size_px(32, 1.));
	
	img := arts[ArtId.Editor_Titlebar].tex;
	
	editor_image(img, rectF32(0.25, 0, 0.5, 1));
	editor_image(img, rectF32(0.5, 0, 0.75, 1));
	editor_image(img, rectF32(0.75, 0, 1, 1));
	ui_pop_size_node();
	
	ui_pop_parent_node();
	editor_pop_file_id(scratch_window);
	editor_window_end(scratch_window);
}