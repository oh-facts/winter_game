World_Cmd_Kind :: enum {
	Eat;
}

World_Cmd_Header :: struct {
	kind : World_Cmd_Kind;
}

World_Eat_Cmd :: struct {
	header : World_Cmd_Header;
	
	// position of eater
	tile_pos : Vector2i;
}

World_Cmd_Buffer :: struct {
	base : *u8;
	count : int;
	size : s64;
	cap : s64;
}

world_cmds : World_Cmd_Buffer;

push_world_eat_cmd :: (tile_pos : Vector2i) {
	data : *World_Eat_Cmd = xx world_cmds.base;
	data.tile_pos = tile_pos;
	
	world_cmds.count += 1;
	world_cmds.size += size_of(World_Eat_Cmd);
}

Entity_Type :: enum {
	Nothing;
	Player;
	Tree;
}

Entity_Flags :: enum_flags u64 {
	Control;
	Animated;
	Inactive;
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
	color : Vector4;
	next : *Entity;
};

entity_templates : [2]Entity : .[.{type = .Player, art_id = .Impolo, size = .{64, 64}, origin = .{32, 64}, frame_x = 8, frame_y = 1, speed = 300.},
																 .{type = .Tree, art_id = .Tree, size = .{512, 512}, frame_x = 3, frame_y = 1, frame_n = 0, origin = .{256, 380}}];

EntityStore :: struct {
	arena : *Arena;
	first : *Entity;
	count : int;
	inactive_count : int;
	sort_list : [..]*Entity;
	apples : [..]*Entity;
	free : *Entity;
}

active_count :: () -> int {
	return entity_store.count - entity_store.inactive_count;
}

entity_store : EntityStore;
world_initialized := false;

entity_alloc :: (flags : Entity_Flags) -> *Entity {
	out := entity_store.free;
	
	if out {
		entity_store.free = entity_store.free.next;
		entity_store.inactive_count -= 1;
		<< out = .{};
	} else {
		out = push_struct(entity_store.arena, Entity);
	}
	
	entity_store.count += 1;
	out.flags = flags;
	
	return out;
}

entity_free :: (entity : *Entity) {
	entity.next = entity_store.free;
	entity_store.free = entity;
	entity.flags |= .Inactive;
	entity_store.inactive_count += 1;
}

entity_window : *Editor_Window;
world_window : *Editor_Window;

py : *Entity;

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
			load_tilemap();
			load_entities();
			started = true;
		}
	}
	
	if started {
		tick(events, sprite_batches, ui_batches, delta);
	}
	
}

started := false;

tick :: (events : *os.EventList, sprite_batches : *r.BatchList, ui_batches : *r.BatchList, delta : float32) {
	
	world_cmds.base = talloc(xx MB(1));
	world_cmds.count = 0;
	world_cmds.size = 0;
	world_cmds.cap = xx MB(1);
	
	if py {
		pos : Vector2;
		pos.x = xx (py.pos.x);
		pos.y = xx (py.pos.y);
		
		set_camera_pos(pos);
	}
	
	draw_tilemap(sprite_batches);
	
	// control
	for 0 .. entity_store.count - 1 {
		entity := entity_store.first + it;
		
		if entity.flags & .Inactive continue;
		
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
				push_world_eat_cmd(entity.tile_pos);
			}
		}
	}
	
	// update tile pos
	for 0 .. entity_store.count - 1 {
		entity := entity_store.first + it;
		
		if entity.flags & .Inactive continue;
		
		entity.tile_pos.x = xx (entity.pos.x / 32.);
		entity.tile_pos.y = xx (entity.pos.y / 32.);
	}
	
	// update animations
	for 0 .. entity_store.count - 1 {
		entity := entity_store.first + it;
		
		if entity.flags & .Inactive continue;
		
		if entity.flags & .Animated {
			
			entity.anim_counter += xx delta;
			
			entity.frame_n = (xx (entity.anim_counter * 10)) % entity.frame_x;
		}
	}
	
	// draw
	for 0 .. entity_store.count - 1 {
		entity := entity_store.first + it;
		if entity.flags & .Inactive continue;
		
		// draw occupied tile
		ifx 0 {
			dst := tile_rect_from_index(xx ((entity.tile_pos.x)), xx ((entity.tile_pos.y)), 0);
			r.push_rect2(sprite_batches, dst, .{1, 1, 1, 1});
		}
		
		// draw origin
		ifx 0 {
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
	
	base := world_cmds.base;
	for 0 .. world_cmds.count - 1 {
		header :*World_Cmd_Kind = xx base;
		
		if << header == {
			case .Eat;
			eat_cmd :*World_Eat_Cmd= xx base;
			//print("Tried to eat apple from %\n", eat_cmd.tile_pos);
			
			for entity_store.apples {
				if distance_squared(it.tile_pos, eat_cmd.tile_pos) < 4 {
					entity_free(it);
					array_unordered_remove_by_index(*entity_store.apples, it_index);
				}
				
				base += size_of(World_Eat_Cmd);
			}
			
		}
		
	}
	
	{
		text := tprint("% balls left!", entity_store.apples.count);
		text_rect := r.get_text_rect(font, text, .{10, 10}, 0.4);
		r.push_rect2(ui_batches, text_rect, r.COLOR_BLACK);
		
		r.push_text(ui_batches, font, text, .{10, 10}, 0.4, r.COLOR_RED);
		
	}
	
	if entity_store.apples.count == 0 {
		
		text := tprint("You have eaten all my balls! Victory is yours!");
		
		r.push_text(ui_batches, font, text, .{400, 500}, 1, r.COLOR_BLACK);
		
	}
	
	if entity_store.apples.count == 0 {
		//exit(0);
	}
	
	editor_window_begin(ui_batches, entity_window);
	
	if !entity_window.hide {
		
		builder: String_Builder;
		builder.allocator = __temporary_allocator;
		
		ti := type_info(Entity);
		
		entity_window.entity_scroll_region.min = entity_window.layout.text_pos;
		
		e_count := active_count();
		
		entity_window.entry_start = max(entity_window.entry_start, 0);
		entity_window.entry_start = min(entity_window.entry_start, e_count - entry_count - 1);
		
		start := entity_window.entry_start;
		end := start + entry_count;
		
		occluded : bool;
		
		for i : start .. end {
			entity := entity_store.first + i;
			
			if entity.flags & .Inactive {
				end += 1;
				continue;
			}
			
			//print("%", << entity);
			
			if (ui_button(.{1, i, 0}, entity.name).toggle) {
				
				ui_begin_parent();
				
				count := ti.members.count;
				
				scroll := *entity_window.entity_scrolls[i];
				
				if point_in_rect(mpos, scroll.rect) {
					
					occluded = true;
					
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
		
		entity_window.entity_scroll_region.max = entity_window.layout.rect_max;
		
		if !occluded {
			if point_in_rect(mpos, entity_window.entity_scroll_region) {
				
				if scroll_up {
					entity_window.entry_start -= 1;
				}
				
				else if scroll_down {
					entity_window.entry_start += 1;
				}
				
			}
		}
	}
}

load_entities :: () {
	for y: 0 .. tilemap.row - 1{
		for x: 0 .. tilemap.col - 1 {
			
			tile := tile_from_index(x, y, 2);
			
			paint := paints[tile.paint_index];
			
			if paint.prop {
				
				e : *Entity;
				
				if paint.kind == .Player {
					e = entity_alloc(.Control | .Animated);
					e.speed = 300;
					e.type = .Player;
					py = e;
				}
				else if paint.kind == .Tree {
					e = entity_alloc(0);
					e.type = .Tree;
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
