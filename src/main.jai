#import "Basic";
#import "System";
#import "String";
#import "Math";
#import "File";
#import "IntroSort";
#import "Random";

#import "mizu_base";
r :: #import "render";
ui :: #import "ui";

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

set_camera_size :: (size : Vector2) {
	camera.size = size;
}

set_camera_pos :: (pos : Vector2i) {
	camera.pos.x = xx ((pos.x * Tilemap.col) * Tilemap.tile_size + camera.size.x / 2);
	camera.pos.y = xx ((pos.y * Tilemap.row) * Tilemap.tile_size + camera.size.y / 2);
}

update_camera :: () {
	// mouse coords -> world space coords
	wmpos.x = mpos.x + camera.pos.x - camera.size.x / 2.;
	wmpos.y = mpos.y + camera.pos.y - camera.size.y / 2.;
}

mpos : Vector2;
lmb_held : bool;
rmb_held : bool;
lmb_down : bool;
lmb_up : bool;
scroll_up : bool;
scroll_down : bool;

#load "asset.jai";
#load "editor.jai";
#load "simulation.jai";
#load "map_editor.jai";
#load "world.jai";
#load "winter.jai";
#load "dialogue";

/*
editor_window_begin(*ui_batches, map_editor_window);
		if !map_editor_window.hide {
			
			editor_label("text");
			editor_label("text");
		}
		editor_window_end(map_editor_window);
*/

Mode :: enum {
	Game;
	Tile_Editor;
	COUNT;
}

current_mode : Mode = .Tile_Editor;
//current_mode : Mode = .Game;

arena : *Arena;

main :: () {
	print("Do not enter is written on the doorway, why can't everyone just go away\n");
	print("Except for you, you can stay\n");
	
	os.init();
	win := os.open_window("winter steam game", 960, 540);
	
	r.init();
	
	start := os.get_perf_counter();
	freq := os.get_perf_freq();
	
	time_elapsed : float64;
	delta : float64;
	
	frames : u64;
	
	arena = arena_init();
	
	load_all_assets();
	ui.set_font(font);
	quit : bool;
	
	ui_cxt := ui.init();
	editor_ui_cxt = ui_cxt;
	
	while !quit {
		//print("%\n", frames);
		frames += 1;
		time_since_last := time_elapsed;
		
		events := os.poll_events();
		win_size := os.get_window_size(win);
		set_camera_size(win_size);
		
		if os.event(*events, .NULL, .CloseRequested) || os.event(*events, .ESC, .Pressed){
			quit = true;
		}
		
		passes : r.Pass_List;
		
		lmbdown_event := os.event(*events, .LMB, .Pressed);
		lmbup_event := os.event(*events, .LMB, .Released);
		
		mm_event := os.event(*events, .NULL, .MouseMove);
		scroll_event := os.event(*events, .NULL, .Scroll);
		
		update_camera();
		
		lmb_down = false;
		lmb_up = false;
		scroll_up = false;
		scroll_down = false;
		
		if lmbdown_event {
			lmb_held = true;
			lmb_down = true;
		}
		
		if lmbup_event {
			lmb_held = false;
			lmb_up = true;
		}
		
		if mm_event {
			mpos = mm_event.mpos;
		}
		
		if scroll_event {
			
			if scroll_event.wheel > 0 {
				scroll_up = true;
			}
			
			else if scroll_event.wheel < 0 {
				scroll_down = true;
			}
			
		}
		
		ui.begin(ui_cxt, mpos, lmb_down);
		
		if os.event(*events, .TAB, .Pressed) {
			current_mode = (current_mode + 1) % .COUNT;
		}
		
		if current_mode == {
			case .Game;
			world_update(xx delta, *events, *passes);
			
			case .Tile_Editor;
			editor_update(xx delta, *events, *passes);
		}
		
		ui.layout(ui_cxt.root);
		
		//print("----\n");
		draw_children(*passes, ui_cxt.root);
		//print("----\n");
		ui.end(ui_cxt);
		
		r.submit(win, camera.size, passes, camera.pos);
		
		//editor_tick_clock();
		
		end := os.get_perf_counter();
		time_elapsed = (end - start) / (freq * 1.);
		delta = time_elapsed - time_since_last;
		
		// poor man's vsync--------------------------------
		ifx false {
			time_left : float64 = (1 / 60.) - delta;
			if (time_left > 0) 
			{
				os.sleep(xx (time_left * 1000));
			}
		}
		// -------------------------------------------------
		//print("%\n", delta);
		
		reset_temporary_storage();
	}
	
	print("quit safely\n");
}