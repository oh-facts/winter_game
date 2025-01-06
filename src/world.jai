Entity_Type :: enum {
	Player;
	Tree;
}

Entity_Flags :: enum_flags u64 {
	Control;
	Animated;
}

Entity :: struct {
	name : string;
	type : Entity_Type;
	flags : Entity_Flags;
	anim_counter : float32;
	art_id : ArtId;
	speed : float32;
	size : Vector2i;
	pos : Vector2;
	tile_pos : Vector2i;
	origin : Vector2;
	frame_x : s32;
	frame_y : s32;
	frame_n : s32;
	eaten : bool;
};

entity_templates : [2]Entity : .[.{type = .Player, art_id = .Impolo, size = .{64, 64}, origin = .{32, 64}, frame_x = 8, frame_y = 1, speed = 300.},
																 .{type = .Tree, art_id = .Tree, size = .{512, 512}, frame_x = 3, frame_y = 1, frame_n = 0, origin = .{256, 380}}];

EntityStore :: struct {
	arena : *Arena;
	first : *Entity;
	count : u32;
	sort_list : [..]*Entity;
	apples : [..]*Entity;
}

entity_store : EntityStore;
world_initialized := false;

entity_alloc :: (flags : Entity_Flags) -> *Entity {
	out : *Entity;
	out = push_struct(entity_store.arena, Entity);
	entity_store.count += 1;
	out.flags = flags;
	
	return out;
}

entity_window : *Editor_Window;
world_window : *Editor_Window;

py : *Entity;

Scene_Tile :: struct {
	src : RectF32;
	art_id : ArtId;
}

Scene :: struct {
	row :: 50;
	col :: 50;
	depth :: 2;
	
	tiles : []Scene_Tile;
}

scene : Scene;

scene_data_from_map_data :: () {
	
	count := scene.row * scene.col * tilemap.depth;
	
	scene.tiles.data = push_array(arena, Scene_Tile, xx (count));
	scene.tiles.count = count;
	
	for z: 0 .. tilemap.depth - 1 {
		for y: 0 .. tilemap.row - 1 {
			for x: 0 .. tilemap.col - 1 {
				
				tile := tile_from_index(x, y, z);
				paint := paints[tile.paint_index];
				
				if !paint.empty {
					if paint.prop {
						
						e : *Entity;
						
						if paint.kind == .Player {
							e = entity_alloc(.Control | .Animated);
							py = e;
							py.speed = 300;
						}
						else if paint.kind == .Tree {
							e = entity_alloc(0);
						}
						else if paint.kind == .Ball {
							e = entity_alloc(0);
							array_add(*entity_store.apples, e);
						}
						
						if e {
							e.name = paint.name;
							e.art_id = paint.art_id;
							
							e.origin = paint.origin;
							e.size = paint.size;
							e.frame_x = paint.frame_x;
							e.frame_y = paint.frame_y;
							e.frame_n = paint.frame_n;
							e.pos = .{x * 32. + 16, y * 32. + 16};
						}
						
					}
					else {
						
						scene_tile := scene_tile_from_index(x, y, z);
						
						neighbours := get_neighbours(x, y, z, tile.paint_index);
						bitmask := tile_bitmask(neighbours);
						//print("%\n", bitmask);
						
						uv := uv_from_bitmask(bitmask);
						
						src : RectF32;
						src.min.x = (cast(float32)uv.x / tilemap.auto_col);
						src.max.y = (cast(float32)uv.y / tilemap.auto_row);
						src.max.x = src.min.x + 1. / tilemap.auto_col;
						src.min.y = src.max.y + 1. / tilemap.auto_row;
						
						src.min.y = 1 - src.min.y;
						src.max.y = 1 - src.max.y;
						//print("%\n", src);
						
						scene_tile.src = src;
						scene_tile.art_id = paint.art_id;
					}
				}
			}
		}
	}
	
}

world_update :: (delta : float32, events : *os.EventList, sprite_batches : *r.BatchList, ui_batches : *r.BatchList) {
	if !world_initialized {
		world_initialized = true;
		entity_store.arena = arena_init();
		entity_store.first = push_struct(entity_store.arena, void);
		
		entity_window = editor_init_window("entity inspector");
		world_window = editor_init_window("world inspector");
		
		editor_set_window_pos(world_window, .{1600, 0});
	}
	
	editor_window_begin(ui_batches, world_window);
	
	if !world_window.hide {
		text := "start";
		if ui_button(.{200, 0, 0}, text).active {
			scene_data_from_map_data();
			started = true;
		}
	}
	
	if started {
		tick(events, sprite_batches, ui_batches, delta);
	}
	
}

started := false;

