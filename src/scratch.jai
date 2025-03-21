// TODO(mizu): maximize button, recreate framebuffers, get rid of camera stupid abstraction work on "tabs" and make the map editor and game different tabs and work on letting the map editor have windows and fix scissors and then :) :) :) put the map editor, and sim inside of main.

scratch_initialized : bool;
scratch_window : *Editor_Window;

counter : u64;
win_target : r.Framebuffer;
game_target : r.Framebuffer;
timer : float32;

scratch_update :: (delta : float32, events : *os.EventList,
									 passes : *r.Pass_List) {
	if !scratch_initialized {
		scratch_initialized = true;
		scratch_window = editor_init_window("The Sad Debugger And Linker", .Draw_Titlebar | .Resizable | .Scrollable);
		win_target = r.framebuffer(scratch_window.size);
		game_target = r.framebuffer(.{960, 540});
	}
	timer += xx delta;
	
	editor_window_begin(scratch_window, events);
	editor_push_file_id(scratch_window, .Scratch);
	
	ui_push_size_node(ui_size_pct(1, 0), true);
	editor_col_begin();
	
	if !scratch_window.hide {
		ui_push_size_node(ui_size_txt(1));
		editor_label("Hello you are loved");
		ui_pop_size_node();
		
		ui_push_size_x_node(ui_size_px(1920, 0), true);
		ui_push_size_y_node(ui_size_px(1080, 0), true);
		editor_image(.{U64 = .[0, xx game_target.resident]});
	}
	
	editor_row_end();
	editor_pop_file_id(scratch_window);
	editor_window_end(scratch_window);
	
	passes2 : r.Pass_List;
	r.push_scissor(*passes2, rectF32(0, 0, 1920, 1080));
	
	editor_update(delta, events, *passes2);
	//world_update(xx delta, events, *passes2);
	r.submit(timer, game_target, .{1920, 1080}, passes2, camera.pos);
	r.pop_scissor(*passes2);
	
	//text := tprint("%", delta);
	//r.push_text(passes, font, text, .{}, text_size, r.COLOR_BLACK);
	
	counter += 1;
}