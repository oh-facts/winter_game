// main editor window
// option to edit levels
// option to play scenes
// scenes reference levels

World_Cmd_Kind :: enum {
	Eat;
	Complete_Interaction;
}

World_Cmd_Header :: struct {
	kind : World_Cmd_Kind;
}

World_Eat_Cmd :: struct {
	header : World_Cmd_Header;
	// position of eater
	tile_pos : Vector2i;
}

World_Complete_Interaction_Cmd :: struct {
	header : World_Cmd_Header;
}

World_Cmd_Buffer :: struct {
	base : *u8;
	count : int;
	size : s64;
	cap : s64;
}

active_entity : *Entity;

world_cmds : World_Cmd_Buffer;

push_world_eat_cmd :: (tile_pos : Vector2i) {
	data : *World_Eat_Cmd = xx world_cmds.base;
	data.tile_pos = tile_pos;
	data.header.kind = .Eat;
	
	world_cmds.count += 1;
	world_cmds.size += size_of(World_Eat_Cmd);
}

push_world_complete_interaction :: () {
	data : *World_Complete_Interaction_Cmd = xx world_cmds.base;
	data.header.kind = .Complete_Interaction;
	world_cmds.count += 1;
	world_cmds.size += size_of(World_Complete_Interaction_Cmd);
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
	Sloppy_Shadow;
}

