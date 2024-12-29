#import "System";
#import "String";
#import "Basic";
#import "mizu_base";
#import "Math";
#import "File";
r :: #import "render";
ui :: #import "ui";

// @debug
mpos : Vector2;
wmpos : Vector2;

tile_pos : Vector2i;

Vector2i :: struct {
	x : s32;
	y : s32;
}

Tile :: struct {
	//uv : Vector2i = .{1, 1};
	alpha : bool;
};

Tilemap :: struct {
	row :: 10;
	col :: 10;
	tiles : [col * row]Tile;
	image : r.Handle;
	uv_col :: 8;
	uv_row :: 6;
};

tilemap : Tilemap;

#import "Random";
draw_children :: (root : *ui.Widget) {
	
	print("%\n", root.pref_size);
	
	{
		child :=  root.first;
		while child {
			draw_children(child);
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
	
	ui_cxt := ui.init();
	
	quit : bool;
	
	start := os.get_perf_counter();
	freq := os.get_perf_freq();
	
	time_elapsed : float64;
	delta : float64;
	
	frames : u64;
	
	arena := arena_init();
	
	base_path := path_strip_filename(get_path_of_running_executable());
	data_folder := join(base_path, "../data");
	
	font : *r.Font;
	
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
	
	ell := r.image(ell_bmp);
	
	impolo_bmp : Bitmap;
	{
		filename := tprint("%/%", data_folder, "art/impolo-east.png");
		impolo_bmp = bitmap(arena, filename);;
	}
	
	impolo_art := r.image(impolo_bmp, .NEAREST);
	py_pos : Vector2;
	counter : float32;
	mv : Vector2;
	
	tilemap_bmp : Bitmap;
	{
		filename := tprint("%/%", data_folder, "art/tilemap-template.png");
		tilemap_bmp = bitmap(arena, filename);;
	}
	
	tilemap.image = r.image(tilemap_bmp, .NEAREST);
	
	while !quit {
		//print("%\n", frames);
		frames += 1;
		time_since_last := time_elapsed;
		
		events := os.poll_events();
		
		if os.event(*events, .NULL, .CloseRequested) || os.event(*events, .ESC, .Pressed){
			quit = true;
		}
		
		/*
		ui.begin(ui_cxt);
		ui.label(ui_cxt, "hello");
		ui.label(ui_cxt, "hello");
		ui.label(ui_cxt, "hello");
		
		ui.layout(ui_cxt.root);
		
		print("----\n");
		draw_children(ui_cxt.root);
		print("----\n");
		ui.end(ui_cxt);
		*/
		
		ui_batches : r.BatchList;
		sprite_batches : r.BatchList;
		
		// tilemap
		{
			ifx 0 {
				disco_tilemap(*sprite_batches);
			}
			
			mb_event := os.event(*events, .LMB, .Pressed);
			mclick : bool;
			
			if mb_event {
				mpos = mb_event.mpos;
				
				wmpos.x = mpos.x + py_pos.x - 480;
				wmpos.y = mpos.y + py_pos.y - 270;
				
				tile_pos.x = xx ((wmpos.x) / 32);
				tile_pos.y = xx ((wmpos.y) / 32);
				
				mclick = true; 
			}
			
			if mclick {
				tilemap.tiles[tile_pos.x * tilemap.col + tile_pos.y].alpha = true;
			}
			
			for y: 0 .. tilemap.row - 1{
				for x: 0 .. tilemap.col - 1 {
					
					tile := tilemap.tiles[x * tilemap.col + y];
					
					if tile.alpha {
						
						TileNeighbours :: struct {
							t  : bool;
							b  : bool;
							l  : bool;
							r  : bool;
							tl : bool;
							tr : bool;
							bl : bool;
							br : bool;
						};
						
						get_neighbours :: (map : Tilemap, index : Vector2i) -> TileNeighbours {
							out : TileNeighbours;
							using out;
							
							tile_present :: (map : Tilemap, _index : Vector2i) -> bool {
								return map.tiles[_index.x * map.col + _index.y].alpha;
							}
							
							t  = tile_present(map, .{index.x, index.y - 1}); 
							tr = tile_present(map, .{index.x + 1, index.y - 1}); 
							r = tile_present(map, .{index.x + 1, index.y}); 
							br = tile_present(map, .{index.x + 1, index.y + 1}); 
							b = tile_present(map, .{index.x, index.y + 1}); 
							bl = tile_present(map, .{index.x - 1, index.y + 1}); 
							l = tile_present(map, .{index.x - 1, index.y}); 
							tl = tile_present(map, .{index.x - 1, index.y - 1}); 
							
							return out;
						}
						
						tile_bitmask :: (_neighbours : TileNeighbours) -> u8 {
							
							neighbours := _neighbours;
							using neighbours;
							
							if !(t && l) tl = false;
							if !(t && r) tr = false;
							if !(b && l) bl = false;
							if !(b && r) br = false;
							
							out : u8;
							
							if t  out += (1 << 0);
							if tr out += (1 << 1);
							if r  out += (1 << 2);
							if br out += (1 << 3);
							if b  out += (1 << 4);
							if bl out += (1 << 5);
							if l  out += (1 << 6);
							if tl out += (1 << 7);
							
							return out;
						}
						
						uv_from_bitmask :: (bitmask : u8) -> Vector2i {
							out : Vector2i;
							
							if bitmask == {
								case 28; out = .{0, 0};
								case 31; out = .{0, 1};
								case 7; out = .{0, 2};
								
								case 124; out = .{1, 0};
								case 255; out = .{1, 1};
								case 199; out = .{1, 2};
								
								case 112; out = .{2, 0};
								case 241; out = .{2, 1};
								case 193; out = .{2, 2};
								
								
								
								case; out = .{1, 1};
							}
							
							return out;
						};
						
						dst : RectF32;
						dst.min.x = xx (x * 32);
						dst.min.y = xx (y * 32);
						dst.max.x = dst.min.x + 32;
						dst.max.y = dst.min.y + 32;
						
						index :Vector2i= .{xx x, xx y};
						
						neighbours := get_neighbours(tilemap, index);
						bitmask := tile_bitmask(neighbours);
						
						uv := uv_from_bitmask(bitmask);
						
						src : RectF32;
						src.min.x = (cast(float32)uv.x / tilemap.uv_col);
						src.max.y = (cast(float32)uv.y / tilemap.uv_row);
						src.max.x = src.min.x + 1. / tilemap.uv_col;
						src.min.y = src.max.y + 1. / tilemap.uv_row;
						
						src.min.y = 1 - src.min.y;
						src.max.y = 1 - src.max.y;
						
						//print("%\n", src);
						
						tile_rect := r.push_rect2(*sprite_batches, dst, r.COLOR_WHITE);
						tile_rect.tex_id = tilemap.image.U64[1];
						tile_rect.src = src;
						
						
						//print("%\n", bitmask);
						
					}
				}
			}
			
		}
		
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
			
			py_size := Vector2.{128, 128};
			
			py_dst : RectF32;
			py_dst.min.x = py_pos.x;
			py_dst.min.y = py_pos.y;
			py_dst.max.x = py_dst.min.x + py_size.x;
			py_dst.max.y = py_dst.min.y + py_size.y;
			
			py_rect := r.push_rect2(*sprite_batches, py_dst, .{1, 1, 1, 1});
			py_rect.tex_id = impolo_art.U64[1];
			py_rect.src = rectF32(index * width, 0, index * width + width, 1);
		}
		
		// @debug text
		text := tprint("%\n%\n%", mpos, tile_pos, wmpos);
		
		text_pos : Vector2 = .{0, 0};
		text_size := 0.6;
		
		ext := r.get_text_rect(font, text, text_pos, text_size);
		r.push_rect2(*ui_batches, ext, .{0, 0, 0, 0.9});
		
		r.push_text(*ui_batches, font, text, text_pos, text_size, r.COLOR_ORANGE);
		test := r.push_rect2(*ui_batches, rectF32(0, 400, 80, 480), .{1, 1, 1, 1});
		test.tex_id = ell.U64[1];
		
		r.submit(win, ui_batches, sprite_batches, py_pos);
		
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
	for y: 0 .. 64 {
		for x: 0 .. 64 {
			dst : RectF32;
			dst.min.x = xx (x * 32);
			dst.min.y = xx (y * 32);
			dst.max.x = dst.min.x + 32;
			dst.max.y = dst.min.y + 32;
			
			colors := Vector4.[r.COLOR_BLACK,
												 r.COLOR_RED,
												 r.COLOR_GREEN,
												 r.COLOR_BLUE,
												 r.COLOR_YELLOW,
												 r.COLOR_CYAN,
												 r.COLOR_MAGENTA,];
			
			color := colors[(x + y) % colors.count];
			
			tile_rect := r.push_rect2(sprite_batches, dst, color);
			tile_rect.radius = 16;
		}
	}
}