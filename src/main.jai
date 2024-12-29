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
			
			map_outline := r.push_rect2(*sprite_batches, rectF32(32, 32, (tilemap.col - 1)* 32, (tilemap.row - 1) * 32), .{0, 0, 0, 0});
			map_outline.border_color = r.COLOR_BLACK;
			map_outline.border_thickness = 4;
			
			mb_event := os.event(*events, .LMB, .Pressed);
			mm_event := os.event(*events, .NULL, .MouseMove);
			
			mclick : bool;
			
			if mb_event {
				mclick = true; 
			}
			
			if mm_event {
				mpos = mm_event.mpos;
				
				wmpos.x = mpos.x + py_pos.x - 480;
				wmpos.y = mpos.y + py_pos.y - 270;
				
				tile_pos.x = xx ((wmpos.x) / 32);
				tile_pos.y = xx ((wmpos.y) / 32);
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
								
								// common 16 =========
								case 28; out = .{0, 0};
								case 31; out = .{0, 1};
								case 7; out = .{0, 2};
								
								case 124; out = .{1, 0};
								case 255; out = .{1, 1};
								case 199; out = .{1, 2};
								
								case 112; out = .{2, 0};
								case 241; out = .{2, 1};
								case 193; out = .{2, 2};
								
								// =========== common 9
								case 16; out = .{3, 0};
								case 17; out = .{3, 1};
								case 1; out = .{3, 2};
								
								case 4; out = .{0, 3};
								case 68; out = .{1, 3};
								case 64; out = .{2, 3};
								
								case 0; out = .{3, 3};
								
								// ========== common 16
								
								// 2 adj sides + opp corner
								case 20; out = .{4, 0}; 
								case 80; out = .{5, 0};
								case 5; out = .{4, 1};
								case 65; out = .{5, 1};
								// ===================
								
								// 1 side + 2 corners
								case 84; out = .{6, 0};
								case 69; out = .{7, 0};
								case 21; out = .{6, 1};
								case 81; out = .{7, 1};
								// ==================
								
								// 1 corner
								case 247; out = .{4, 2};
								case 223; out = .{5, 2};
								case 253; out = .{4, 3};
								case 127; out = .{5, 3};
								// =========
								
								// 2 corner
								case 215; out = .{6, 2};
								case 125; out = .{7, 2};
								case 245; out = .{6, 3};
								case 95; out = .{7, 3};
								// ========
								
								// l/r side + 1 corner
								case 29; out = .{0, 4};
								case 113; out = .{1, 4};
								case 23; out = .{0, 5};
								case 209; out = .{1, 5};
								// ====
								
								//t/d side + 1 corner 
								case 92; out = .{2, 4};
								case 116; out = .{3, 4};
								case 71; out = .{2, 5};
								case 197; out = .{3, 5};
								// =====
								
								// 3 corners ==========
								case 93; out = .{4, 4};
								case 117; out = .{5, 4};
								case 87; out = .{4, 5};
								case 213; out = .{5, 5};
								// ===
								
								// opposite corners ====
								case 221; out = .{6, 4};
								case 119; out = .{6, 5};
								// ====
								
								// 4 corners ====
								case 85; out = .{7, 4};
								// ====
								
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
			
			// grid outline
			
			for y: 1 .. tilemap.row - 1 - 1 {
				for x: 1 .. tilemap.col - 1 - 1 {
					
					tile := tilemap.tiles[x * tilemap.col + y];
					
					dst : RectF32;
					dst.min.x = xx (x * 32);
					dst.min.y = xx (y * 32);
					dst.max.x = dst.min.x + 32;
					dst.max.y = dst.min.y + 32;
					
					tile_rect := r.push_rect2(*sprite_batches, dst, .{});
					tile_rect.border_thickness = 4;
					tile_rect.border_color = r.COLOR_BLACK;
					
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
		text := tprint("mpos: %\nwmpos:{% %}\ntpos:%", mpos, cast(s32) wmpos.x, cast(s32) wmpos.y, tile_pos);
		
		text_pos : Vector2 = .{0, 0};
		text_size := 0.4;
		
		ext := r.get_text_rect(font, text, text_pos, text_size);
		r.push_rect2(*ui_batches, ext, .{0, 0, 0, 0.9});
		
		r.push_text(*ui_batches, font, text, text_pos, text_size, r.COLOR_ORANGE);
		
		text_pos.y += ext.max.y - ext.min.y;
		ell_rect : RectF32;
		ell_rect.min.x = 0;
		ell_rect.max.x = 80;
		ell_rect.min.y = text_pos.y;
		ell_rect.max.y = ell_rect.min.y + 80;
		test := r.push_rect2(*ui_batches, ell_rect, .{1, 1, 1, 1});
		test.tex_id = ell.U64[1];
		test.radius = 40;
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