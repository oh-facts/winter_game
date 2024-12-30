mpos : Vector2;
wmpos : Vector2;
lmb_held : bool;
rmb_held : bool;
lctrl_held : bool;
tile_pos : Vector2i;
brush_size : float32 = 1;
grid_toggle : bool = true;
active_image_index : s32 = 0;
default_text_color :: Vector4.{1, 1, 1, 1};
hover_text_color :: Vector4.{1, 0, 0, 1};
current_text_color : Vector4;
editor_rect_max : Vector2;
editor_in_focus : bool;
tilemap_rect : RectF32;
hot_id : s32;

editor_update :: (delta : float32, events : *os.EventList, cam_pos : Vector2, cam_size : Vector2, sprite_batches : *r.BatchList, ui_batches : *r.BatchList) {
	lmbdown_event := os.event(events, .LMB, .Pressed);
	rmbdown_event := os.event(events, .RMB, .Pressed);
	lctrlup_event := os.event(events, .LCTRL, .Pressed);
	
	lmbup_event := os.event(events, .LMB, .Released);
	rmbup_event := os.event(events, .RMB, .Released);
	lctrldown_event := os.event(events, .LCTRL, .Released);
	
	mm_event := os.event(events, .NULL, .MouseMove);
	
	if os.event(events, .TAB, .Pressed) {
		grid_toggle = !grid_toggle;
	}
	
	lmb_click : bool;
	rmb_click : bool;
	
	if lmbdown_event {
		lmb_click = true; 
		lmb_held = true;
	}
	
	if lmbup_event {
		lmb_held = false;
	}
	
	if lctrlup_event {
		lctrl_held = true;
	}
	
	if rmbdown_event {
		rmb_click = true; 
		rmb_held = true;
	}
	
	if rmbup_event {
		rmb_held = false;
	}
	
	if lctrldown_event {
		lctrl_held = false;
	}
	
	if mm_event {
		mpos = mm_event.mpos;
	}
	
	wmpos.x = mpos.x + cam_pos.x - cam_size.x / 2.;
	wmpos.y = mpos.y + cam_pos.y - cam_size.y / 2.;
	
	tile_pos.x = xx ((wmpos.x) / 32);
	tile_pos.y = xx ((wmpos.y) / 32);
	
	editor_rect : RectF32;
	editor_rect.max = editor_rect_max;
	editor_in_focus = point_in_rect(mpos, editor_rect);
	
	tilemap_in_focus := !editor_in_focus && point_in_rect(wmpos, tilemap_rect);
	
	// draw tile
	if lmb_held && tilemap_in_focus{
		tilemap.tiles[tile_pos.x * tilemap.col + tile_pos.y].alpha = true;
		tilemap.tiles[tile_pos.x * tilemap.col + tile_pos.y].image_index = active_image_index;
	}
	else if rmb_held && tilemap_in_focus {
		tilemap.tiles[tile_pos.x * tilemap.col + tile_pos.y].alpha = false;
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
				
				get_neighbours :: (map : Tilemap, index : Vector2i, image_index : s32) -> TileNeighbours {
					out : TileNeighbours;
					using out;
					
					tile_present :: (map : Tilemap, _index : Vector2i, _image_index : s32) -> bool {
						return map.tiles[_index.x * map.col + _index.y].alpha && (map.tiles[_index.x * map.col + _index.y].image_index == _image_index);
					}
					
					t  = tile_present(map, .{index.x, index.y - 1}, image_index); 
					tr = tile_present(map, .{index.x + 1, index.y - 1}, image_index); 
					r = tile_present(map, .{index.x + 1, index.y}, image_index); 
					br = tile_present(map, .{index.x + 1, index.y + 1}, image_index); 
					b = tile_present(map, .{index.x, index.y + 1}, image_index); 
					bl = tile_present(map, .{index.x - 1, index.y + 1}, image_index); 
					l = tile_present(map, .{index.x - 1, index.y}, image_index); 
					tl = tile_present(map, .{index.x - 1, index.y - 1}, image_index); 
					
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
				
				index : Vector2i= .{xx x, xx y};
				
				neighbours := get_neighbours(tilemap, index, tile.image_index);
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
				
				tile_rect := r.push_rect2(sprite_batches, dst, r.COLOR_WHITE);
				tile_rect.tex_id = tilemap.images[tile.image_index].U64[1];
				tile_rect.src = src;
				
				//print("%\n", bitmask);
			}
		}
	}
	
	// grid outline
	if grid_toggle {
		for y: 1 .. tilemap.row - 1 - 1 {
			for x: 1 .. tilemap.col - 1 - 1 {
				tile := tilemap.tiles[x * tilemap.col + y];
				
				dst : RectF32;
				dst.min.x = xx (x * 32);
				dst.min.y = xx (y * 32);
				dst.max.x = dst.min.x + 32;
				dst.max.y = dst.min.y + 32;
				
				tile_rect := r.push_rect2(sprite_batches, dst, .{});
				tile_rect.border_thickness = 4;
				tile_rect.border_color = r.COLOR_BLACK;
			}
		}
	}
	
	// map outline
	tilemap_rect = rectF32(32, 32, (tilemap.col - 1)* 32, (tilemap.row - 1) * 32);
	map_outline := r.push_rect2(sprite_batches, tilemap_rect, .{0, 0, 0, 0});
	map_outline.border_color = r.COLOR_ORANGE;
	map_outline.border_thickness = 4;
	
	// preview draw tile
	
	if tilemap_in_focus{
		r.push_rect2(sprite_batches, rectF32(tile_pos.x * 32., tile_pos.y * 32., tile_pos.x * 32. + 32., tile_pos.y * 32. + 32.), .{0, 0, 0, 1});
	}
	
	// @debug text
	r.push_rect2(ui_batches, editor_rect, .{0, 0, 0, 0.9});
	
	text := tprint("%\nmpos: %\nwmpos:{% %}\ntpos:%", delta, mpos, cast(s32) wmpos.x, cast(s32) wmpos.y, tile_pos);
	
	text_pos : Vector2 = .{0, 0};
	text_size := 0.4;
	
	ext := r.get_text_rect(font, text, text_pos, text_size);
	if ext.max.x > editor_rect_max.x {
		editor_rect_max.x = ext.max.x;
	}
	
	if ext.max.y > editor_rect_max.y {
		editor_rect_max.y = ext.max.y;
	}
	
	r.push_text(ui_batches, font, text, text_pos, text_size, r.COLOR_ORANGE);
	
	text_pos.y += ext.max.y - ext.min.y;
	
	// active paint
	for 0 .. TileKind.COUNT - 1 {
		text = tprint("%", tile_kind_names[it]);
		ext = r.get_text_rect(font, text, text_pos, text_size);
		if ext.max.x > editor_rect_max.x {
			editor_rect_max.x = ext.max.x;
		}
		
		if ext.max.y > editor_rect_max.y {
			editor_rect_max.y = ext.max.y;
		}
		
		hovering := point_in_rect(mpos, ext);
		
		if hovering {
			current_text_color = hover_text_color;
			
			if lmb_held {
				active_image_index = xx it;
			}
			
		}
		else {
			current_text_color = default_text_color;
		}
		
		r.push_text(ui_batches, font, text, text_pos, text_size, current_text_color);
		text_pos.y += ext.max.y - ext.min.y;
	}
}

point_in_rect :: (point : Vector2, rect : RectF32) -> bool{
	out : bool;
	
	if (point.x > rect.min.x) && (point.y > rect.min.y) && (point.x < rect.max.x) && (point.y < rect.max.y) {
		out = true;
	}
	
	return out;
}
