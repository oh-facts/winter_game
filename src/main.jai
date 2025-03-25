// TODO(mizu): When I come back, I need to make a different ui cxt for the engine window and the game windows. dont couple it with the editor. and remove editor context. make push pop functions for context. better yet, make begin and end push pop ui cxt.

// TODO(mizu): See if you can make them use the same context but different render list

// TODO(mizu): Scissoring

// TODO(mizu): proper pixel -> ui co-ordinates / world co-ordinates

// TODO(mizu): Remove scroll global

// TODO(mizu): take it one at a time, just make sure it works. Maybe start with toggle fullscreen. Then making render submit take a target size. Then work on scissoring and mouse co ords -> ui coords



#import "Basic";
#import "System";
#import "String";
#import "Math";
#import "File";
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

// TODO(mizu): Needs to go.
rmb_held : bool;

Mode :: enum {
	Home;
	Editor;
	Game;
	Scratch;
	Profiler;
	Asset;
	COUNT;
}

//current_mode : Mode = .Editor;
//current_mode : Mode = .Game;
//current_mode : Mode = .Scratch;
//current_mode : Mode = .Home;
current_mode : Mode = .Asset;

arena : *Arena;
win : os.Handle;
game_ui_cxt : *UI_State;
map_editor_window : *Editor_Window;
entity_tree_window : *Editor_Window;
dialogue_window : *Editor_Window;
combat_window : *Editor_Window;

main :: () {
	print("Do not enter is written on the doorway, why can't everyone just go away\n");
	print("Except for you, you can stay\n");
	
	os.init();
	win = os.open_window("The sad debugger", 960 + 32, 540 + 64);
	win_size := os.get_window_size(win);
	r.init(.{1920, 1024});
	tex.init();
	
	start := os.get_perf_counter();
	freq := os.get_perf_freq();
	
	time_elapsed : float64;
	delta : float64;
	
	frames : u64;
	
	arena = arena_init(ARENA_COMMIT_SIZE, MB(128));
	
	load_all_assets();
	quit : bool;
	
	ui_cxt := ui_init();
	game_ui_cxt = ui_init();
	
	timer : float32;
	
	entity_store = entity_store_init();
	tileworld = init_tileworld();
	anim_store = animation_store_init();
	load_entities(*entity_store);
	load_tileworld(*tileworld);
	scratch_window = editor_init_window("~~~~ The Sad Debugger 1 Million <3 ~~~~", .Draw_Titlebar | .Resizable);
	
	map_editor_window = editor_init_window("map editor", .Draw_Titlebar | .Scrollable | .Resizable | .Dialog, .{0, 64});
	entity_tree_window = editor_init_window("entity tree", .Draw_Titlebar | .Scrollable | .Resizable | .Dialog, .{800, 64});
	dialogue_window = editor_init_window("dialogue window", .Dialog, .{400, 400}, .{600, 200});
	combat_window = editor_init_window("combat window", .Dialog, .{0, 64}, .{600, 200});
	
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
		
		mm_event := os.event(*events, .NULL, .MouseMove);
		
		update_camera();
		
		if mm_event {
			mpos = mm_event.mpos;
		}
		
		r.push_scissor(*passes, rectF32(0, 0, scratch_window.win_target.size.x, scratch_window.win_target.size.y));
		ui_begin(ui_cxt, *events, mpos);
		scratch_update(xx delta, *events, *passes);
		ui_layout(ui_cxt.root);
		editor_window_update(scratch_window);
		draw_children(*passes, ui_cxt.root);
		
		if !scratch_window.resize_grabbed {
			if game_ui_cxt.root {
				ui_layout(game_ui_cxt.root);
				editor_window_update(map_editor_window);
				editor_window_update(entity_tree_window);
				editor_window_update(dialogue_window);
				editor_window_update(combat_window);
				
				r.push_scissor(*passes, scratch_window.client_rect.dst);
				draw_children(*passes, game_ui_cxt.root);
				r.pop_scissor(*passes);
			}
		}
		//print("----\n");
		
		//print("----\n");
		ui_end();
		r.pop_scissor(*passes);
		
		r.submit(timer, scratch_window.win_target, win_size, passes, .{});
		r.present(scratch_window.win_target, win);
		
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
		
		if !scratch_window.hide {
			os.set_window_size(win, scratch_window.size);
		} else {
			os.set_window_size(win, .{scratch_window.size.x, 32});
		}
		os.set_window_pos(win, scratch_window.pos);
		
		if scratch_window.close_requested {
			quit = true;
		}
	}
	
	print("quit safely\n");
}