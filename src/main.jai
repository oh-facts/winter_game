// TODO(mizu): Make it so that tilemap uses world position instead of local / ...

// Infact, get rid of tilemap world and
// game world. Just have one. 
// After that, in load entities, make a load
// entity and use that fn in the editor
// to alloc entities

// change all engine imports to load.
// modules make sense for ext libraries
// where I can't control the namespace.

// TODO(mizu): Also, fix that annoying map editor bug you've been working around.
// also bug in the ui layer. padding doesn't add up for some reason. Fix that first.

// For stuff like picking, I am thinking I just use the per frame entity map.

#import "Basic";
#import "System";
#import "String";
#import "Math";
#import "File";
#import "IntroSort";
#import "Random";
#import "Thread";
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
beam_pos : Vector2;

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

// TODO(mizu): Needs to go.
rmb_held : bool;

scroll_up : bool;
scroll_down : bool;

Mode :: enum {
	Tile_Editor;
	Game;
	Scratch;
	COUNT;
}

//current_mode : Mode = .Tile_Editor;
current_mode : Mode = .Game;
//current_mode : Mode = .Scratch;

arena : *Arena;

main :: () {
	print("Do not enter is written on the doorway, why can't everyone just go away\n");
	print("Except for you, you can stay\n");
	
	os.init();
	win := os.open_window("winter steam game", 960, 540);
	r.init();
	tex.init();
	
	start := os.get_perf_counter();
	freq := os.get_perf_freq();
	
	time_elapsed : float64;
	delta : float64;
	
	frames : u64;
	
	arena = arena_init(ARENA_COMMIT_SIZE, MB(256));
	
	load_all_assets();
	quit : bool;
	
	ui_cxt := ui_init();
	editor_ui_cxt = ui_cxt;
	timer : float32;
	
	while !quit {
		timer += xx delta;
		
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
		
		mm_event := os.event(*events, .NULL, .MouseMove);
		scroll_event := os.event(*events, .NULL, .Scroll);
		
		update_camera();
		
		scroll_up = false;
		scroll_down = false;
		
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
		
		r.push_scissor(*passes, rectF32(0, 0, win_size.x, win_size.y));
		ui_begin(ui_cxt, *events, mpos);
		
		if os.event(*events, .TAB, .Pressed) {
			current_mode = (current_mode + 1) % .COUNT;
		}
		
		if current_mode == {
			case .Game;
			world_update(xx delta, *events, *passes);
			
			case .Tile_Editor;
			editor_update(xx delta, *events, *passes);
			
			case .Scratch;
			scratch_update(xx delta, *events, *passes);
		}
		
		ui_layout(ui_cxt.root);
		
		//print("----\n");
		
		
		draw_children(*passes, ui_cxt.root);
		
		//print("----\n");
		ui_end();
		r.pop_scissor(*passes);
		
		r.submit(timer, win, camera.size, passes, beam_pos, camera.pos);
		
		//editor_tick_clock();
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
	}
	
	print("quit safely\n");
}