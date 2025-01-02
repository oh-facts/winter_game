ToolKind :: enum {
	Select;
	Paint;
}

Tool :: struct {
	kind : ToolKind;
	name : string;
};

tools : [2]Tool : .[.{kind = .Select, name = "select"}, .{kind = .Paint, name = "paint"}];

Tile :: struct {
	paint_index : s32;
	alpha : bool;
	pos : Vector2;
};

Paint :: struct {
	name : string;
	auto : bool;
	off_grid : bool;
	image_index : s32;
	offset : Vector2i;
	size : Vector2i;
	
	pos : Vector2;
	extent : Vector2;
	ex : Vector2;
};

paints : [5]Paint : .[.{auto = true, image_index = 0, name = "template 1"},
											.{auto = true, image_index = 1, name = "auto grass"},
											.{auto = false, image_index = 3, name = "grass", offset = .{1, 1}, ex = .{128, 240}},
											.{auto = false, image_index = 3, name = "dirt", offset = .{6, 0}, ex = .{128, 240}},
											.{auto = false, image_index = 2, name = "tree", pos = .{11, 143}, extent = .{70, 98}, ex = .{256, 256}, off_grid = true}];

Tilemap :: struct {
	row :: 50;
	col :: 50;
	depth :: 2;
	tile_size :: 32;
	tiles : [col * row * depth]Tile;
	images : [4]r.Handle;
	uv_col :: 8;
	uv_row :: 6;
	props : [10]Tile;
	num_props : s32;
};

tilemap : Tilemap;

mpos : Vector2;
wmpos : Vector2;
lmb_held : bool;
rmb_held : bool;
lctrl_held : bool;
tile_pos : Vector3i;
brush_size : float32 = 1;
grid_toggle : bool = true;
active_paint_index : s32 = 0;
active_tool_index := 0;

selection_counter : float32;
selection_started : bool;
selection_ended : bool;
selection_tile_start : Vector3i;
selection_tile_end : Vector3i;

default_text_color := Vector4.{1, 1, 1, 1};
hot_text_color := Vector4.{1, 0, 0, 1};
active_text_color := Vector4.{0, 1, 0, 1};

editor_rect_max : Vector2;
editor_in_focus : bool;
tilemap_rect : RectF32;

tile_select_range : RectS32;
selection_yes := false;

move_wheld : bool;
move_aheld : bool;
move_sheld : bool;
move_dheld : bool;

