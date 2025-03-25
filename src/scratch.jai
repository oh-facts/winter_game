// TODO(mizu): maximize button, recreate framebuffers, get rid of camera stupid abstraction work on "tabs" and make the map editor and game different tabs and work on letting the map editor have windows and fix scissors and then :) :) :) put the map editor, and sim inside of main.

scratch_initialized : bool;
scratch_window : *Editor_Window;

counter : u64;
current_art : ArtId;

timer : float32;

scratch_update :: (delta : float32, events : *os.EventList,
									 passes : *r.Pass_List) {
	if !scratch_initialized {
		scratch_initialized = true;
		
	}
	
	timer += xx delta;
	
	editor_window_begin(scratch_window, events);
	
	editor_push_file_id(.Scratch);
	
	ui_push_size_node(ui_size_pct(1, 0), true);
	editor_col_begin();
	game_ui_cxt.root = xx 0;
	
	if !scratch_window.hide {
		ui_push_size_x_node(ui_size_pct(1, 0), true);
		ui_push_size_y_node(ui_size_children_sum(1), true);
		editor_row_begin();
		
		ui_push_size_x_node(ui_size_px(64, 1));
		ui_push_size_y_node(ui_size_px(32, 1));
		
		passes2 : r.Pass_List;
		r.push_scissor(*passes2, rectF32(0, 0, 1920, 1024));
		
		for 0 .. Mode.COUNT - 1 {
			text := tprint("%", it);
			
			if current_mode == it {
				ui_push_flags_node(.Offset, true);
				ui_push_remove_flags_node(.Shadow, true);
			}
			
			if editor_button(text, xx it).active {
				current_mode = it;
			}
		}
		
		editor_mpos := mpos;
		//editor_mpos.x *= 1920. / (1920 - 32);
		//editor_mpos.x *= scratch_window.game_target.size.x / scratch_window.client_rect.size.x;
		//editor_mpos.y *= scratch_window.game_target.size.y / (scratch_window.client_rect.size.y);
		//editor_mpos.y -= 64;
		
		if current_mode == {
			case .Home;
			case .Game;
			ui_begin(game_ui_cxt, events, editor_mpos);
			world_update(delta, events, *passes2);
			ui_end();
			
			case .Editor;
			
			ui_begin(game_ui_cxt, events, editor_mpos);
			editor_update(delta, events, *passes2);
			ui_end();
			
			case .Scratch;
			
			case .Profiler;
			
			ui_push_size_x_node(ui_size_txt(1));
			editor_spacer(ui_size_px(4));
			text := tprint("cmt: %\n res %", os.cmt, os.res);
			editor_label(text);
			ui_pop_size_x_node();
			
			case .Asset;
			
		}
		
		tab_event := os.event(events, .TAB, .Pressed);
		
		if  tab_event {
			if tab_event.shift_held {
				current_mode = (current_mode - 1) % .COUNT;
			} else {
				current_mode = (current_mode + 1) % .COUNT;
			}
		}
		
		ui_push_size_x_node(ui_size_txt(1));
		editor_spacer(ui_size_px(4));
		editor_label("Please enjoy each mode equally.");
		//editor_spacer(ui_size_px(4));
		//text := tprint("%", 1. / delta);
		//editor_label(text);
		ui_pop_size_x_node();
		
		ui_pop_size_node();
		
		r.submit(timer, scratch_window.game_target, .{1920, 1024}, passes2, camera.pos);
		r.pop_scissor(*passes2);
		
		editor_row_end();
		
		if current_mode == {
			case .Asset;
			
			ui_push_size_x_node(ui_size_pct(1, 0), true);
			ui_push_size_y_node(ui_size_children_sum(1), true);
			editor_row_begin();
			
			ui_push_size_x_node(ui_size_txt(1));
			ui_push_size_y_node(ui_size_px(32, 1));
			
			for 0 .. ArtId.COUNT - 1 {
				if current_art == it {
					ui_push_flags_node(.Offset, true);
					ui_push_remove_flags_node(.Shadow, true);
				}
				
				text := tprint("  %  ", it);
				if editor_button(text, xx it).active {
					current_art = it;
				}
			}
			editor_row_end();
			
			ui_push_size_node(ui_size_pct(1, 0), true);
			editor_col_begin();
			
			text := tprint(" Save ");
			if editor_button(text).active {
				save_assets();
			}
			text = tprint(" Load ");
			if editor_button(text).active {
				load_assets();
			}
			editor_row_end();
			
			ui_pop_size_node();
			// save / load
			// draw the art
			// path
			// other art related data
			// "save this"
			
			
		}
	}
	
	if current_mode == .Home {
		scope := tex.scope_open();
		
		ui_push_size_x_node(ui_size_px(960, 0), true);
		ui_push_size_y_node(ui_size_px(540, 0), true);
		editor_image(editor_home_art);
		tex.scope_close(scope);
	}
	
	if current_mode == .Game || current_mode == .Editor {
		ui_push_size_x_node(ui_size_px(1920, 0), true);
		ui_push_size_y_node(ui_size_px(1024, 0), true);
		editor_image_cant_click_lol_bro(.{U64 = .[0, xx scratch_window.game_target.resident]});
	}
	
	editor_row_end();
	editor_pop_file_id();
	editor_window_end(scratch_window);
	
	//text := tprint("%", delta);
	//r.push_text(passes, font, text, .{}, text_size, r.COLOR_BLACK);
	
	counter += 1;
}