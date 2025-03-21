scratch_initialized : bool;
scratch_window : *Editor_Window;

counter : u64;

scratch_update :: (delta : float32, events : *os.EventList,
									 passes : *r.Pass_List) {
	if !scratch_initialized {
		scratch_initialized = true;
		scratch_window = editor_init_window("The Sad Debugger And Linker", .Draw_Titlebar | .Resizable | .Scrollable);
	}
	
	editor_window_begin(scratch_window, events);
	editor_push_file_id(scratch_window, .Scratch);
	
	ui_push_size_node(ui_size_pct(1, 0), true);
	editor_col_begin();
	
	if !scratch_window.hide {
		ui_push_size_node(ui_size_txt(0));
		editor_label("Hello you are loved");
		ui_pop_size_node();
	}
	
	editor_row_end();
	editor_pop_file_id(scratch_window);
	editor_window_end(scratch_window);
	
	//text := tprint("%", delta);
	//r.push_text(passes, font, text, .{}, text_size, r.COLOR_BLACK);
	
	counter += 1;
}