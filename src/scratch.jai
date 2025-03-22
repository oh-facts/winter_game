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
		scratch_window = editor_init_window("~~~~ The Sad Debugger 1 Million <3 ~~~~", .Draw_Titlebar | .Resizable | .Scrollable);
		win_target = r.framebuffer(scratch_window.size);
		game_target = r.framebuffer(.{1920, 1024});
	}
	timer += xx delta;
	
	editor_window_begin(scratch_window, events, passes);
	editor_push_file_id(scratch_window, .Scratch);
	
	ui_push_size_node(ui_size_pct(1, 0), true);
	editor_col_begin();
	
	if !scratch_window.hide {
		ui_push_size_x_node(ui_size_pct(1, 0), true);
		ui_push_size_y_node(ui_size_children_sum(1), true);
		editor_row_begin();
		
		ui_push_size_x_node(ui_size_px(64, 1));
		ui_push_size_y_node(ui_size_px(32, 1));
		
		passes2 = .{};
		r.push_scissor(*passes2, rectF32(0, 0, 1920, 1024));
		
		active_ids : [Mode.COUNT]UI_ID;
		
		for 0 .. Mode.COUNT - 1 {
			text := tprint("%", it);
			
			if current_mode == it {
				editor_active_button(text, active_ids[it]);
			} else {
				sig := editor_button(text, xx it);
				if sig.active {
					current_mode = it;
				}
				active_ids[it] = sig.widget.key;
			}
		}
		
		if current_mode == {
			case .Home;
			
			
			case .Game;
			world_update(delta, events, *passes2);
			
			case .Editor;
			editor_update(delta, events, *passes2);
			
			case .Scratch;
			r.push_text(passes, font, "hi", .{100, 600}, 32);
			
			case .Profiler;
			
			ui_push_size_x_node(ui_size_txt(1));
			editor_spacer(ui_size_px(4));
			text := tprint("cmt: %\n res %", os.cmt, os.res);
			editor_label(text);
			ui_pop_size_x_node();
			
		}
		
		if os.event(events, .TAB, .Pressed) {
			current_mode = (current_mode + 1) % .COUNT;
		}
		
		ui_push_size_x_node(ui_size_txt(1));
		editor_spacer(ui_size_px(4));
		editor_label("Please enjoy each mode equally.");
		//editor_spacer(ui_size_px(4));
		//text := tprint("%", 1. / delta);
		//editor_label(text);
		ui_pop_size_x_node();
		
		ui_pop_size_node();
		
		
		editor_row_end();
	}
	
	if current_mode == .Home {
		scope := tex.scope_open();
		
		ui_push_size_x_node(ui_size_px(960, 0), true);
		ui_push_size_y_node(ui_size_px(540, 0), true);
		hide_img := tex.handle_from_hash(scope, arts[ArtId.Editor_Home_Bg].hash, .Linear);
		
		editor_image(hide_img);
		tex.scope_close(scope);
	}
	
	if current_mode == .Game || current_mode == .Editor {
		ui_push_size_x_node(ui_size_px(1920, 0), true);
		ui_push_size_y_node(ui_size_px(1024, 0), true);
		editor_image_cant_click_lol_bro(.{U64 = .[0, xx game_target.resident]});
	}
	
	editor_row_end();
	editor_pop_file_id(scratch_window);
	editor_window_end(scratch_window);
	
	//text := tprint("%", delta);
	//r.push_text(passes, font, text, .{}, text_size, r.COLOR_BLACK);
	
	counter += 1;
}