tick :: (events : *os.EventList, sprite_batches : *r.BatchList, ui_batches : *r.BatchList, delta : float32) {
	
	set_camera_pos(py.pos);
	
	for z: 0 .. scene.depth {
		for y: 0 .. scene.row - 1 {
			for x: 0 .. scene.col - 1 {
				
				scene_tile := scene_tile_from_index(x, y, z);
				
				dst : RectF32;
				dst.min.x = xx (x * tilemap.tile_size);
				dst.min.y = xx (y * tilemap.tile_size);
				dst.max.x = dst.min.x + tilemap.tile_size;
				dst.max.y = dst.min.y + tilemap.tile_size;
				
				tile_rect := r.push_rect2(sprite_batches, dst, r.COLOR_WHITE);
				tile_rect.src = scene_tile.src;
				tile_rect.tex_id = arts[scene_tile.art_id].tex.U64[1];
			}
		}
	}
	// control
	for 0 .. entity_store.count - 1 {
		entity := entity_store.first + it;
		
		if entity.flags & .Control {
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
			
			entity.pos.x += mv.x * xx delta * entity.speed;
			entity.pos.y += mv.y * xx delta * entity.speed;
			
			if os.event(events, .E, .Pressed) {
				
				for entity_store.apples {
					if distance(it.pos, entity.pos) < 15 {
						it.eaten = true;
					}
				}
				
			}
			
		}
	}
	
	// update tile pos
	for 0 .. entity_store.count - 1 {
		entity := entity_store.first + it;
		
		entity.tile_pos.x = xx (entity.pos.x / 32.);
		entity.tile_pos.y = xx (entity.pos.y / 32.);
	}
	
	// update animations
	for 0 .. entity_store.count - 1 {
		entity := entity_store.first + it;
		
		if entity.flags & .Animated {
			
			entity.anim_counter += xx delta;
			
			entity.frame_n = (xx (entity.anim_counter * 10)) % entity.frame_x;
		}
	}
	
	// draw
	for 0 .. entity_store.count - 1 {
		entity := entity_store.first + it;
		
		if entity.eaten {
			continue;
		}
		
		// draw occupied tile
		{
			dst := tile_rect_from_index(xx ((entity.tile_pos.x)), xx ((entity.tile_pos.y)), 0);
			r.push_rect2(sprite_batches, dst, .{1, 1, 1, 1});
		}
		
		// draw origin
		{
			dst : RectF32;
			dst.min.x = entity.pos.x;
			dst.min.y = entity.pos.y;
			dst.max.x = dst.min.x + 8;
			dst.max.y = dst.min.y + 8;
			
			origin := r.push_rect2(sprite_batches, dst, r.COLOR_YELLOW);
			origin.radius = 4;
			origin.border_color = r.COLOR_BLACK;
			origin.border_thickness = 2;
		}
		
		// draw sprite
		{
			array_add(*entity_store.sort_list, entity);
		}
		
	}
	
	sort_entitties :: (a : *Entity, b : *Entity) -> int {
		pos_a := a.pos;
		pos_b := b.pos;
		
		out : int = 1;
		if pos_a.y < pos_b.y {
			out = -1;
		}
		
		return out; 
	}
	
	intro_sort(entity_store.sort_list, sort_entitties);
	
	for entity_store.sort_list {
		dst : RectF32;
		dst.min.x = it.pos.x - it.origin.x;
		dst.min.y = it.pos.y - it.origin.y;
		dst.max.x = dst.min.x + it.size.x;
		dst.max.y = dst.min.y + it.size.y;
		
		sprite := r.push_rect2(sprite_batches, dst, .{1, 1, 1, 1});
		sprite.tex_id = arts[it.art_id].tex.U64[1];
		
		width := 1. / it.frame_x;
		
		sprite.src = rectF32(it.frame_n * width, 0, width * (it.frame_n + 1), 1);
	}
	
	array_reset_keeping_memory(*entity_store.sort_list);
	
	editor_window_begin(ui_batches, entity_window);
	
	if !entity_window.hide {
		
		builder: String_Builder;
		builder.allocator = __temporary_allocator;
		
		ti := type_info(Entity);
		for i : 0 .. entity_store.count - 1 {
			entity := entity_store.first + i;
			//print("%", << entity);
			
			if (ui_button(.{1, i, 0}, entity.name).toggle) {
				
				ui_begin_parent();
				
				count := ti.members.count;
				
				scroll := *entity_window.entity_scrolls[i];
				
				if point_in_rect(mpos, scroll.rect) {
					if scroll_up {
						scroll.entry_start -= 1;
					}
					
					else if scroll_down {
						scroll.entry_start += 1;
					}
				}
				
				scroll.entry_start = max(scroll.entry_start, 0);
				scroll.entry_start = min(scroll.entry_start, count - entry_count - 1);
				
				start := scroll.entry_start;
				end := start + entry_count;
				
				scroll.rect.min = entity_window.layout.text_pos;
				
				for ti.members {
					if it_index >= start && it_index <= end {
						any: Any = ---;
						any.type = it.type;
						any.value_pointer = cast(*u8)entity + it.offset_in_bytes;
						
						print_item_to_builder(*builder, any);
						
						field_name := builder_to_string(*builder,, allocator = __temporary_allocator);
						
						text := tprint("%: %", it.name, field_name);
						ui_label(.{1, 0, 0}, text);
					}
				}
				
				scroll.rect.max = entity_window.layout.rect_max;
				ui_end_parent();
				
			}
		}
	}
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

scene_tile_from_index :: (x : int, y : int, z : int) -> *Scene_Tile {
	return *scene.tiles[z * scene.row * scene.col + y * scene.col + x];
}