// ui todo : 
// fragmenting editor and ui like this is annoying
// begin and end for ui cxt is required
// begin and end for file number. Use it in the widget id

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
	
	text : string;
	
	pad :: 8;
	
	ui_push_size_x_node(ui_size_px(64));
	ui_push_size_y_node(ui_size_px(32));
	ui_push_flags_node(UI_Floating);
	parent := ui_widget_from_key(.{.[99, 99]});
	parent.bg_color = r.COLOR_BLUE;
	ui_pop_flags_node();
	ui_pop_size_node();
	
	ui_push_parent_node( parent);
	
	ui_push_size_node( ui_size_pct(1, 0.));
	//ui_push_size_y_node( ui_size_px(128));
	
	editor_button("");
	editor_button("");
	editor_button("");
	
	ui_pop_size_node();
	
	editor_window_end(scratch_window);
	ui_pop_parent_node();
}