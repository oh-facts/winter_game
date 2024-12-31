#import "System";
#import "String";
#import "Basic";
#import "mizu_base";
#import "Math";
#import "File";
r :: #import "render";

ell : r.Handle;
font : *r.Font;

#import "Random";
#load "map_editor.jai";

Vector2i :: struct {
	x : s32;
	y : s32;
}

Vector3i :: struct {
	x : s32;
	y : s32;
	z: s32;
}

main :: () {
	print("Do not enter is written on the doorway, why can't everyone just go away\n");
	print("Except for you, you can stay\n");
	
	os.init();
	win := os.open_window("winter steam game", 960, 540);
	
	r.init();
	
	quit : bool;
	
	start := os.get_perf_counter();
	freq := os.get_perf_freq();
	
	time_elapsed : float64;
	delta : float64;
	
	frames : u64;
	
	arena := arena_init();
	
	base_path := path_strip_filename(get_path_of_running_executable());
	data_folder := join(base_path, "../data");
	
	{
		filename := tprint("%/%", data_folder, "fonts/font.data");
		data := read_entire_file(filename);
		font = xx data.data;
	}
	
	{
		filename := tprint("%/%", data_folder, "fonts/font.png");
		font.bmp = bitmap(arena, filename);
	}
	
	font.img = r.image(font.bmp);
	
	ell_bmp : Bitmap;
	{
		filename := tprint("%/%", data_folder, "art/ell.png");
		ell_bmp = bitmap(arena, filename);;
	}
	
	ell = r.image(ell_bmp);
	
	impolo_bmp : Bitmap;
	{
		filename := tprint("%/%", data_folder, "art/impolo-east.png");
		impolo_bmp = bitmap(arena, filename);;
	}
	
	impolo_art := r.image(impolo_bmp, .NEAREST);
	py_pos : Vector2;
	counter : float32;
	mv : Vector2;
	
	tilemap_paths : [4]string = .["art/tilemap-template16.png", "art/grass16.png", "art/props.png", "art/Tileset.png"];
	tilemap_bmp : [4]Bitmap;
	{
		for tilemap_paths {
			filename := tprint("%/%", data_folder, it);
			tilemap_bmp[it_index] = bitmap(arena, filename);
			tilemap.images[it_index] = r.image(tilemap_bmp[it_index], .NEAREST);
		}
	}
	
	while !quit {
		//print("%\n", frames);
		frames += 1;
		time_since_last := time_elapsed;
		
		events := os.poll_events();
		win_size := os.get_window_size(win);
		
		if os.event(*events, .NULL, .CloseRequested) || os.event(*events, .ESC, .Pressed){
			quit = true;
		}
		
		ui_batches : r.BatchList;
		sprite_batches : r.BatchList;
		
		ifx 0 {
			disco_tilemap(*sprite_batches);
		}
		
		editor_update(xx delta, *events, py_pos, win_size, *sprite_batches, *ui_batches);
		
		// player
		{
			if(os.event(*events, .W, .Pressed))
			{
				mv.y += -1;
			}
			else if(os.event(*events, .W, .Released))
			{
				mv.y -= -1;
			}
			
			if(os.event(*events, .A, .Pressed))
			{
				mv.x += -1;
			}
			else if(os.event(*events, .A, .Released))
			{
				mv.x -= -1;
			}
			
			if(os.event(*events, .D, .Pressed))
			{
				mv.x += 1;
			}
			else if(os.event(*events, .D, .Released))
			{
				mv.x -= 1;
			}
			
			if(os.event(*events, .S, .Pressed))
			{
				mv.y += 1;
			}
			else if(os.event(*events, .S, .Released))
			{
				mv.y -= 1;
			}
			
			py_speed :: 300.;
			py_pos.x += mv.x * xx delta * py_speed;
			py_pos.y += mv.y * xx delta * py_speed;
			
			counter += xx delta;
			
			width := 1.0 / 8.0;
			index := (xx (counter * 10)) % 8;
			
			py_size := Vector2.{64, 64};
			
			py_dst : RectF32;
			py_dst.min.x = py_pos.x;
			py_dst.min.y = py_pos.y;
			py_dst.max.x = py_dst.min.x + py_size.x;
			py_dst.max.y = py_dst.min.y + py_size.y;
			
			py_rect := r.push_rect2(*sprite_batches, py_dst, .{1, 1, 1, 1});
			py_rect.tex_id = impolo_art.U64[1];
			py_rect.src = rectF32(index * width, 0, index * width + width, 1);
		}
		
		r.submit(win, win_size, ui_batches, sprite_batches, py_pos);
		
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

// @debug
disco_tilemap :: (sprite_batches : *r.BatchList) {
	tile_size :: 64;
	for y: 0 .. 64 {
		for x: 0 .. 64 {
			dst : RectF32;
			dst.min.x = xx (x * tile_size);
			dst.min.y = xx (y * tile_size);
			dst.max.x = dst.min.x + tile_size;
			dst.max.y = dst.min.y + tile_size;
			
			colors := Vector4.[r.COLOR_BLACK,
												 r.COLOR_RED,
												 r.COLOR_GREEN,
												 r.COLOR_BLUE,
												 r.COLOR_YELLOW,
												 r.COLOR_CYAN,
												 r.COLOR_MAGENTA,];
			
			color := colors[(x + y) % colors.count];
			
			tile_rect := r.push_rect2(sprite_batches, dst, color);
			//tile_rect.radius = 16;
		}
	}
}