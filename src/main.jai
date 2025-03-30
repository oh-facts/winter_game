// TODO(mizu): When I come back, I need to make a different ui cxt for the engine window and the game windows. dont couple it with the editor. and remove editor context. make push pop functions for context. better yet, make begin and end push pop ui cxt.

// TODO(mizu): See if you can make them use the same context but different render list

// TODO(mizu): take it one at a time, just make sure it works. Maybe start with toggle fullscreen. Then making render submit take a target size. Then work on scissoring and mouse co ords -> ui coords

// TODO(mizu): Consider making monofunctions

#import "Basic";
#import "System";
#import "String";
#import "Math";
#import "File";
#import "File_Utilities";
#import "IntroSort";
#import "Random";
#import "Thread";
#import "Compiler";

#import "mizu_base";
r :: #import "render";
tex :: #import "texture";

#load "asset.jai";
#load "editor.jai";
#load "simulation.jai";
#load "map_editor.jai";
#load "world.jai";

#load "dialogue.jai";
#load "scratch.jai";
#load "ui.jai";

// hee haw camera
cam_wheld : bool;
cam_aheld : bool;
cam_sheld : bool;
cam_dheld : bool;

Camera :: struct {
	pos : Vector2;
	size : Vector2;
}

camera : Camera;

wmpos : Vector2;
wmpos_last : Vector2;

set_camera_size :: (size : Vector2) {
	camera.size = size;
}

set_camera_pos :: (pos : Vector2i) {
	camera.pos.x = xx ((pos.x * Tilemap.col) * Tilemap.tile_size + camera.size.x / 2);
	camera.pos.y = xx ((pos.y * Tilemap.row) * Tilemap.tile_size + camera.size.y / 2);
}

update_camera :: () {
	wmpos_last = wmpos;
	
	// mouse coords -> world space coords
	wmpos.x = mpos.x + camera.pos.x - camera.size.x / 2.;
	wmpos.y = mpos.y + camera.pos.y - camera.size.y / 2. - 64;
}

mpos : Vector2;

Mode :: enum {
	Home;
	Editor;
	Game;
	Asset;
	COUNT;
	Scratch;
}

current_mode : Mode = .Editor;
//current_mode : Mode = .Game;
//current_mode : Mode = .Scratch;
//current_mode : Mode = .Home;
//current_mode : Mode = .Asset;

arena : *Arena;
win : os.Handle;
game_ui_cxt : *UI_State;
map_editor_window : *Editor_Window;
entity_tree_window : *Editor_Window;
dialogue_window : *Editor_Window;
combat_window : *Editor_Window;
main_window : *Editor_Window;

main :: () {
	print("Do not enter is written on the doorway, why can't everyone just go away\n");
	print("Except for you, you can stay\n");
	
	os.init();
	win = os.open_window("The sad debugger", 960 + 32, 540 + 32);
	win_size := os.get_window_size(win);
	r.init(.{1920, 1024});
	tex.init();
	
	start := os.get_perf_counter();
	freq := os.get_perf_freq();
	
	time_elapsed : float64;
	delta : float64;
	
	frames : u64;
	
	arena = arena_init(ARENA_COMMIT_SIZE, MB(128));
	asset_init();
	
	quit : bool;
	
	ui_cxt := ui_init();
	game_ui_cxt = ui_init();
	
	timer : float32;
	
	entity_store = entity_store_init();
	tileworld = init_tileworld();
	
	anim_store = animation_store_init();
	load_entities(*entity_store);
	load_tileworld(*tileworld);
	//scratch_window = editor_init_window("~~~~ The Sad Debugger 1 Million <3 ~~~~", .Draw_Titlebar | .Resizable);
	main_window = editor_init_window("~~~~ Please Enjoy Every Mode Equally ~~~~", .Draw_Titlebar | .Resizable);
	
	map_editor_window = editor_init_window("map editor", .Draw_Titlebar | .Scrollable | .Resizable | .Dialog, .{0, 64});
	entity_tree_window = editor_init_window("entity tree", .Draw_Titlebar | .Scrollable | .Resizable | .Dialog, .{800, 64});
	dialogue_window = editor_init_window("dialogue window", .Dialog, .{400, 400}, .{600, 200});
	combat_window = editor_init_window("combat window", .Dialog, .{0, 32}, .{600, 200});
	
	files = file_list(art_folder);
	
	while !quit {
		timer += xx delta;
		
		//print("%\n", frames);
		frames += 1;
		time_since_last := time_elapsed;
		
		events := os.poll_events();
		win_size = os.get_window_size(win);
		set_camera_size(.{1920, 1024});
		
		//print("win size: %\n", win_size);
		
		if os.event(*events, .NULL, .CloseRequested) || os.event(*events, .ESC, .Pressed){
			quit = true;
		}
		
		passes : r.Pass_List;
		
		mpos = os.get_mouse_pos(win);
		
		update_camera();
		
		r.push_scissor(*passes, rectF32(0, 0, main_window.win_target.size.x, main_window.win_target.size.y));
		ui_begin(ui_cxt, *events, mpos);
		
		main_window_update(xx delta, *events);
		
		ui_layout(ui_cxt.root);
		draw_children(*passes, ui_cxt.root);
		
		if !main_window.resize_grabbed {
			if game_ui_cxt.root {
				ui_layout(game_ui_cxt.root);
				r.push_scissor(*passes, main_window.client_rect.dst);
				draw_children(*passes, game_ui_cxt.root);
				r.pop_scissor(*passes);
			}
		}
		
		ui_end();
		r.pop_scissor(*passes);
		
		r.submit(timer, main_window.win_target, win_size, passes, .{});
		r.present(main_window.win_target, win);
		
		editor_tick_clock();
		tex.clock_tick();
		
		tex.evict_textures();
		
		end := os.get_perf_counter();
		time_elapsed = (end - start) / (freq * 1.);
		delta = time_elapsed - time_since_last;
		
		// poor man's vsync--------------------------------
#if false {
			time_left : float64 = (1 / 60.) - delta;
			if (time_left > 0)
			{
				os.sleep(xx (time_left * 1000));
			}
		}
		// -------------------------------------------------
		//print("%\n", delta);
		
		reset_temporary_storage();
		
		if !main_window.hide {
			os.set_window_size(win, main_window.size);
		} else {
			os.set_window_size(win, .{main_window.size.x, 32});
		}
		os.set_window_pos(win, main_window.pos);
		
		if main_window.close_requested {
			quit = true;
		}
	}
	
	print("quit safely\n");
}

