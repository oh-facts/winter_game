Tile_Kind :: enum {
	Grass;
	Dirt;
	Player;
	Tree;
	Ball;
	Siren;
}

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
	
	// used for identification
	key : int;
};

paints : [9]Paint : .[.{empty = true},
											.{auto = true, art_id = .TerrainTemplate, name = "template 1"},
											.{auto = true, art_id = .TerrainGrass, name = "auto grass", kind = .Grass},
											.{auto = false, art_id = .TilesForest, name = "grass", src = .{.{0, 0},.{1, 1}}, frame_x = 8, frame_y = 15, frame_n = 9, kind = .Grass},
											.{auto = false, art_id = .TilesForest, name = "dirt", src = .{.{0, 0},.{1, 1}}, frame_x = 8, frame_y = 15, frame_n = 6, kind = .Dirt},
											.{auto = false, art_id = .Impolo, name = "player", kind = .Player, size = .{64, 64}, origin = .{32, 64}, src = .{.{0, 0}, .{1, 1}}, frame_x = 8, frame_y = 1, prop = true, kind = .Player},
											.{auto = false, art_id = .Tree, name = "tree", kind = .Tree, size = .{512, 512}, src = .{.{0, 0}, .{1, 1}}, frame_x = 3, frame_y = 1, frame_n = 0, origin = .{256, 380}, prop = true},
											.{art_id = .Ball, name = "Ball", size = .{32, 32}, frame_x = 1, frame_y = 1, frame_n = 0, origin = .{16, 32}, prop = true, kind = .Ball},
											.{art_id = .Siren, name = "Siren", size = .{256, 256}, frame_x = 1, frame_y = 1, frame_n = 0, origin = .{128, 240}, prop = true, kind = .Siren}];

Tilemap :: struct {
	row :: 32;
	col :: 60;
	depth :: 3;
	tile_size :: 32;
	tiles : [row * col * depth]Tile;
	size :: row * col * depth * size_of(Tile);
	auto_col :: 8;
	auto_row :: 6;
	rect : RectF32 : .{.{tile_size, tile_size}, .{(col - 1) * tile_size, (row - 1) * tile_size}};
	next : *Tilemap;
	index : Vector2i;
};

Tilemap_Slot :: struct {
	first : *Tilemap;
	last : *Tilemap;
}

Tileworld :: struct {
	slots : []Tilemap_Slot;
	
	// useful for serializing or for batch operations ??
	tm_arena : *Arena;
	tm_base : *Tilemap;
	tm_count : int;
}

init_tileworld :: () -> Tileworld {
	out : Tileworld;
	count :: 1024;
	
	out.slots.data = push_array(arena, Tilemap, xx (count));
	out.slots.count = count;
	out.tm_arena = arena_init();
	out.tm_base = push_struct(out.tm_arena, void);
	return out;
}

tilemap_from_key :: (world : *Tileworld, key : Vector2i) -> *Tilemap {
	out : *Tilemap;
	
	hash : u64 = 5381;
	hash = ((hash << 5) + hash) + xx key.x;
	hash = ((hash << 5) + hash) + xx key.y;
	
	index := xx hash % world.slots.count;
	slot := world.slots.data + index;
	
	cur := slot.first;
	
	while  cur {
		if cur.index == key {
			out = cur;
			break;
		}
		cur = cur.next;
	}
	
	if !out {
		out = push_struct(world.tm_arena, Tilemap);
		out.index = key;
		
		if slot.last {
			slot.last.next = out;
			slot.last = out;
		} else {
			slot.last = out;
			slot.first = out;
		}
		
		world.tm_count += 1;
	}
	
	return out;
}

save_tileworld :: (tw : Tileworld) {
	print("started saving\n");
	
	{
		filename := tprint("%/%", data_folder, "map_data");
		
		write_entire_file(filename, tw.tm_base, size_of(Tilemap) * tw.tm_count);
	}
	{
		filename := tprint("%/%", data_folder, "map_meta_data");
		
		count := tw.tm_count;
		write_entire_file(filename, *count, size_of(int));
	}
	print("ended saving\n");
}