Interaction_State :: enum {
	Cold;
	Hot;
	Active;
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
	interaction_state : Interaction_State;
	next : *Entity;
	submerged : float;
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

world_update :: (delta : float32, events : *os.EventList, 
								 passes : *r.Pass_List) {
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
	
	editor_window_begin(world_window);
	defer editor_window_end(world_window);
	
	if !world_window.hide {
		text := "restart";
		if editor_label(text).active {
			demo_quest = .{};
			unload_entities();
			load_tileworld(*world_tileworld);
			load_entities();
		}
		
		if py {
			text = tprint("%", tm_index);
			editor_label(text);
			
			text = tprint("%", py.tile_pos);
			editor_label(text);
		}
		
		text = tprint("%", delta);
		editor_label(text);
	}
	
	tick(events, passes, delta);
	quest_update(*demo_quest, events, passes);
}

tm_index := Vector2i.{};
aos_tm_index := Vector2i.{3, 3};

tick :: (events : *os.EventList, passes : *r.Pass_List, delta : float32) {
	
	world_cmds.base = talloc(xx MB(1));
	world_cmds.count = 0;
	world_cmds.size = 0;
	world_cmds.cap = xx MB(1);
	
	if py {
		tm_index = tilemap_index_from_tile_pos(py.tile_pos);
	}
	
	set_camera_pos(tm_index);
	
	world_tilemap := tilemap_from_key(*world_tileworld, tm_index);
	
	r.begin_water(passes);
	draw_tilemap(world_tileworld, world_tilemap, passes);
	
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
			
			test_pos := entity.pos;
			test_pos.x += mv.x * xx delta * entity.speed;
			test_pos.y += mv.y * xx delta * entity.speed;
			
			
			test_tile_pos : Vector2i;
			test_tile_pos.x = cast(s32) test_pos.x / 32;
			test_tile_pos.y = cast(s32) test_pos.y / 32;
			
			
			
			entity.pos = test_pos;
			
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
	
	highlighted_entity : *Entity;
	
	// 
	for 0 .. entity_store.count - 1 {
		entity := entity_store.first + it;
		
		if entity.flags & .Inactive continue;
		
		if entity.flags & .Interactable {
			
			if distance_squared(entity.tile_pos, py.tile_pos) < 4 {
				if entity.interaction_state == .Cold {
					entity.interaction_state = .Hot;
					highlighted_entity = entity;
				}
			};
			
		}
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
		{
			dst := tile_rect_from_index(xx ((entity.tile_pos.x)), xx ((entity.tile_pos.y)), xx 0);
			if entity.interaction_state == {
				case .Hot;
				r.push_sprite(passes, dst, .{1, 1, 1, 1});
				case .Active;
				r.push_sprite(passes, dst, .{0, 0, 1, 1});
			}
		}
		
		// draw shadow
		if entity.flags & .Sloppy_Shadow {
			// cylinder radius and "extra" width when
			// one stretches a circle along x to form
			// a cylinder
			rad :: 12.;
			fat :: 6.;
			
			dst : RectF32;
			dst.min.x = entity.pos.x - rad - fat / 2;
			dst.min.y = entity.pos.y - rad;
			dst.max.x = dst.min.x + rad*2 + fat;
			dst.max.y = dst.min.y + rad*2;
			
			shadow := r.push_sprite(passes, dst, .{0, 0, 0, 0.4});
			shadow.radius = rad;
		}
		
		// draw origin
		if 0 {
			dst : RectF32;
			dst.min.x = entity.pos.x;
			dst.min.y = entity.pos.y;
			dst.max.x = dst.min.x + 8;
			dst.max.y = dst.min.y + 8;
			
			origin := r.push_sprite(passes, dst, r.COLOR_YELLOW);
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
		
		sprite := r.push_sprite(passes, dst, .{1, 1, 1, 1});
		sprite.tex_id = arts[it.art_id].tex.U64[1];
		sprite.pad2[0] = -1.;
		sprite.pad2[1] = it.submerged;
		
		width := 1. / it.frame_x;
		
		sprite.src = rectF32(it.frame_n * width, 0, width * (it.frame_n + 1), 1);
	}
	
	calculate_beam_pos :: () -> Vector2 {
		c := py.pos;//tm_index;
		t :: Vector2i.{10 * Tilemap.tile_size * Tilemap.col, 10 * Tilemap.tile_size * Tilemap.row};
		
		out : Vector2;
		
		out.x = (cast(float32)c.x) / t.x - 0.5;;
		out.y = (cast(float32)c.y) / t.y;
		
		return out;
	}
	
	beam_pos = calculate_beam_pos();
	
	r.push_beam(passes);
	
	r.end_water(passes);
	
	for entity_store.sort_list {
		dst : RectF32;
		dst.min.x = it.pos.x - it.origin.x;
		dst.min.y = it.pos.y - it.origin.y;
		dst.max.x = dst.min.x + it.size.x;
		dst.max.y = dst.min.y + it.size.y;
		
		sprite := r.push_sprite(passes, dst, .{1, 1, 1, 1});
		sprite.tex_id = arts[it.art_id].tex.U64[1];
		sprite.pad2[0] = 1.;
		sprite.pad2[1] = it.submerged;
		
		width := 1. / it.frame_x;
		
		sprite.src = rectF32(it.frame_n * width, 0, width * (it.frame_n + 1), 1);
	}
	
	array_reset_keeping_memory(*entity_store.sort_list);
	
	for 0 .. entity_store.count - 1 {
		entity := entity_store.first + it;
		
		if entity.flags & .Inactive continue;
		
		if entity.flags & .Interactable {
			if entity.interaction_state == {
				case .Hot;
				entity.interaction_state = .Cold;
			}
		}
	}
	
	if active_entity {
		if active_entity.type == .Tree {
			
			if dialogue_box(passes, events, TREE_TALK) {
				push_world_complete_interaction();
			}
		}
	}
	
	base := world_cmds.base;
	for 0 .. world_cmds.count - 1 {
		header :*World_Cmd_Kind = xx base;
		
		if << header == {
			case .Eat;
			cmd : *World_Eat_Cmd = xx base;
			if highlighted_entity {
				highlighted_entity.interaction_state = .Active;
				
				active_entity = highlighted_entity;
				
			}
			
			case .Complete_Interaction;
			cmd : *World_Complete_Interaction_Cmd = xx base;
			active_entity.interaction_state = .Hot;
			active_entity = xx 0;
		}
	}
}

load_entities :: () {
	
	for 0 .. world_tileworld.tm_count - 1 {
		
		tm := world_tileworld.tm_base + it;
		
		for y: 0 .. Tilemap.row - 1{
			for x: 0 .. Tilemap.col - 1 {
				
				tile := tile_from_local_index(tm, .{xx x, xx y, 2});
				
				paint := paints[tile.paint_index];
				
				if paint.prop {
					
					e : *Entity;
					
					if paint.kind == .Player {
						e = entity_alloc(.Control | .Animated | .Sloppy_Shadow);
						e.speed = 1400;
						e.type = .Player;
						e.submerged = 0.2;
						py = e;
					}
					else if paint.kind == .Tree {
						e = entity_alloc(.Interactable);
						e.type = .Tree;
						e.submerged = 0.28;
					}
					else if paint.kind == .Ball {
						e = entity_alloc(0);
						//array_add(*entity_store.apples, e);
					}
					else if paint.kind == .Siren {
						e = entity_alloc(0);
						e.submerged = 0.2;
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

quest_update :: (quest : *Quest, events : *os.EventList, passes : *r.Pass_List) {
	
	if !quest.started {
		quest.started = true;
		
		print("%", OPENING_PROMPT);
		py.flags &= ~.Control;
		
		// some cutscene. Very short. Just the explosion
	}
	
	if !quest.opening_prompt {
		
		quest.opening_prompt = dialogue_box(passes, events, OPENING_PROMPT);
		
	}
	
}

dialogue_box :: (passes : *r.Pass_List, events : *os.EventList, text : string) -> bool {
	out := false;
	padding := 16.;
	
	bg : RectF32;
	bg.min.x = 0;
	bg.min.y = 0;
	bg.max.x = camera.size.x;
	bg.max.y = camera.size.y;
	
	r.push_rect2(passes, bg, r.COLOR_BLACK);
	r.push_text(passes, font, text, .{padding, padding}, text_size);
	
	continue_text := "space ->";
	
	text_rect := r.get_text_rect(font, continue_text, camera.size, text_size);
	
	bottom_right := camera.size - .{padding, padding};
	bottom_right.x -= (text_rect.max.x - text_rect.min.x);
	bottom_right.y -= (text_rect.max.y - text_rect.min.y);
	
	r.push_text(passes, font, continue_text, bottom_right, text_size);
	
	if os.event(events, .SPACE, .Pressed) {
		py.flags |= .Control;
		out = true;
	}
	return out;
}