timer : float32;

main_window_update :: (delta : float32, events : *os.EventList) {
	timer += xx delta;
	
	editor_window_begin(main_window, events);
	
	editor_push_file_id(.Main);
	
	ui_push_size_node(ui_size_pct(1, 0), true);
	editor_col_begin();
	game_ui_cxt.root = xx 0;
	
	if !main_window.hide {
		ui_push_size_x_node(ui_size_pct(1, 0), true);
		ui_push_size_y_node(ui_size_children_sum(1), true);
		editor_row_begin();
		
		passes2 : r.Pass_List;
		r.push_scissor(*passes2, rectF32(0, 0, 1920, 1024));
		
		editor_mpos := mpos;
		//editor_mpos.x *= 1920. / (1920 - 32);
		//editor_mpos.x *= main_window.game_target.size.x / main_window.client_rect.size.x;
		//editor_mpos.y *= main_window.game_target.size.y / (main_window.client_rect.size.y);
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
			scratch_update(xx delta, events, *passes2);
		}
		
		tab_event := os.event(events, .TAB, .Pressed);
		
		if  tab_event {
			if tab_event.shift_held {
				current_mode = (current_mode - 1) % .COUNT;
			} else {
				current_mode = (current_mode + 1) % .COUNT;
			}
		}
		
		r.submit(timer, main_window.game_target, .{1920, 1024}, passes2, camera.pos);
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
				
				art := get_art(*art_store, it);
				
				if current_art == art {
					ui_push_flags_node(.Offset, true);
					ui_push_remove_flags_node(.Shadow, true);
				}
				
				text := tprint("  %  ", it);
				if editor_button(text, xx it).active {
					current_art = art;
				}
			}
			editor_row_end();
			
			ui_push_size_node(ui_size_pct(1, 0), true);
			editor_col_begin();
			
			{
				if current_art {
					
					// art editor
					
					scope := tex.scope_open();
					img := tex.handle_from_hash(scope, current_art.hash);
					
					w := img.U32[0];
					h := img.U32[1];
					
					ui_push_size_x_node(ui_size_px(xx w), true);
					ui_push_size_y_node(ui_size_px(xx h), true);
					
					editor_image(img);
					
					tex.scope_close(scope);
					
					editor_struct_edit(<< current_art, xx 0, xx current_art);
					
				}
			}
			
			text := tprint(" Save ");
			if editor_button(text).active {
				save_assets();
			}
			text = tprint(" Load ");
			if editor_button(text).active {
				load_assets();
			}
			text = tprint(" Submit ");
			if editor_button(text).active {
				submit_assets();
			}
			
			editor_row_end();
			
			// button
			ui_pop_size_node();
		}
	}
	
	if current_mode == .Home {
		scope := tex.scope_open();
		
		size := main_window.client_rect.size;
		
		ui_push_size_x_node(ui_size_px(size.x, 0), true);
		ui_push_size_y_node(ui_size_px(size.y, 0), true);
		editor_image(editor_home_art);
		tex.scope_close(scope);
	}
	
	if current_mode == .Game || current_mode == .Editor {
		ui_push_size_x_node(ui_size_px(1920, 0), true);
		ui_push_size_y_node(ui_size_px(1024, 0), true);
		editor_image_cant_click_lol_bro(.{U64 = .[0, xx main_window.game_target.resident]});
	}
	
	editor_row_end();
	editor_pop_file_id();
	editor_window_end(main_window);
}