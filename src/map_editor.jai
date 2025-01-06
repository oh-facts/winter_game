Tile_Kind :: enum {
	Grass;
	Dirt;
	Player;
	Tree;
	Ball;
}

map_editor_camera_pos : Vector2;

Tool_Kind :: enum {
	Select;
	Paint;
	Move;
	Fill;
}

Tool :: struct {
	kind : Tool_Kind;
	name : string;
};

tools : [4]Tool : .[.{kind = .Select, name = "select"},
										.{kind = .Paint, name = "paint"},
										.{kind = .Move, name = "move"},
										.{kind = .Fill, name = "fill"}
										];

Tile :: struct {
	paint_index : s32;
};

Paint :: struct {
	auto : bool;
	prop : bool;
	empty : bool;
	kind : Tile_Kind;
	name : string;
	art_id : ArtId;
	
	// i was thinking of using this as an offset into an image. So imagine a massive image with .. I don't feel like writing the rest I am particularly sad.
	src : RectF32;
	
	frame_x : s32;
	frame_y : s32;
	frame_n : s32;
	
	// used by props
	size : Vector2i;
	origin : Vector2;
};

paints : [8]Paint : .[.{empty = true},
											.{auto = true, art_id = .TerrainTemplate, name = "template 1"},
											.{auto = true, art_id = .TerrainGrass, name = "auto grass", kind = .Grass},
											.{auto = false, art_id = .TilesForest, name = "grass", src = .{.{0, 0},.{1, 1}}, frame_x = 8, frame_y = 15, frame_n = 9, kind = .Grass},
											.{auto = false, art_id = .TilesForest, name = "dirt", src = .{.{0, 0},.{1, 1}}, frame_x = 8, frame_y = 15, frame_n = 6, kind = .Dirt},
											.{auto = false, art_id = .Impolo, name = "player", kind = .Player, size = .{64, 64}, origin = .{32, 64}, src = .{.{0, 0}, .{1, 1}}, frame_x = 8, frame_y = 1, prop = true, kind = .Player},
											.{auto = false, art_id = .Tree, name = "tree", kind = .Tree, size = .{512, 512}, src = .{.{0, 0}, .{1, 1}}, frame_x = 3, frame_y = 1, frame_n = 0, origin = .{256, 380}, prop = true},
											.{art_id = .Ball, name = "Ball", size = .{32, 32}, frame_x = 1, frame_y = 1, frame_n = 0, origin = .{16, 32}, prop = true, kind = .Ball}];

Tilemap :: struct {
	row :: 50;
	col :: 50;
	depth :: 3;
	tile_size :: 32;
	tiles : []Tile;
	auto_col :: 8;
	auto_row :: 6;
};

tilemap : Tilemap;

save_tilemap :: () {
	print("started saving\n");
	
	count := size_of(Tile) * tilemap.tiles.count;
	data := talloc(count);
	memcpy(data, tilemap.tiles.data, count);
	
	filename := tprint("%/%", data_folder, "map_data");
	
	write_entire_file(filename, data, count);
	
	print("ended saving\n");
}

load_tilemap :: () {
	
	filename := tprint("%/%", data_folder, "map_data");
	
	data := read_entire_file(filename);
	memcpy(tilemap.tiles.data, data.data, data.count);
	free (data);
}

tile_pos : Vector3i;

grid_toggle : bool = true;
active_tool_index := 0;
active_paint_index := 0;
active_entity_index := 0;

SelectionTile :: struct {
	tile : Tile;
	pos : Vector3i;
}

selection_started : bool;
selection_tile_start : Vector3i;
selection_tile_end : Vector3i;
selection_buffer : [..]SelectionTile;
selection_yes : bool;

default_text_color := Vector4.{1, 1, 1, 1};
hot_text_color := Vector4.{1, 0, 0, 1};
active_text_color := Vector4.{0, 1, 0, 1};

tilemap_rect : RectF32;

move_start : Vector3i;
move_end : Vector3i;
moving_started := false;
moving_yes := false;

ed_initialized : bool;

map_editor_window : *Editor_Window;

