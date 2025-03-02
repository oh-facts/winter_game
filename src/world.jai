// i was thinking of using this as an offset into an image. So imagine a massive image with .. I don't feel like writing the rest I am particularly sad.

paints : [5]Entity : .[.{name = "empty"},
											 .{auto = true, art_id = .TerrainTemplate, name = "template 1"},
											 .{auto = true, art_id = .TerrainGrass, name = "auto grass"},
											 .{art_id = .TilesForest, name = "grass", src = .{.{0, 0},.{1, 1}}, frame_n = 9},
											 .{art_id = .TilesForest, name = "dirt", src = .{.{0, 0},.{1, 1}}, frame_n = 6},
											 ];

auto_col :: 8;
auto_row :: 6;

// TODO(mizu): generate tile collisions.
// idk if i want to move it to tile data
// or keep separate.
// i dont see point in keeping inside
// I think I will keep separate
// in the video you can talk about generating per frame collisions is easier now because of the array.
// Also I am thinking that I store entities
// in its own grid instead of having depth of 3
// since entity grid will also be per frame. Maybe this way, I would have an easier time saving the world data as tile data

// 0 : bg
// 1 : fg
// 2 : entity start locations ?

// I am thinking it might be better to store
// a physics tileworld. And build it every frame
// Either that, or I put it inside the tile struct
// Ok I have decided to store it inside the tile struct
// AOS would be easier. one memeset
// Separate occupied map would be easiest.
// Need to pass enums
// 

Tile_Kind :: enum {
	Gfx;
	Occupied;
}

Tile :: struct {
	layers :: 3;
	v : [layers]s32;
	entity : *Entity;
};

// TODO(mizu): Use something like this eventually?
/*
Tile :: union {
	S32 : [4]s32;
	S64 : [2]s64;
};
*/

Tilemap :: struct {
	// dim
	row :: 32;
	col :: 60;
	
	tile_size :: 32;
	count :: row * col;
	size_gfx :: count * size_of(Tile);
	size_occupied :: count * size_of(Tile);
	size :: size_gfx + size_occupied;
	rect :: RectF32.{.{0, 0}, .{(col) * tile_size, (row) * tile_size}};
	
	// tile data
	gfx : [row * col]Tile;
	
	// per frame
	occupied : [row * col]Tile;
	
	// hash link
	next : *Tilemap;
	
	// key
	index : Vector2i;
};

Tilemap_Slot :: struct {
	first : *Tilemap;
	last : *Tilemap;
}

Tileworld :: struct {
	slots : []Tilemap_Slot;
	
	// useful for serializing or for batch operations ??
	tilemap_arena : *Arena;
	tilemaps : []Tilemap;
}

init_tileworld :: () -> Tileworld {
	out : Tileworld;
	count :: 1024;
	
	out.slots.data = push_array(arena, Tilemap, xx (count));
	out.slots.count = count;
	out.tilemap_arena = arena_init();
	out.tilemaps.data = push_struct(out.tilemap_arena, void);
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
		out = push_struct(world.tilemap_arena, Tilemap);
		out.index = key;
		
		if slot.last {
			slot.last.next = out;
			slot.last = out;
		} else {
			slot.last = out;
			slot.first = out;
		}
		
		world.tilemaps.count += 1;
	}
	
	return out;
}

tilemap_from_key_dont_alloc:: (world : Tileworld, key : Vector2i) -> *Tilemap {
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
	
	return out;
}