load_tileworld :: (tw : *Tileworld) {
	loaded := 0;
	{
		filename := tprint("%/%", data_folder, "map_meta_data");
		data : *int = xx read_entire_file(filename).data;
		
		if data {
			loaded = << data;
			
			free (data);
		}
	}
	{
		filename := tprint("%/%", data_folder, "map_data");
		
		data :*Tilemap= xx read_entire_file(filename).data;
		
		if data {
			for 0 .. loaded - 1{
				tm := tilemap_from_key(tw, data[it].index);
				memcpy(tm.tiles.data, data[it].tiles.data, Tilemap.size);
			}
			
			free (data);
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

get_neighbours :: (tm : Tilemap, x : int, y : int, z : int, paint_index : s32) -> TileNeighbours {
	out : TileNeighbours;
	using out;
	
	tile_present :: (tm : Tilemap, x : int, y : int, z : int,  _paint_index : s32) -> bool {
		return xx tile_from_index(tm, x, y, z).paint_index;
	}
	
	t  = tile_present(tm, x, y - 1, z, paint_index); 
	tr = tile_present(tm, x + 1, y - 1, z, paint_index); 
	r = tile_present(tm, x + 1, y, z, paint_index); 
	br = tile_present(tm, x + 1, y + 1, z, paint_index); 
	b = tile_present(tm, x, y + 1, z, paint_index); 
	bl = tile_present(tm, x - 1, y + 1, z, paint_index); 
	l = tile_present(tm, x - 1, y, z, paint_index); 
	tl = tile_present(tm, x - 1, y - 1, z, paint_index); 
	
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

tile_from_index :: (tm : Tilemap, x : int, y : int, z : int) -> *Tile {
	return *tm.tiles[z * tm.row * tm.col + y * tm.col + x];
}

tile_from_index :: (tm : Tilemap, index : Vector3i) -> *Tile {
	return *tm.tiles[index.z * tm.row * tm.col + index.y * tm.col + index.x];
}

tile_rect_from_index :: (tm : Tilemap, pos : Vector3i) -> RectF32 {
	out := rectF32(cast(float32) pos.x * tm.tile_size, cast(float32) pos.y * tm.tile_size, cast(float32) pos.x * tm.tile_size + tm.tile_size, cast(float32) pos.y * tm.tile_size + tm.tile_size);
	
	return out;
}

tile_rect_from_index :: (tm : Tilemap, x : s32, y : s32, z : s32) -> RectF32{
	out := rectF32(cast(float32) x * tm.tile_size, cast(float32) y * tm.tile_size, cast(float32) x * tm.tile_size + tm.tile_size, cast(float32) y * tm.tile_size + tm.tile_size);
	
	return out;
}

draw_tilemap :: (tm : Tilemap, sprite_batches : *r.BatchList) {
	// draw tilemap
	for z: 0 .. tm.depth - 2 {
		for y: 0 .. tm.row - 1 {
			for x: 0 .. tm.col - 1 {
				
				tile := tile_from_index(tm, x, y, z);
				
				if tile.paint_index {
					
					paint := paints[tile.paint_index];
					
					dst : RectF32;
					dst.min.x = xx ((x + tm.index.x * tm.col) * tm.tile_size);
					dst.min.y = xx ((y + tm.index.y * tm.row) * tm.tile_size);
					dst.max.x = dst.min.x + tm.tile_size + 1;
					dst.max.y = dst.min.y + tm.tile_size + 1;
					
					src : RectF32;
					
					// if its a terrain (auto), the src rect are calculated based on the ruleset, if not, it is based on whats in the paint info
					if paint.auto {
						neighbours := get_neighbours(tm, x, y, z, tile.paint_index);
						bitmask := tile_bitmask(neighbours);
						//print("%\n", bitmask);
						
						uv := uv_from_bitmask(bitmask);
						
						src.min.x = (cast(float32)uv.x / tm.auto_col);
						src.max.y = (cast(float32)uv.y / tm.auto_row);
						src.max.x = src.min.x + 1. / tm.auto_col;
						src.min.y = src.max.y + 1. / tm.auto_row;
						
						src.min.y = 1 - src.min.y;
						src.max.y = 1 - src.max.y;
						//print("%\n", src);
						
						tile_rect := r.push_rect2(sprite_batches, dst, r.COLOR_WHITE);
						tile_rect.tex_id = arts[paint.art_id].tex.U64[1];
						tile_rect.src = src;
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
}

draw_entities :: (tm : Tilemap, sprite_batches : *r.BatchList) {
	for y: 0 .. tm.row - 1{
		for x: 0 .. tm.col - 1 {
			
			tile := tile_from_index(tm, x, y, 2);
			
			paint := paints[tile.paint_index];
			
			if paint.prop {
				dst : RectF32;
				dst.min.x = xx ((x + tm.index.x * tm.col) * tm.tile_size - paint.origin.x + 16);
				dst.min.y = xx ((y + tm.index.y * tm.row) * tm.tile_size - paint.origin.y + 16);
				dst.max.x = dst.min.x + paint.size.x;
				dst.max.y = dst.min.y + paint.size.y;
				
				tile_rect := r.push_rect2(sprite_batches, dst, r.COLOR_WHITE);
				tile_rect.tex_id = arts[paint.art_id].tex.U64[1];
				
				width := 1. / paint.frame_x;
				
				tile_rect.src = rectF32(paint.frame_n * width, 0, width * (paint.frame_n + 1), 1);
			}
		}
	}
}

draw_grid :: (sprite_batches : *r.BatchList) {
	for y: 1 .. Tilemap.row - 1 - 1 {
		for x: 1 .. Tilemap.col - 1 - 1 {
			dst : RectF32;
			dst.min.x = xx (x * Tilemap.tile_size);
			dst.min.y = xx (y * Tilemap.tile_size);
			dst.max.x = dst.min.x + Tilemap.tile_size;
			dst.max.y = dst.min.y + Tilemap.tile_size;
			
			tile_rect := r.push_rect2(sprite_batches, dst, .{});
			tile_rect.border_thickness = 4;
			tile_rect.border_color = r.COLOR_BLACK;
		}
	}
}

draw_outline :: (sprite_batches : *r.BatchList) {
	map_outline := r.push_rect2(sprite_batches, Tilemap.rect, .{0, 0, 0, 0});
	map_outline.border_color = r.COLOR_ORANGE;
	map_outline.border_thickness = 4;
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

tilemap_index_from_tile_pos :: (tile_pos : Vector2i) -> Vector2i {
	
	out : Vector2i;
	
	out.x = tile_pos.x / Tilemap.col;
	out.y = tile_pos.y / Tilemap.row;
	
	return out;
}