editor_update :: (delta : float32, events : *os.EventList, sprite_batches : *r.BatchList, ui_batches : *r.BatchList) {
	
	if !ed_initialized {
		ed_initialized = true;
		
		// alloc tilemap memory
		{
			count := tilemap.row * tilemap.col * tilemap.depth;
			
			tilemap.tiles.data = push_array(arena, Tile, xx (count));
			tilemap.tiles.count = count;
		}
		
		map_editor_window = editor_init_window("map editor");
		//editor_set_window_pos(map_editor_window, .{800, 0});
	}
	
	// tilemap camera
	{
		mv : Vector2;
		if(os.event(events, .W, .Pressed))
		{
			cam_wheld = true;
		}
		else if(os.event(events, .W, .Released))
		{
			cam_wheld = false;
		}
		
		if(os.event(events, .A, .Pressed))
		{
			cam_aheld = true;
		}
		else if(os.event(events, .A, .Released))
		{
			cam_aheld = false;
		}
		
		if(os.event(events, .D, .Pressed))
		{
			cam_dheld = true;
		}
		else if(os.event(events, .D, .Released))
		{
			cam_dheld = false;
		}
		
		if(os.event(events, .S, .Pressed))
		{
			cam_sheld = true;
		}
		else if(os.event(events, .S, .Released))
		{
			cam_sheld = false;
		}
		
		if cam_wheld {
			mv.y -= 1;
		}
		
		if cam_aheld {
			mv.x -= 1;
		}
		
		if cam_sheld {
			mv.y += 1;
		}
		
		if cam_dheld {
			mv.x += 1;
		}
		
		map_editor_camera_pos.x += mv.x * delta * 300;
		map_editor_camera_pos.y += mv.y * delta * 300;
	}
	
	set_camera_pos(map_editor_camera_pos);
	
	// draw tilemap
	for z: 0 .. tilemap.depth - 1 {
		for y: 0 .. tilemap.row - 1{
			for x: 0 .. tilemap.col - 1 {
				
				tile := tile_from_index(x, y, z);
				
				if tile.paint_index {
					
					paint := paints[tile.paint_index];
					
					dst : RectF32;
					dst.min.x = xx (x * tilemap.tile_size);
					dst.min.y = xx (y * tilemap.tile_size);
					dst.max.x = dst.min.x + tilemap.tile_size;
					dst.max.y = dst.min.y + tilemap.tile_size;
					
					src : RectF32;
					
					// if its a terrain (auto), the src rect are calculated based on the ruleset, if not, it is based on whats in the paint info
					if paint.auto {
						neighbours := get_neighbours(x, y, z, tile.paint_index);
						bitmask := tile_bitmask(neighbours);
						//print("%\n", bitmask);
						
						uv := uv_from_bitmask(bitmask);
						
						src.min.x = (cast(float32)uv.x / tilemap.auto_col);
						src.max.y = (cast(float32)uv.y / tilemap.auto_row);
						src.max.x = src.min.x + 1. / tilemap.auto_col;
						src.min.y = src.max.y + 1. / tilemap.auto_row;
						
						src.min.y = 1 - src.min.y;
						src.max.y = 1 - src.max.y;
						//print("%\n", src);
						
						tile_rect := r.push_rect2(sprite_batches, dst, r.COLOR_WHITE);
						tile_rect.tex_id = arts[paint.art_id].tex.U64[1];
						tile_rect.src = src;
					}
					else if paint.prop {
						dst : RectF32;
						dst.min.x = xx (x * tilemap.tile_size - paint.origin.x + 16);
						dst.min.y = xx (y * tilemap.tile_size - paint.origin.y + 16);
						dst.max.x = dst.min.x + paint.size.x;
						dst.max.y = dst.min.y + paint.size.y;
						
						tile_rect := r.push_rect2(sprite_batches, dst, r.COLOR_WHITE);
						tile_rect.tex_id = arts[paint.art_id].tex.U64[1];
						
						width := 1. / paint.frame_x;
						
						tile_rect.src = rectF32(paint.frame_n * width, 0, width * (paint.frame_n + 1), 1);
					}
					else {
						src.min.x = (cast(float32) (paint.frame_n % paint.frame_x) / paint.frame_x);
						src.max.y = (cast(float32)((paint.frame_n / paint.frame_x)) / paint.frame_y);
						src.max.x = src.min.x + 1. / paint.frame_x;
						src.min.y = src.max.y + 1. / paint.frame_y;
						
						src.min.y = 1 - src.min.y;
						src.max.y = 1 - src.max.y;
						//print("%\n", src);
						
						tile_rect := r.push_rect2(sprite_batches, dst, r.COLOR_WHITE);
						tile_rect.tex_id = arts[paint.art_id].tex.U64[1];
						tile_rect.src = src;
					}
				}
			}
		}
	}
	
	// draw grid
	if grid_toggle {
		for y: 1 .. tilemap.row - 1 - 1 {
			for x: 1 .. tilemap.col - 1 - 1 {
				tile := tilemap.tiles[y * tilemap.col + x];
				
				dst : RectF32;
				dst.min.x = xx (x * tilemap.tile_size);
				dst.min.y = xx (y * tilemap.tile_size);
				dst.max.x = dst.min.x + tilemap.tile_size;
				dst.max.y = dst.min.y + tilemap.tile_size;
				
				tile_rect := r.push_rect2(sprite_batches, dst, .{});
				tile_rect.border_thickness = 4;
				tile_rect.border_color = r.COLOR_BLACK;
			}
		}
	}
	
	// draw map outline
	{
		tilemap_rect = rectF32(tilemap.tile_size, tilemap.tile_size, (tilemap.col - 1) * tilemap.tile_size, (tilemap.row - 1) * tilemap.tile_size);
		map_outline := r.push_rect2(sprite_batches, tilemap_rect, .{0, 0, 0, 0});
		map_outline.border_color = r.COLOR_ORANGE;
		map_outline.border_thickness = 4;
	}
	
	// TODO(mizu): i don't want events to be shared like this.
	
	if scroll_up {
		tile_pos.z += 1;
	}
	else if scroll_down {
		tile_pos.z -= 1;
	}
	
	tile_pos.z = clamp(tile_pos.z, 0, 2);
	
	// world space coords -> tile pos
	tile_pos.x = xx ((wmpos.x) / tilemap.tile_size);
	tile_pos.y = xx ((wmpos.y) / tilemap.tile_size);
	
	tilemap_in_focus := !any_editor_in_focus() && point_in_rect(wmpos, tilemap_rect);
	
	if tilemap_in_focus {
		
		tool := *tools[active_tool_index];
		
		if tool.kind == .Paint {
			
			// collect input events
			rmbup_event := os.event(events, .RMB, .Released);
			rmbdown_event := os.event(events, .RMB, .Pressed);
			rmb_click : bool;
			
			if rmbdown_event {
				rmb_click = true; 
				rmb_held = true;
			}
			
			if rmbup_event {
				rmb_held = false;
			}
			
			// paint
			if lmb_held {
				tile_from_index(tile_pos).paint_index = xx active_paint_index;
			}
			// erase
			else if rmb_held{
				tile_from_index(tile_pos).paint_index = 0;
			}
		}
		else if tool.kind == .Fill {
			
			// selection started
			if (lmb_held || rmb_held) && !selection_started {
				selection_started = true;
				selection_tile_start = tile_pos;
			}
			
			if selection_started {
				tile_select_range : RectS32;
				
				// tile selection range
				tile_select_range.min.x = min(selection_tile_start.x, selection_tile_end.x);
				tile_select_range.min.y = min(selection_tile_start.y, selection_tile_end.y);
				
				tile_select_range.max.x = max(selection_tile_start.x, selection_tile_end.x);
				tile_select_range.max.y = max(selection_tile_start.y, selection_tile_end.y);
				
				// selection in progress
				if (lmb_held || rmb_held) {
					//print("selectioning ...\n");
					
					selection_tile_end = tile_pos;
					
					// draw selection outline
					dst : RectF32;
					dst.min.x = tile_select_range.min.x * 32.;
					dst.min.y = tile_select_range.min.y * 32.;
					dst.max.x = (tile_select_range.max.x + 1) * 32.;
					dst.max.y = (tile_select_range.max.y + 1) * 32.;
					
					r.push_rect2(sprite_batches, dst, r.COLOR_CYAN);
				}
				// selection ended
				else {
					//print("selection ended\n");
					
					selection_started = false;
					selection_yes = true;
					
					
					for y : tile_select_range.min.y .. tile_select_range.max.y {
						
						for x : tile_select_range.min.x .. tile_select_range.max.x {
							tile_from_index(x, y, tile_pos.z).paint_index = xx active_paint_index;
							
						}
					}
					
					
				}
			}
			
			
		}
		else if tool.kind == .Select {
			
			// selection started
			if lmb_held && !selection_started {
				selection_started = true;
				selection_tile_start = tile_pos;
			}
			
			if selection_started {
				tile_select_range : RectS32;
				
				// tile selection range
				tile_select_range.min.x = min(selection_tile_start.x, selection_tile_end.x);
				tile_select_range.min.y = min(selection_tile_start.y, selection_tile_end.y);
				
				tile_select_range.max.x = max(selection_tile_start.x, selection_tile_end.x);
				tile_select_range.max.y = max(selection_tile_start.y, selection_tile_end.y);
				
				// selection in progress
				if lmb_held {
					//print("selectioning ...\n");
					
					selection_tile_end = tile_pos;
					
					// draw selection outline
					dst : RectF32;
					dst.min.x = tile_select_range.min.x * 32.;
					dst.min.y = tile_select_range.min.y * 32.;
					dst.max.x = (tile_select_range.max.x + 1) * 32.;
					dst.max.y = (tile_select_range.max.y + 1) * 32.;
					
					r.push_rect2(sprite_batches, dst, r.COLOR_CYAN);
				}
				// selection ended
				else {
					//print("selection ended\n");
					selection_started = false;
					selection_yes = true;
					
					// add valid tiles in the selection rect to the selection buffer 
					for y : tile_select_range.min.y .. tile_select_range.max.y {
						for x : tile_select_range.min.x .. tile_select_range.max.x {
							
							tile := tile_from_index(x, y, tile_pos.z);
							
							if tile.paint_index {
								select_tile : SelectionTile;
								select_tile.tile = << tile;
								select_tile.pos = .{x, y, tile_pos.z};
								
								array_add(*selection_buffer, select_tile);
							}
						}
					}
				}
			}
		}
		else if tool.kind == .Move {
			if lmb_down {
				move_start = tile_pos;
				moving_started = true;
			}
			
			if lmb_up {
				move_end = tile_pos;
				moving_yes = true;
				moving_started = false;
			}
			
			if moving_started {
				mv := tile_pos - move_start;
				
				for selection_buffer {
					
					dst := tile_rect_from_index(it.pos + mv);
					r.push_rect2(sprite_batches, dst, r.COLOR_ORANGE);
				}
			}
			
			if moving_yes {
				mv := move_end - move_start;
				
				for *selection_buffer {
					tile1 := tile_from_index(it.pos);
					tile1.paint_index = 0;
					
					tile := tile_from_index(mv + it.pos);
					<< tile = it.tile;
					it.pos = mv + it.pos;
				}
				
				moving_yes = false;
			}
		}
		
		if (tool.kind == .Move) || (tool.kind == .Select) {
			if os.event(events, .RMB, .Pressed) || os.event(events, .LMB, .Pressed) {
				selection_yes = false;
				
				array_reset_keeping_memory(*selection_buffer);
			}
			
			// preview selection
			if selection_yes {
				
				for selection_buffer {
					
					dst := tile_rect_from_index(it.pos);
					r.push_rect2(sprite_batches, dst, .{0, 0, 1, 0.3});
					
				}
				
				// delete selection
				if os.event(events, .DEL, .Pressed) {
					// empty buffer
					for selection_buffer {
						tile := tile_from_index(it.pos);
						tile.paint_index = 0;
					}
					
					array_reset_keeping_memory(*selection_buffer);
					selection_yes = false;
				}
			}
		}
		
		// preview tile pos
		r.push_rect2(sprite_batches, tile_rect_from_index(tile_pos), .{0, 0, 0, 1});
	}
	
	// @panel
	editor_window_begin(ui_batches, map_editor_window);
	
	if !map_editor_window.hide {
		text := tprint("%\nmpos: %\nwmpos:{% %}\ntpos:%", delta, mpos, cast(s32) wmpos.x, cast(s32) wmpos.y, tile_pos);
		ui_label(.{0, 0, 0}, text);
		
		for tools {
			text = tprint("%", it.name);
			
			if(active_tool_index == xx it_index) {
				default_text_color = r.COLOR_ORANGE;
			}
			
			signal := ui_button(.{0, it_index, 1}, text);
			
			default_text_color = r.COLOR_WHITE;
			
			if(signal.active) {
				active_tool_index = xx it_index;
			}
			
			if(active_tool_index == xx Tool_Kind.Paint && (signal.id == .{0, xx Tool_Kind.Paint, 1})) {
				ui_begin_parent();
				for 1 .. paints.count - 1{
					paint := paints[it];
					text = tprint("%", paint.name);
					
					if(active_paint_index == xx it) {
						default_text_color = r.COLOR_ORANGE;
					}
					
					if(ui_button(.{0, it, 2}, text).active) {
						active_paint_index = xx it;
					}
					
					default_text_color = r.COLOR_WHITE;
					
				}
				ui_end_parent();
			}
			
		}
		
		text = tprint("%", selection_buffer.count);
		ui_label(.{0, 0, 3}, text);
		
		text = tprint("% %", move_start, move_end);
		ui_label(.{0, 0, 4}, text);
		
		text = tprint("toggle grid");
		
		grid_toggle = !ui_button(.{0, 0, 5}, text).toggle;
		
		text = tprint("save");
		if ui_button(.{0, 0, 8}, text).active {
			save_tilemap();
		}
		
		text = tprint("load");
		if ui_button(.{0, 0, 9}, text).active {
			load_tilemap();
		}
		
		text = tprint("play");
		
		if ui_button(.{0, 0, 10}, text).toggle {
			world_update(delta, events, sprite_batches, ui_batches);
		}
		
	}
}

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