editor_update :: (delta : float32, events : *os.EventList, cam_pos : Vector2, cam_size : Vector2, sprite_batches : *r.BatchList, ui_batches : *r.BatchList) {
	
	if !ed_initialized {
		ed_initialized = true;
		ed_arena = arena_init();
	}
	
	lmbdown_event := os.event(events, .LMB, .Pressed);
	lctrlup_event := os.event(events, .LCTRL, .Pressed);
	lctrldown_event := os.event(events, .LCTRL, .Released);
	lmbup_event := os.event(events, .LMB, .Released);
	
	mm_event := os.event(events, .NULL, .MouseMove);
	scroll_event := os.event(events, .NULL, .Scroll);
	
	if os.event(events, .TAB, .Pressed) {
		grid_toggle = !grid_toggle;
	}
	
	lmb_click : bool;
	lmb_down : bool;
	lmb_up : bool;
	
	
	if lmbdown_event {
		lmb_click = true; 
		lmb_held = true;
		lmb_down = true;
	}
	
	if lmbup_event {
		lmb_held = false;
		lmb_up = true;
	}
	
	if lctrlup_event {
		lctrl_held = true;
	}
	
	if lctrldown_event {
		lctrl_held = false;
	}
	
	if mm_event {
		mpos = mm_event.mpos;
	}
	
	if scroll_event {
		
		if scroll_event.wheel > 0 {
			tile_pos.z += 1;
		}
		
		else if scroll_event.wheel < 0 {
			tile_pos.z -= 1;
		}
		tile_pos.z = clamp(tile_pos.z, 0, 1);
	}
	
	wmpos.x = mpos.x + cam_pos.x - cam_size.x / 2.;
	wmpos.y = mpos.y + cam_pos.y - cam_size.y / 2.;
	
	tile_pos.x = xx ((wmpos.x) / tilemap.tile_size);
	tile_pos.y = xx ((wmpos.y) / tilemap.tile_size);
	
	editor_rect : RectF32;
	editor_rect.max = editor_rect_max;
	editor_in_focus = point_in_rect(mpos, editor_rect);
	
	tilemap_in_focus := !editor_in_focus && point_in_rect(wmpos, tilemap_rect);
	
	// draw tile
	if tilemap_in_focus {
		
		tool := *tools[active_tool_index];
		
		if tool.kind == .Paint {
			
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
			
			if !paints[active_paint_index].off_grid {
				if lmb_held {
					tile_from_index(tile_pos).alpha = true;
					tile_from_index(tile_pos).paint_index = active_paint_index;
				}
				else if rmb_held{
					tile_from_index(tile_pos).alpha = false;
				}
				
			}
			else {
				if lmb_click {
					tilemap.props[tilemap.num_props].paint_index = active_paint_index;
					tilemap.props[tilemap.num_props].pos = wmpos;
					tilemap.num_props += 1;
				}
			}
		}
		else if tool.kind == .Select {
			
			if lmb_held && !selection_started {
				selection_counter += delta;
			}
			
			if selection_counter > 0.05 {
				selection_started = true;
				selection_counter = 0.;
				//print("selection started\n");
				selection_tile_start = tile_pos;
			}
			
			if !lmb_held && selection_started {
				selection_ended = true;
			}
			
			if selection_started {
				if !selection_ended {
					//print("selectioning ...\n");
					
					selection_tile_end = tile_pos;
					
					// tile range
					tile_select_range.min.x = min(selection_tile_start.x, selection_tile_end.x);
					tile_select_range.min.y = min(selection_tile_start.y, selection_tile_end.y);
					
					tile_select_range.max.x = max(selection_tile_start.x, selection_tile_end.x);
					tile_select_range.max.y = max(selection_tile_start.y, selection_tile_end.y);
					
					{
						//print("start\n");
						for y : tile_select_range.min.y .. tile_select_range.max.y {
							for x : tile_select_range.min.x .. tile_select_range.max.x {
								//print("% %\n", x, y);
							}
						}
						//print("end\n");
					}
					
					// draw selection outline
					{
						dst : RectF32;
						dst.min.x = tile_select_range.min.x * 32.;
						dst.min.y = tile_select_range.min.y * 32.;
						dst.max.x = (tile_select_range.max.x + 1) * 32.;
						dst.max.y = (tile_select_range.max.y + 1) * 32.;
						
						r.push_rect2(sprite_batches, dst, r.COLOR_CYAN);
					}
					
				}
				else {
					//print("selection ended\n");
					selection_started = false;
					selection_ended = false;
					selection_counter = 0;
					selection_yes = true;
				}
			}
		}
	}
	
	for z: 0 .. tilemap.depth - 1 {
		for y: 0 .. tilemap.row - 1{
			for x: 0 .. tilemap.col - 1 {
				
				tile := tile_from_index(x, y, z);
				
				if tile.alpha {
					
					paint := paints[tile.paint_index];
					
					if paint.auto {
						
						dst : RectF32;
						dst.min.x = xx (x * tilemap.tile_size);
						dst.min.y = xx (y * tilemap.tile_size);
						dst.max.x = dst.min.x + tilemap.tile_size;
						dst.max.y = dst.min.y + tilemap.tile_size;
						
						neighbours := get_neighbours(tilemap, x, y, z, tile.paint_index);
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
						tile_rect.tex_id = tilemap.images[paint.image_index].U64[1];
						tile_rect.src = src;
					}
					else {
						dst : RectF32;
						dst.min.x = xx (x * tilemap.tile_size);
						dst.min.y = xx (y * tilemap.tile_size);
						dst.max.x = dst.min.x + tilemap.tile_size;
						dst.max.y = dst.min.y + tilemap.tile_size;
						
						src : RectF32;
						src.min.x = (cast(float32)paint.offset.x / 8.);
						src.max.y = (cast(float32)paint.offset.y / 15.);
						src.max.x = src.min.x + 1. / 8.;
						src.min.y = src.max.y + 1. / 15.;
						
						src.min.y = 1 - src.min.y;
						src.max.y = 1 - src.max.y;
						
						tile_rect := r.push_rect2(sprite_batches, dst, r.COLOR_WHITE);
						tile_rect.tex_id = tilemap.images[paint.image_index].U64[1];
						tile_rect.src = src;
					}
					//print("%\n", bitmask);
				}
			}
		}
	}
	
	// grid outline
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
	
	// draw props
	for tilemap.props {
		paint := paints[it.paint_index];
		dst : RectF32;
		dst.min.x = xx (it.pos.x);
		dst.min.y = xx (it.pos.y);
		dst.max.x = dst.min.x + paint.extent.x * 2;
		dst.max.y = dst.min.y + paint.extent.y * 2;
		
		src : RectF32;
		src.min.x = paint.pos.x / paint.ex.x;
		src.max.y = paint.pos.y / paint.ex.y;
		src.max.x = src.min.x + paint.extent.x / paint.ex.x;
		src.min.y = src.max.y + paint.extent.y / paint.ex.y;
		
		src.min.y = 1 - src.min.y;
		src.max.y = 1 - src.max.y;
		
		tile_rect := r.push_rect2(sprite_batches, dst, r.COLOR_WHITE);
		tile_rect.tex_id = tilemap.images[paint.image_index].U64[1];
		tile_rect.src = src;
	}
	
	// map outline
	tilemap_rect = rectF32(tilemap.tile_size, tilemap.tile_size, (tilemap.col - 1) * tilemap.tile_size, (tilemap.row - 1) * tilemap.tile_size);
	map_outline := r.push_rect2(sprite_batches, tilemap_rect, .{0, 0, 0, 0});
	map_outline.border_color = r.COLOR_ORANGE;
	map_outline.border_thickness = 4;
	
	// preview draw tile
	
	if tilemap_in_focus{
		paint := paints[active_paint_index];
		
		if paint.auto {
			r.push_rect2(sprite_batches, tile_rect_from_index(tile_pos), .{0, 0, 0, 1});
		}
		else if paint.off_grid {
			dst : RectF32;
			dst.min.x = xx (wmpos.x);
			dst.min.y = xx (wmpos.y);
			dst.max.x = dst.min.x + paint.extent.x * 2;
			dst.max.y = dst.min.y + paint.extent.y * 2;
			
			src : RectF32;
			src.min.x = paint.pos.x / paint.ex.x;
			src.max.y = paint.pos.y / paint.ex.y;
			src.max.x = src.min.x + paint.extent.x / paint.ex.x;
			src.min.y = src.max.y + paint.extent.y / paint.ex.y;
			
			src.min.y = 1 - src.min.y;
			src.max.y = 1 - src.max.y;
			
			tile_rect := r.push_rect2(sprite_batches, dst, r.COLOR_WHITE);
			tile_rect.tex_id = tilemap.images[paint.image_index].U64[1];
			tile_rect.src = src;
			
		}
	}
	
	// preview selection
	if selection_yes {
		for y : tile_select_range.min.y .. tile_select_range.max.y {
			for x : tile_select_range.min.x .. tile_select_range.max.x {
				
				tile := tile_from_index(x, y, 0);
				
				if tile.alpha {
					dst : RectF32;
					dst.min.x = xx (x * tilemap.tile_size);
					dst.min.y = xx (y * tilemap.tile_size);
					dst.max.x = dst.min.x + tilemap.tile_size;
					dst.max.y = dst.min.y + tilemap.tile_size;
					
					r.push_rect2(sprite_batches, dst, .{0, 0, 1, 0.3});
				}
			}
		}
		
		// delete selection
		if os.event(events, .DEL, .Pressed) {
			for y : tile_select_range.min.y .. tile_select_range.max.y {
				for x : tile_select_range.min.x .. tile_select_range.max.x {
					
					tile := tile_from_index(x, y, 0);
					tile.alpha = false;
				}
			}
			selection_yes = false;
		}
		
		// move selection
		move_wheld : bool;
		move_aheld : bool;
		move_sheld : bool;
		move_dheld : bool;
		
		if(os.event(events, .W, .Pressed))
		{
			move_wheld = true;
		}
		else if(os.event(events, .W, .Released))
		{
			move_wheld = false;
		}
		
		if(os.event(events, .A, .Pressed))
		{
			move_aheld = true;
		}
		else if(os.event(events, .A, .Released))
		{
			move_aheld = false;
		}
		
		if(os.event(events, .D, .Pressed))
		{
			move_dheld = true;
		}
		else if(os.event(events, .D, .Released))
		{
			move_dheld = false;
		}
		
		if(os.event(events, .S, .Pressed))
		{
			move_sheld = true;
		}
		else if(os.event(events, .S, .Released))
		{
			move_sheld = false;
		}
		
		mv : Vector2i;
		
		if move_wheld {
			mv.y -= 1;
		}
		
		if move_aheld {
			mv.x -= 1;
		}
		
		if move_sheld {
			mv.y += 1;
		}
		
		if move_dheld {
			mv.x += 1;
		}
		
		//selection_yes = false;
		if mv.x != 0 || mv.y != 0 {
			
			if mv.x > 0 || mv.y > 0 {
				for #v2 < y : tile_select_range.min.y + mv.y .. tile_select_range.max.y + mv.y {
					for #v2 < x : tile_select_range.min.x + mv.x.. tile_select_range.max.x + mv.x {
						
						tile1 := tile_from_index(x - mv.x, y - mv.y, 0);
						tile2 := tile_from_index(x, y, 0);
						
						<< tile2 = << tile1;
						<< tile1 = .{};
					}
				}
			}
			else if mv.x < 0 || mv.y < 0 {
				for y : tile_select_range.min.y + mv.y .. tile_select_range.max.y + mv.y {
					for x : tile_select_range.min.x + mv.x.. tile_select_range.max.x + mv.x {
						
						tile1 := tile_from_index(x - mv.x, y - mv.y, 0);
						tile2 := tile_from_index(x, y, 0);
						
						<< tile2 = << tile1;
						<< tile1 = .{};
					}
				}
			}
			
			tile_select_range.min.x += mv.x;
			tile_select_range.min.y += mv.y;
			tile_select_range.max.x += mv.x;
			tile_select_range.max.y += mv.y;
		}
		
		if os.event(events, .RMB, .Pressed) {
			selection_yes = false;
		}
		
	}
	
	// @editor
	r.push_rect2(ui_batches, editor_rect, .{0, 0, 0, 0.9});
	
	text := tprint("%\nmpos: %\nwmpos:{% %}\ntpos:%", delta, mpos, cast(s32) wmpos.x, cast(s32) wmpos.y, tile_pos);
	
	ui_begin(ui_batches, lmb_down, lmb_up);
	ui_label(.{0, 0, 0}, text);
	
	for tools {
		text = tprint("%", it.name);
		
		if(active_tool_index == xx it_index) {
			default_text_color = r.COLOR_ORANGE;
		}
		
		signal := ui_label(.{0, it_index, 1}, text);
		
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
				
				if(ui_label(.{0, it_index, 2}, text).active) {
					active_paint_index = xx it_index;
				}
				
				default_text_color = r.COLOR_WHITE;
				
			}
			ui_end_parent();
		}
		
	}
	
	text = tprint("%", tile_select_range);
	ui_label(.{0, 0, 3}, text);
	
	
}