save_tileworld :: (tw : Tileworld) {
	print("started saving\n");
	
	{
		filename := tprint("%/%", data_folder, "map_data");
		
		write_entire_file(filename, tw.tilemaps.data, size_of(Tilemap) * tw.tilemaps.count);
	}
	{
		filename := tprint("%/%", data_folder, "map_meta_data");
		
		count := tw.tilemaps.count;
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
				memcpy(tm.gfx.data, data[it].gfx.data, Tilemap.size);
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

get_neighbours :: (tw : Tileworld, x : int, y : int, z : int, paint_index : s32) -> TileNeighbours {
	out : TileNeighbours;
	using out;
	
	t  = tile_present(tw, x, y - 1, z); 
	tr = tile_present(tw, x + 1, y - 1, z); 
	r = tile_present(tw, x + 1, y, z); 
	br = tile_present(tw, x + 1, y + 1, z); 
	b = tile_present(tw, x, y + 1, z); 
	bl = tile_present(tw, x - 1, y + 1, z); 
	l = tile_present(tw, x - 1, y, z); 
	tl = tile_present(tw, x - 1, y - 1, z); 
	
	return out;
}

tile_present :: (tw : Tileworld, x : int, y : int, layer : int) -> bool {
	
	out : bool;
	tile := tile_from_index(tw, .{xx x, xx y}, .Gfx);
	
	if tile {
		out = xx tile.v[layer];
	}
	
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

local_to_real_coords :: (tm : Tilemap, l : Vector2i) -> Vector3i {
	out : Vector3i;
	out.x = l.x + tm.index.x * Tilemap.col;
	out.y = l.y + tm.index.y * Tilemap.row;
	
	return out;
}

real_to_local_coords :: (tw : Tileworld, r : Vector2i) -> Vector2i, Vector2i {
	out : Vector2i;
	
	tm_slot := Vector2i.{r.x / Tilemap.col, r.y / Tilemap.row};
	
	out.x = r.x % Tilemap.col;
	out.y = r.y % Tilemap.row;
	
	return tm_slot, out;
}

tile_from_index :: (tw : Tileworld, r : Vector2i, kind : Tile_Kind) -> *Tile {
	tm_slot, index := real_to_local_coords(tw, r);
	
	tm := tilemap_from_key_dont_alloc(tw, tm_slot);
	
	out : *Tile;
	
	if tm {
		tile_slot := index.y * tm.col + index.x;
		
		if index.x >= 0 && index.y >= 0 && index.x < tm.col && index.y < tm.row {
			
			if kind == .Gfx out = *tm.gfx[tile_slot];
			else if kind == .Occupied out = *tm.occupied[tile_slot];
			
		}
	}
	
	return out;
}

tile_from_local_index :: (tm : *Tilemap, l : Vector2i, kind : Tile_Kind) -> *Tile {
	tile_slot := l.y * tm.col + l.x;
	
	tile : *Tile;
	if l.x >= 0 && l.y >= 0 && l.x < tm.col && l.y < tm.row {
		
		if kind == .Gfx tile = *tm.gfx[tile_slot];
		else if kind == .Occupied tile = *tm.occupied[tile_slot];
	}
	
	return tile;
}

tile_rect_from_index :: (pos : Vector2i) -> RectF32 {
	out := rectF32(cast(float32) pos.x * Tilemap.tile_size, cast(float32) pos.y * Tilemap.tile_size, cast(float32) pos.x * Tilemap.tile_size + Tilemap.tile_size, cast(float32) pos.y * Tilemap.tile_size + Tilemap.tile_size);
	
	return out;
}

tile_rect_from_index :: (x : s32, y : s32) -> RectF32{
	out := rectF32(cast(float32) x * Tilemap.tile_size, cast(float32) y * Tilemap.tile_size, cast(float32) x * Tilemap.tile_size + Tilemap.tile_size, cast(float32) y * Tilemap.tile_size + Tilemap.tile_size);
	
	return out;
}

index_from_coords :: (pos : Vector2) -> Vector2i {
	return Vector2i.{cast(s32)pos.x / Tilemap.tile_size, cast(s32)pos.y / Tilemap.tile_size};
}

draw_tilemap :: (tw : Tileworld, tm : *Tilemap, passes : *r.Pass_List) {
	scope := tex.scope_open();
	
	// draw tilemap
	//r.push_beam(passes);
	for y: 0 .. tm.row - 1 {
		for x: 0 .. tm.col - 1 {
			
			if x == 1 && y == 1 {
				i____t := 0;
			}
			
			tile := tile_from_local_index(tm, .{xx x, xx y}, .Gfx);
			
			if tile {
				for layer : 0 .. Tile.layers - 2 {
					
					if tile.v[layer] {
						paint := paints[tile.v[layer]];
						
						dst : RectF32;
						dst.min.x = xx ((x + tm.index.x * tm.col) * tm.tile_size);
						dst.min.y = xx ((y + tm.index.y * tm.row) * tm.tile_size);
						dst.max.x = dst.min.x + tm.tile_size + 1;
						dst.max.y = dst.min.y + tm.tile_size + 1;
						
						src : RectF32;
						
						tex_id := tex.handle_from_hash(scope, arts[paint.art_id].hash).U64[1];
						frame_x := arts[paint.art_id].frame_x;
						frame_y := arts[paint.art_id].frame_y;
						
						// if its a terrain (auto), the src rect are calculated based on the ruleset, if not, it is based on whats in the paint info
						if paint.auto {
							
							real := local_to_real_coords(tm, .{xx x, xx y});
							
							neighbours := get_neighbours(tw, real.x, real.y, layer, tile.v[layer]);
							bitmask := tile_bitmask(neighbours);
							//print("%\n", bitmask);
							
							uv := uv_from_bitmask(bitmask);
							
							src.min.x = (cast(float32)uv.x / auto_col);
							src.max.y = (cast(float32)uv.y / auto_row);
							src.max.x = src.min.x + 1. / auto_col;
							src.min.y = src.max.y + 1. / auto_row;
							
							src.min.y = 1 - src.min.y;
							src.max.y = 1 - src.max.y;
							//print("%\n", src);
							
							tile_rect := r.push_sprite(passes, dst, r.COLOR_WHITE);
							tile_rect.tex_id = tex_id;
							tile_rect.src = src;
						}
						else {
							src.min.x = (cast(float32) (paint.frame_n % frame_x) / frame_x);
							src.max.y = (cast(float32)((paint.frame_n / frame_x)) / frame_y);
							src.max.x = src.min.x + 1. / frame_x;
							src.min.y = src.max.y + 1. / frame_y;
							
							src.min.y = 1 - src.min.y;
							src.max.y = 1 - src.max.y;
							//print("%\n", src);
							
							tile_rect := r.push_sprite(passes, dst, r.COLOR_WHITE);
							tile_rect.tex_id = tex_id;
							tile_rect.src = src;
						}
					}
				}
			}
			
		}
	}
	
	tex.scope_close(scope);
}

draw_grid :: (passes : *r.Pass_List) {
	for y: 0 .. Tilemap.row - 1 {
		for x: 0 .. Tilemap.col - 1 {
			dst : RectF32;
			dst.min.x = xx (x * Tilemap.tile_size);
			dst.min.y = xx (y * Tilemap.tile_size);
			dst.max.x = dst.min.x + Tilemap.tile_size;
			dst.max.y = dst.min.y + Tilemap.tile_size;
			
			tile_rect := r.push_rect2(passes, dst, .{});
			tile_rect.border_thickness = 2;
			tile_rect.border_color = r.COLOR_BLACK;
		}
	}
}

draw_outline :: (passes : *r.Pass_List) {
	map_outline := r.push_rect2(passes, Tilemap.rect, .{0, 0, 0, 0});
	map_outline.border_color = r.COLOR_ORANGE;
	map_outline.border_thickness = 4;
}

// @debug
disco_tilemap :: (passes : *r.Pass_List) {
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
			
			tile_rect := r.push_rect2(passes, dst, color);
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

// lol no need for tile map collisions , since that data is stored inside the tile tileworld
// unless ... unless ofc ....
// I am thinking I memcpy it once, then when recreating the physics map, I just memset the map to 0
// eh, whats the point

// I had another idea!!
// What if, I just stored a physics tile inside
// of the tilemap that uses the same tile ??
// I can just memset the physics tile to 0
// This is clearly the best idea.

generate_collisions :: (tw : *Tileworld, store : Entity_Store) {
	for 0 .. entity_store.count - 1 {
		entity := entity_store.first + it;
		
		if entity.flags & .Inactive continue;
		
		tile := tile_from_index(tw, entity.tile_pos, .Occupied);
		tile.v[0] = 1;
		tile.entity = entity;
	}
}

clear_collisions :: (tw : *Tileworld) {
	for tw.tilemaps {
		memset(it.occupied.data, 0, Tilemap.size_occupied);
	}
}

draw_tilemap_collisions :: (tw : Tileworld, tm : *Tilemap, passes : *r.Pass_List) {
	for y: 0 .. tm.row - 1 {
		for x: 0 .. tm.col - 1 {
			
			tile := tile_from_local_index(tm, .{xx x, xx y}, .Occupied);
			
			if tile {
				
				if tile.v[0] {
					dst : RectF32;
					dst.min.x = xx ((x + tm.index.x * tm.col) * tm.tile_size);
					dst.min.y = xx ((y + tm.index.y * tm.row) * tm.tile_size);
					dst.max.x = dst.min.x + tm.tile_size + 1;
					dst.max.y = dst.min.y + tm.tile_size + 1;
					tile_rect := r.push_sprite(passes, dst, r.COLOR_RED);
				}
			}
		}
	}
}