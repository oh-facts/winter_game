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
	//camera.pos.x = xx ((pos.x * Tilemap.col) * Tilemap.tile_size + camera.size.x / 2);
	//camera.pos.y = xx ((pos.y * Tilemap.row) * Tilemap.tile_size + camera.size.y / 2);
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
//#load "simulation.jai";
//#load "map_editor.jai";
//#load "world.jai";
#load "winter.jai";
#load "dialogue";

Mode :: enum {
	Game;
	Tile_Editor;
	COUNT;
}

//current_mode : Mode = .Tile_Editor;
current_mode : Mode = .Game;

arena : *Arena;

random_index : int;

draw_children :: (ui_batches : *r.BatchList, root : *ui.Widget) {
	//print("%\n", root.dst);
	
	colors : [4]Vector4 : .[r.COLOR_WHITE, r.COLOR_RED, r.COLOR_GREEN, r.COLOR_BLUE];
	random_index += 1;
	
	color := colors[3];
	inverse_color := .{1, 1, 1, 2} - color;
	
	r.push_rect2(ui_batches, root.dst, color);
	
	if root.hot {
		inverse_color = r.COLOR_ORANGE;
	}
	
	r.push_text(ui_batches, font, root.text, root.pos, 0.4, inverse_color);
	
	{
		child :=  root.first;
		while child {
			draw_children(ui_batches, child);
			child = child.next;
		}
	}
}

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
		
		ui_batches : r.BatchList;
		sprite_batches : r.BatchList;
		
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
		ui.widget_impl(ui_cxt, "hello", 1);
		ui.widget_impl(ui_cxt, "hello", 2);
		ui.widget_impl(ui_cxt, "hello2", 3);
		
		col := ui.widget_from_key(ui_cxt, 4);
		ui.push_parent_node(ui_cxt, col);
		col.child_layout_axis = .Y;
		col.pref_size[0].kind = .ChildrenSum;
		col.pref_size[1].kind = .ChildrenSum;
		
		ui.widget_impl(ui_cxt, "hello3", 9);
		ui.widget_impl(ui_cxt, "hello3", 10);
		ui.widget_impl(ui_cxt, "hello3", 11);
		ui.widget_impl(ui_cxt, "hello3", 12);
		ui.pop_parent_node(ui_cxt);
		
		ui.widget_impl(ui_cxt, "hello34", 13);
		ui.layout(ui_cxt.root);
		
		//print("----\n");
		draw_children(*ui_batches, ui_cxt.root);
		//print("----\n");
		ui.end(ui_cxt);
		
		if os.event(*events, .TAB, .Pressed) {
			current_mode = (current_mode + 1) % .COUNT;
		}
		
		if current_mode == {
			case .Game;
			//world_update(xx delta, *events, *sprite_batches, *ui_batches);
			
			case .Tile_Editor;
			//editor_update(xx delta, *events, *sprite_batches, *ui_batches);
		}
		
		r.submit(win, camera.size, ui_batches,  sprite_batches, camera.pos);
		
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