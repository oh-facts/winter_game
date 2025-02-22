// ui todo : 
// fragmenting editor and ui like this is annoying
// begin and end for ui cxt is required

scratch_initialized : bool;
scratch_window : *Editor_Window;

checked : [2]bool;
slider : float = 0.5;

scratch_update :: (delta : float32, events : *os.EventList, 
									 passes : *r.Pass_List) {
	if !scratch_initialized {
		scratch_initialized = true;
		scratch_window = editor_init_window("editor window");
	}
	
	editor_window_begin(scratch_window, events);
	defer editor_window_end(scratch_window);
	
	text : string;
	
	if ! scratch_window.hide {
		
		editor_row_begin();
		
		editor_spacer(ui_size_px(8));
		
		if scroll_up {
			scratch_window.offset += 8;
		}
		else if scroll_down {
			scratch_window.offset -= 8;
		}
		
		ui_push_offset_node(editor_ui_cxt, .[0, scratch_window.offset]);
		
		window_area := scratch_window.dst;
		window_area.min.y += 32;
		
		ui_push_scissor_node(editor_ui_cxt, window_area);
		ui_push_flags_node(editor_ui_cxt, .Scissor);
		editor_col_begin();
		
		editor_spacer(ui_size_px(8));
		editor_label("This is some useful text.");
		editor_spacer(ui_size_px(8));
		
		for 0 .. 1 {
			editor_row_begin();
			ui_push_size_node(editor_ui_cxt, ui_size_px(32));
			{
				editor_check_box(*checked[it], it);
				editor_spacer(ui_size_px(8));
				ui_push_size_x_node(editor_ui_cxt, ui_size_txt());
				if it == 0 editor_label("Demo Window", it);
				if it == 1 editor_label("Another Window", it);
				editor_spacer(ui_size_px(8));
				ui_pop_size_x_node(editor_ui_cxt);
			}
			
			ui_pop_size_node(editor_ui_cxt);
			editor_row_end();
			editor_spacer(ui_size_px(8));
		}
		
		ui_push_size_node(editor_ui_cxt, ui_size_children_sum());
		editor_row_begin();
		ui_push_size_y_node(editor_ui_cxt, ui_size_px(24));
		ui_push_size_x_node(editor_ui_cxt, ui_size_pct(0.6));
		
		editor_slider(*slider);
		ui_pop_size_node(editor_ui_cxt);
		editor_spacer(ui_size_px(16));
		
		ui_push_size_node(editor_ui_cxt, ui_size_txt());
		editor_label("float");
		ui_pop_size_node(editor_ui_cxt);
		editor_spacer(ui_size_px(8));
		editor_row_end();
		ui_pop_size_node(editor_ui_cxt);
		
		
		editor_row_end();
		ui_pop_flags_node(editor_ui_cxt);
		ui_pop_scissor_node(editor_ui_cxt);
		ui_pop_offset_node(editor_ui_cxt);
		editor_row_end();
	}
	
}