point_in_rect :: (point : Vector2, rect : RectF32) -> bool{
	out : bool;
	
	if (point.x > rect.min.x) && (point.y > rect.min.y) && (point.x < rect.max.x) && (point.y < rect.max.y) {
		out = true;
	}
	
	return out;
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

get_neighbours :: (map : Tilemap, x : int, y : int, z : int, paint_index : s32) -> TileNeighbours {
	out : TileNeighbours;
	using out;
	
	tile_present :: (map : Tilemap, x : int, y : int, z : int,  _paint_index : s32) -> bool {
		return tile_from_index(x, y, z).alpha && (tile_from_index(x, y, z).paint_index == _paint_index);
	}
	
	t  = tile_present(map, x, y - 1, z, paint_index); 
	tr = tile_present(map, x + 1, y - 1, z, paint_index); 
	r = tile_present(map, x + 1, y, z, paint_index); 
	br = tile_present(map, x + 1, y + 1, z, paint_index); 
	b = tile_present(map, x, y + 1, z, paint_index); 
	bl = tile_present(map, x - 1, y + 1, z, paint_index); 
	l = tile_present(map, x - 1, y, z, paint_index); 
	tl = tile_present(map, x - 1, y - 1, z, paint_index); 
	
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

UI_ID :: struct {
	owner : int;
	index : int;
	item: int;
};

operator == :: (a : UI_ID, b : UI_ID) -> bool{
	out : bool;
	if (a.owner == b.owner) && (a.index == b.index) && (a.item == b.item){
		out = true;
	}
	return out;
}

UI_Var :: struct {
	hash_next : *UI_Var;
	id : UI_ID;
	toggle : bool;
}

UI_Var_Slot :: struct {
	first : *UI_Var;
	last: *UI_Var;
};

UI_Var_Cache :: struct {
	num_slots :: 100;
	slots : [num_slots]UI_Var_Slot;
};

push_ui_var :: () -> *UI_Var {
	out := push_struct(ed_arena, UI_Var);
	return out;
}

ed_arena : *Arena;
ed_initialized : bool;

// TODO(mizu): better hash func
ui_lookup_var :: (id : UI_ID) -> * UI_Var{
	index := ((id.owner << 1) + (id.index << 1) + (id.item << 1)) % ui_cxt.cache.num_slots;
	
	slot := *ui_cxt.cache.slots[index];
	out := slot.first;
	
	if out {
		while true {
			if out.id == id {
				break;
			}
			
			out = out.hash_next;
			if !out break;
		}
	}
	
	// allocate 
	if !out {
		out = push_ui_var();
		
		if slot.last {
			slot.last.hash_next = out;
			slot.last = out;
		}
		else {
			slot.first = out;
			slot.last = out;
		}
		
	}
	
	out.id = id;
	
	return out;
}

Signal :: struct {
	hot : bool;
	active : bool;
	id : UI_ID;
	toggle : bool;
};

ui_cxt : struct {
	hot : UI_ID = .{-1, -1, -1};
	active : UI_ID = .{-1, -1, -1};
	text_pos : Vector2;
	ext : RectF32;
	batches : *r.BatchList;
	mouse_up : bool;
	mouse_down : bool;
	arena : *Arena;
	x_layout :: 10;
	cache : UI_Var_Cache;
};

ui_begin :: (batches : *r.BatchList, mouse_down : bool, mouse_up : bool) {
	ui_cxt.text_pos = .{};
	ui_cxt.ext = .{};
	ui_cxt.batches = batches;
	ui_cxt.mouse_down = mouse_down;
	ui_cxt.mouse_up = mouse_up;
	ui_cxt.hot = .{-1, -1, -1};
	editor_rect_max = .{};
	default_text_color = Vector4.{1, 1, 1, 1};
}

ui_begin_parent :: () {
	ui_cxt.text_pos.x += ui_cxt.x_layout;
}

ui_end_parent :: () {
	ui_cxt.text_pos.x -= ui_cxt.x_layout;
}

ui_label :: (id : UI_ID, text : string, text_size := 0.4) -> Signal {
	out : Signal;
	out.id = id;
	text_color := default_text_color;
	
	ui_cxt.ext = r.get_text_rect(font, text, ui_cxt.text_pos, text_size);
	
	var := ui_lookup_var(id);
	out.toggle = var.toggle;
	inside := point_in_rect(mpos, ui_cxt.ext);
	
	if inside {
		ui_cxt.hot = id;
		out.hot = true;
	}
	
	if id == ui_cxt.active {
		text_color = active_text_color;
		if ui_cxt.mouse_up {
			if id == ui_cxt.hot {
				out.active = true;
				var.toggle = !var.toggle;
			}
			ui_cxt.active = .{-1, -1, -1};
		}
	}
	else if id == ui_cxt.hot {
		if ui_cxt.mouse_down {
			ui_cxt.active = id;
		}
		
		if ui_cxt.active == .{-1, -1, -1} {
			text_color = hot_text_color;
		}
	}
	
	if ui_cxt.ext.max.x > editor_rect_max.x {
		editor_rect_max.x = ui_cxt.ext.max.x;
	}
	
	if ui_cxt.ext.max.y > editor_rect_max.y {
		editor_rect_max.y = ui_cxt.ext.max.y;
	}
	
	r.push_text(ui_cxt.batches, font, text, ui_cxt.text_pos, text_size, text_color);
	
	ui_cxt.text_pos.y = ui_cxt.ext.max.y;
	
	return out;
}

tile_rect_from_index :: (pos : Vector3i) -> RectF32{
	out := rectF32(cast(float32) pos.x * tilemap.tile_size, cast(float32) pos.y * tilemap.tile_size, cast(float32) pos.x * tilemap.tile_size + tilemap.tile_size, cast(float32) pos.y * tilemap.tile_size + tilemap.tile_size);
	
	return out;
}