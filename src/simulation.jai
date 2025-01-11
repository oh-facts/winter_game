// main editor window
// option to edit levels
// option to play scenes
// scenes reference levels

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
	Interactable;
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
	highlight : bool;
};

EntityStore :: struct {
	arena : *Arena;
	first : *Entity;
	count : int;
	inactive_count : int;
	free : *Entity;
	
	// per frame
	sort_list : [..]*Entity;
}

active_count :: () -> int {
	return entity_store.count - entity_store.inactive_count;
}

entity_store : EntityStore;
world_initialized := false;
quest : Quest;

entity_alloc :: (flags : Entity_Flags) -> *Entity {
	out := entity_store.free;
	
	if out {
		entity_store.free = entity_store.free.next;
		entity_store.inactive_count -= 1;
	} else {
		out = push_struct(entity_store.arena, Entity);
	}
	
	<< out = .{};
	
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
world_tileworld : Tileworld;

world_update :: (delta : float32, events : *os.EventList, sprite_batches : *r.BatchList, ui_batches : *r.BatchList) {
	if !world_initialized {
		world_initialized = true;
		entity_store.arena = arena_init();
		entity_store.first = push_struct(entity_store.arena, void);
		
		entity_window = editor_init_window("entity inspector");
		world_window = editor_init_window("world inspector");
		
		editor_set_window_pos(world_window, .{1600, 0});
		world_tileworld = init_tileworld();
		
		load_tileworld(*world_tileworld);
		load_entities();
	}
	
	editor_window_begin(ui_batches, world_window);
	defer editor_window_end(world_window);
	
	if !world_window.hide {
		text := "restart";
		if editor_label(text).active {
			demo_quest = .{};
			unload_entities();
			load_tileworld(*world_tileworld);
			load_entities();
		}
	}
	
	tick(events, sprite_batches, ui_batches, delta);
	quest_update(*demo_quest, events, sprite_batches, ui_batches);
}

tick :: (events : *os.EventList, sprite_batches : *r.BatchList, ui_batches : *r.BatchList, delta : float32) {
	
	world_cmds.base = talloc(xx MB(1));
	world_cmds.count = 0;
	world_cmds.size = 0;
	world_cmds.cap = xx MB(1);
	
	tm_index := Vector2i.{};
	
	if py {
		tm_index = tilemap_index_from_tile_pos(py.tile_pos);
	}
	
	set_camera_pos(tm_index);
	
	world_tilemap := tilemap_from_key(*world_tileworld, tm_index);
	draw_tilemap(world_tilemap, sprite_batches);
	
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
		if entity.highlight {
			dst := tile_rect_from_index(world_tilemap, xx ((entity.tile_pos.x)), xx ((entity.tile_pos.y)), 0);
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
	
	
	for 0 .. entity_store.count - 1 {
		entity := entity_store.first + it;
		
		if entity.flags & .Inactive continue;
		
		if entity.flags & .Interactable {
			entity.highlight = false;
		}
	}
	
	
	base := world_cmds.base;
	for 0 .. world_cmds.count - 1 {
		header :*World_Cmd_Kind = xx base;
		
		if << header == {
			case .Eat;
			cmd : *World_Eat_Cmd = xx base;
			
			for 0 .. entity_store.count - 1 {
				entity := entity_store.first + it;
				
				if entity.flags & .Inactive continue;
				
				if entity.flags & .Interactable {
					
					if distance_squared(entity.tile_pos, cmd.tile_pos) < 4 {
						entity.highlight = true;
					};
					
				}
			}
			
		}
	}
}

load_entities :: () {
	
	for 0 .. world_tileworld.tm_count - 1 {
		
		tm := world_tileworld.tm_base + it;
		
		for y: 0 .. Tilemap.row - 1{
			for x: 0 .. Tilemap.col - 1 {
				
				tile := tile_from_index(tm, x, y, 2);
				
				paint := paints[tile.paint_index];
				
				if paint.prop {
					
					e : *Entity;
					
					if paint.kind == .Player {
						e = entity_alloc(.Control | .Animated);
						e.speed = 900;
						e.type = .Player;
						py = e;
					}
					else if paint.kind == .Tree {
						e = entity_alloc(.Interactable);
						e.type = .Tree;
					}
					else if paint.kind == .Ball {
						e = entity_alloc(0);
						//array_add(*entity_store.apples, e);
					}
					else if paint.kind == .Siren {
						e = entity_alloc(0);
					}
					
					if e {
						e.name = paint.name;
						e.art_id = paint.art_id;
						
						e.origin = paint.origin;
						e.size = paint.size;
						e.frame_x = paint.frame_x;
						e.frame_y = paint.frame_y;
						e.frame_n = paint.frame_n;
						e.pos = .{(x + tm.index.x * tm.col) * 32. + 16, (y + tm.index.y * tm.row) * 32. + 16};
					}
					
				}
			}
		}
	}
}

unload_entities :: () {
	entity_store.arena.used = 128;
	entity_store.free = xx 0;
	entity_store.inactive_count = 0;
	entity_store.count = 0;
}

Quest :: struct {
	started : bool;
	opening_prompt : bool;
}

demo_quest : Quest;

quest_update :: (quest : *Quest, events : *os.EventList, sprite_batches : *r.BatchList, ui_batches : *r.BatchList) {
	
	if !quest.started {
		quest.started = true;
		
		print("%", OPENING_PROMPT);
		py.flags &= ~.Control;
		
		// some cutscene. Very short. Just the explosion
	}
	
	if !quest.opening_prompt {
		
		padding := 16.;
		
		bg : RectF32;
		bg.min.x = 0;
		bg.min.y = 0;
		bg.max.x = camera.size.x;
		bg.max.y = camera.size.y;
		
		r.push_rect2(ui_batches, bg, r.COLOR_BLACK);
		r.push_text(ui_batches, font, OPENING_PROMPT, .{padding, padding}, text_size);
		
		continue_text := "space ->";
		
		text_rect := r.get_text_rect(font, continue_text, camera.size, text_size);
		
		bottom_right := camera.size - .{padding, padding};
		bottom_right.x -= (text_rect.max.x - text_rect.min.x);
		bottom_right.y -= (text_rect.max.y - text_rect.min.y);
		
		r.push_text(ui_batches, font, continue_text, bottom_right, text_size);
		if os.event(events, .SPACE, .Pressed) {
			py.flags |= .Control;
			quest.opening_prompt = true;
		}
	}
	
}