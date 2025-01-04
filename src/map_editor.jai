ToolKind :: enum {
	Select;
	Paint;
	Move;
}

Tool :: struct {
	kind : ToolKind;
	name : string;
};

tools : [3]Tool : .[.{kind = .Select, name = "select"},
										.{kind = .Paint, name = "paint"},
										.{kind = .Move, name = "move"}];

Tile :: struct {
	paint_index : s32;
	alpha : bool;
};

Paint :: struct {
	name : string;
	auto : bool;
	art_id : ArtId;
	offset : Vector2i;
};

paints : [4]Paint : .[.{auto = true, art_id = .TerrainTemplate, name = "template 1"},
											.{auto = true, art_id = .TerrainGrass, name = "auto grass"},
											.{auto = false, art_id = .TilesForest, name = "grass", offset = .{1, 1}},
											.{auto = false, art_id = .TilesForest, name = "dirt", offset = .{6, 0}}];

Tilemap :: struct {
	row :: 50;
	col :: 50;
	depth :: 2;
	tile_size :: 32;
	tiles : []Tile;
	uv_col :: 8;
	uv_row :: 6;
};

tilemap : Tilemap;

save_tilemap :: () {
	print("started saving\n");
	
	count := size_of(Tile) * tilemap.tiles.count;
	data := talloc(count);
	memcpy(data, tilemap.tiles.data, count);
	write_entire_file("map_data", data, count);
	
	print("ended saving\n");
}

load_tilemap :: () {
	data := read_entire_file("map_data");
	memcpy(tilemap.tiles.data, data.data, data.count);
	free (data);
}

wmpos : Vector2;
tile_pos : Vector3i;

grid_toggle : bool = true;
active_paint_index := 0;
active_tool_index := 0;

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

ed_arena : *Arena;
ed_initialized : bool;

map_editor_window : *Editor_Window;

editor_update :: (delta : float32, events : *os.EventList, cam_pos : Vector2, cam_size : Vector2, sprite_batches : *r.BatchList, ui_batches : *r.BatchList) {
	
	if !ed_initialized {
		ed_initialized = true;
		ed_arena = arena_init();
		
		// alloc tilemap memory
		{
			count := tilemap.row * tilemap.col * tilemap.depth;
			
			tilemap.tiles.data = push_array(ed_arena, Tile, xx (count));
			tilemap.tiles.count = count;
		}
		
		map_editor_window = editor_init_window("map editor");
		editor_set_window_pos(map_editor_window, .{800, 0});
	}
	
	// draw tilemap
	for z: 0 .. tilemap.depth - 1 {
		for y: 0 .. tilemap.row - 1{
			for x: 0 .. tilemap.col - 1 {
				
				tile := tile_from_index(x, y, z);
				
				if tile.alpha {
					
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
						
						src.min.x = (cast(float32)uv.x / tilemap.uv_col);
						src.max.y = (cast(float32)uv.y / tilemap.uv_row);
						src.max.x = src.min.x + 1. / tilemap.uv_col;
						src.min.y = src.max.y + 1. / tilemap.uv_row;
					}
					else {
						src.min.x = (cast(float32)paint.offset.x / 8.);
						src.max.y = (cast(float32)paint.offset.y / 15.);
						src.max.x = src.min.x + 1. / 8.;
						src.min.y = src.max.y + 1. / 15.;
					}
					
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
	if os.event(events, .TAB, .Pressed) {
		grid_toggle = !grid_toggle;
	}
	
	
	if scroll_up {
		tile_pos.z += 1;
	}
	else if scroll_down {
		tile_pos.z -= 1;
	}
	
	tile_pos.z = clamp(tile_pos.z, 0, 1);
	
	// mouse coords -> world space coords
	wmpos.x = mpos.x + cam_pos.x - cam_size.x / 2.;
	wmpos.y = mpos.y + cam_pos.y - cam_size.y / 2.;
	
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
				tile_from_index(tile_pos).alpha = true;
				tile_from_index(tile_pos).paint_index = xx active_paint_index;
			}
			// erase
			else if rmb_held{
				tile_from_index(tile_pos).alpha = false;
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
							
							if tile.alpha {
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
					tile1.alpha = false;
					
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
						tile.alpha = false;
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
			
			if(active_tool_index == xx ToolKind.Paint && (signal.id == .{0, xx ToolKind.Paint, 1})) {
				ui_begin_parent();
				for paints {
					text = tprint("%", it.name);
					
					if(active_paint_index == xx it_index) {
						default_text_color = r.COLOR_ORANGE;
					}
					
					if(ui_button(.{0, it_index, 2}, text).active) {
						active_paint_index = xx it_index;
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
		
		text = tprint("save");
		if ui_button(.{0, 0, 5}, text).active {
			save_tilemap();
		}
		
		text = tprint("load");
		if ui_button(.{0, 0, 6}, text).active {
			load_tilemap();
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
		return tile_from_index(x, y, z).alpha && (tile_from_index(x, y, z).paint_index == _paint_index);
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