get_neighbours :: (x : int, y : int, z : int, paint_index : s32) -> TileNeighbours {
	out : TileNeighbours;
	using out;
	
	tile_present :: (x : int, y : int, z : int,  _paint_index : s32) -> bool {
		return tile_from_index(x, y, z).paint_index && (tile_from_index(x, y, z).paint_index == _paint_index);
	}
	
	t  = tile_present(x, y - 1, z, paint_index); 
	tr = tile_present(x + 1, y - 1, z, paint_index); 
	r = tile_present(x + 1, y, z, paint_index); 
	br = tile_present(x + 1, y + 1, z, paint_index); 
	b = tile_present(x, y + 1, z, paint_index); 
	bl = tile_present(x - 1, y + 1, z, paint_index); 
	l = tile_present(x - 1, y, z, paint_index); 
	tl = tile_present(x - 1, y - 1, z, paint_index); 
	
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

tile_from_index :: (x : int, y : int, z : int) -> *Tile {
	return *tilemap.tiles[z * tilemap.row * tilemap.col + y * tilemap.col + x];
}

tile_from_index :: (index : Vector3i) -> *Tile {
	return *tilemap.tiles[index.z * tilemap.row * tilemap.col + index.y * tilemap.col + index.x];
}

tile_rect_from_index :: (pos : Vector3i) -> RectF32 {
	out := rectF32(cast(float32) pos.x * tilemap.tile_size, cast(float32) pos.y * tilemap.tile_size, cast(float32) pos.x * tilemap.tile_size + tilemap.tile_size, cast(float32) pos.y * tilemap.tile_size + tilemap.tile_size);
	
	return out;
}

tile_rect_from_index :: (x : s32, y : s32, z : s32) -> RectF32{
	out := rectF32(cast(float32) x * tilemap.tile_size, cast(float32) y * tilemap.tile_size, cast(float32) x * tilemap.tile_size + tilemap.tile_size, cast(float32) y * tilemap.tile_size + tilemap.tile_size);
	
	return out;
}
