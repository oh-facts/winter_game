// main editor window
// option to edit levels
// option to play scenes
// scenes reference levels

// I think mimic trees will just have
// a demon shadow ??

World_Cmd_Kind :: enum {
	Eat;
	Test_Interaction;
	Start_Interaction;
	Complete_Interaction;
	Start_Attack;
}

World_Cmd_Header :: struct {
	kind : World_Cmd_Kind;
}

World_Eat_Cmd :: struct {
	header : World_Cmd_Header;
	// position of eater
	tile_pos : Vector2i;
}

World_Test_Interaction_Cmd :: struct {
	header : World_Cmd_Header;
}

World_Start_Interaction_Cmd :: struct {
	header : World_Cmd_Header;
	id : Interaction_Id;
}

World_Complete_Interaction_Cmd :: struct {
	header : World_Cmd_Header;
	id : Interaction_Id;
}

World_Start_Attack_Cmd :: struct {
	header : World_Cmd_Header;
	entity : *Entity; 
}

World_Cmd_Buffer :: struct {
	base : *u8;
	count : int;
	size : s64;
	cap : s64;
}

world_cmds : World_Cmd_Buffer;

push_world_eat_cmd :: (tile_pos : Vector2i) {
	data : *World_Eat_Cmd = xx (world_cmds.base + world_cmds.size);
	data.tile_pos = tile_pos;
	data.header.kind = .Eat;
	
	world_cmds.count += 1;
	world_cmds.size += size_of(World_Eat_Cmd);
}

push_world_test_interaction :: () {
	data : *World_Test_Interaction_Cmd = xx (world_cmds.base + world_cmds.size);
	data.header.kind = .Test_Interaction;
	world_cmds.count += 1;
	world_cmds.size += size_of(World_Test_Interaction_Cmd);
}

push_world_start_interaction :: (id : Interaction_Id) {
	data : *World_Start_Interaction_Cmd = xx (world_cmds.base + world_cmds.size);
	data.header.kind = .Start_Interaction;
	data.id = id;
	world_cmds.count += 1;
	world_cmds.size += size_of(World_Start_Interaction_Cmd);
}

push_world_complete_interaction :: (id : Interaction_Id) {
	data : *World_Complete_Interaction_Cmd = xx (world_cmds.base + world_cmds.size);
	data.header.kind = .Complete_Interaction;
	data.id = id;
	world_cmds.count += 1;
	world_cmds.size += size_of(World_Complete_Interaction_Cmd);
}

push_world_start_attack :: (entity : *Entity) {
	data : *World_Start_Attack_Cmd = xx (world_cmds.base + world_cmds.size);
	data.header.kind = .Start_Attack;
	data.entity = entity;
	world_cmds.count += 1;
	world_cmds.size += size_of(World_Start_Attack_Cmd);
}

Entity_Kind :: enum {
	Nothing;
	Opening;
	Player;
	Tree;
	Siren;
	Husk;
	Ball;
}

Entity_Flags :: enum_flags u64 {
	Control;
	Animated;
	Inactive;
	Interactable;
	Sloppy_Shadow;
	Chase_Entity;
}

Interaction_State :: enum {
	Cold;
	Hot;
	Active;
}

Chase_State :: enum {
	Cold;
	Hot;
	Active;
}

Animation_State :: enum {
	Idle;
	Move;
}

Attack_State :: enum {
	Cold;
	Active;
}

Animation :: struct {
	art : ArtId;
	frame_x : s32;
	frame_y : s32;
	speed : float32;
}

animations : [2]Animation : .[.{art = .Impolo, frame_x = 1, frame_y = 1, speed = 0},
															.{art = .Impolo_East, frame_x = 8, frame_y = 1, speed = 7}];

Entity :: struct {
	next : *Entity;
	name : string;
	type : Entity_Kind;
	flags : Entity_Flags;
	
	dir : Vector2i;
	speed : float32;
	size : Vector2i;
	
	test_pos : Vector2;
	
	pos : Vector2;
	tile_pos : Vector2i;
	origin : Vector2;
	
	target_entity : *Entity;
	chase_state : Chase_State;
	
	art_id : ArtId;
	frame_x : s32;
	frame_y : s32;
	frame_n : s32;
	flipped : bool;
	
	anim_state : Animation_State;
	anim_counter : float32;
	
	color : Vector4;
	interaction_state : Interaction_State;
	submerged : float;
	
	attack_state : Attack_State;
};

Entity_Store :: struct {
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

entity_store : Entity_Store;
world_initialized := false;
quest : Quest;

Interaction_Id :: enum {
	None;
	Tree;
	Siren;
	Opening;
};

interaction_id_from_entity :: (e : Entity) -> Interaction_Id{
	
	if e.type == {
		case .Tree; return .Tree;
		case .Siren; return .Siren;
		case .Opening; return .Opening;
	}
	
	return .None;
}

active_interatction : Interaction_Id;
active_entity : *Entity;

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
	
	editor_window_begin(world_window, events);
	
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
	editor_window_end(world_window);
	
	tick(events, passes, delta);
}

tm_index := Vector2i.{};
aos_tm_index := Vector2i.{3, 3};

tick :: (events : *os.EventList, passes : *r.Pass_List, delta : float32) {
	
	world_cmds.base = talloc(xx MB(1));
	world_cmds.count = 0;
	world_cmds.size = 0;
	world_cmds.cap = xx MB(1);
	
	quest_update(*demo_quest, events, passes);
	
	if py {
		tm_index = tilemap_index_from_tile_pos(py.tile_pos);
	}
	
	set_camera_pos(tm_index);
	
	world_tilemap := tilemap_from_key(*world_tileworld, tm_index);
	
	r.begin_water(passes);
	draw_tilemap(world_tileworld, world_tilemap, passes);
	
	generate_collisions(*world_tileworld, entity_store);
	draw_tilemap_collisions(world_tileworld, world_tilemap, passes);
	
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
			
			if mv.x || mv.y {
				entity.anim_state = .Move;
			} else {
				entity.anim_state = .Idle;
			}
			
			if mv.x < 0 {
				entity.flipped = xx 1;
			} else {
				entity.flipped = xx 0;
			}
			
			entity.test_pos = test_pos;
			
			if os.event(events, .E, .Pressed) {
				push_world_test_interaction();
			}
			
			if os.event(events, .LMB, .Pressed) {
				if entity.attack_state == .Cold {
					push_world_start_attack(entity);
				}
			}
		}
	}
	
	// pathfind
	
	for 0 .. entity_store.count - 1 {
		entity := entity_store.first + it;
		
		if entity.flags & .Inactive continue;
		
		if entity.flags & .Chase_Entity {
			
		}
		
	}
	
	// physics
	for 0 .. entity_store.count - 1 {
		entity := entity_store.first + it;
		
		if entity.flags & .Inactive continue;
		
		//valid := false;
		valid := true;
		
		test_tile_pos : Vector2i;
		test_tile_pos.x = cast(s32) entity.test_pos.x / 32;
		test_tile_pos.y = cast(s32) entity.test_pos.y / 32;
		
		// tilemap collision
#if 0 {
			for 0 .. 1 {
				
				tile := tile_from_index(world_tileworld, .{test_tile_pos.x, test_tile_pos.y, xx it});
				
				if tile.paint_index {
					valid = true;
				}
			}
		}
		
		// other entities
		
		tile := tile_from_index(world_tileworld, .{test_tile_pos.x, test_tile_pos.y}, .occupied);
		
		if tile {
			valid = !tile.entity;
			if tile.entity == entity {
				valid = true;
			}
		}
		
		// if valid, set new position. if not, slide
		
		if valid {
			entity.pos.x = entity.test_pos.x;
			entity.tile_pos.x = xx (entity.pos.x / 32.);
			
			entity.pos.y = entity.test_pos.y;
			entity.tile_pos.y = xx (entity.pos.y / 32.);
		} else {
			if entity.tile_pos.y != test_tile_pos.y {
				entity.pos.x = entity.test_pos.x;
				entity.tile_pos.x = xx (entity.pos.x / 32.);
			} else {
				entity.pos.y = entity.test_pos.y;
				entity.tile_pos.y = xx (entity.pos.y / 32.);
			}
		}
		
	}
	
	highlighted_entity : *Entity;
	
	// 
	for 0 .. entity_store.count - 1 {
		entity := entity_store.first + it;
		
		if entity.flags & .Inactive continue;
		
		if entity.flags & .Interactable {
			min_dist :: 2;
			if distance_squared(entity.tile_pos, py.tile_pos) < min_dist * min_dist {
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
			
			anim := animations[entity.anim_state];
			
			entity.anim_counter += xx delta;
			entity.frame_n = (xx (entity.anim_counter * anim.speed)) % anim.frame_x;
		}
	}
	
	// draw
	for 0 .. entity_store.count - 1 {
		entity := entity_store.first + it;
		if entity.flags & .Inactive continue;
		
		// draw occupied tile
		{
			dst := tile_rect_from_index(xx ((entity.tile_pos.x)), xx ((entity.tile_pos.y)));
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
		
		clear_collisions(*world_tileworld);
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
	
	r.push_beam(passes);
	intro_sort(entity_store.sort_list, sort_entitties);
	draw_submerged_entities(passes, -1);
	
	calculate_beam_pos :: () -> Vector2 {
		c := py.pos;//tm_index;
		t :: Vector2i.{10 * Tilemap.tile_size * Tilemap.col, 10 * Tilemap.tile_size * Tilemap.row};
		
		out : Vector2;
		
		out.x = (cast(float32)c.x) / t.x - 0.5;;
		out.y = (cast(float32)c.y) / t.y;
		
		return out;
	}
	
	beam_pos = calculate_beam_pos();
	//r.push_beam(passes);
	r.end_water(passes);
	
	draw_submerged_entities(passes, 1);
	
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
	
	if active_interatction == {
		case .Tree;
		if dialogue_box(passes, events, TREE_TALK) {
			push_world_complete_interaction(.Tree);
		}
		case .Siren;
		if dialogue_box(passes, events, SIREN_TALK) {
			push_world_complete_interaction(.Siren);
		}
		case .Opening;
		if dialogue_box(passes, events, OPENING_PROMPT) {
			push_world_complete_interaction(.Opening);
		}
	}
	
	base := world_cmds.base;
	i : s32;
	while i < world_cmds.count {
		defer i+=1;
		
		header :*World_Cmd_Kind = xx base;
		
		//print("%\n", i);
		
		if << header == {
			case .Eat;
			cmd : *World_Eat_Cmd = xx base;
			
			base += size_of(type_of(<< cmd));
			
			case .Test_Interaction;
			cmd : *World_Test_Interaction_Cmd = xx base;
			
			if highlighted_entity {
				highlighted_entity.interaction_state = .Active;
				active_entity = highlighted_entity;
				push_world_start_interaction(interaction_id_from_entity(active_entity));
			}
			
			base += size_of(type_of(<< cmd));
			
			case .Start_Interaction;
			cmd : *World_Start_Interaction_Cmd = xx base;
			py.flags &= ~.Control;
			print("started");
			active_interatction = cmd.id;
			
			base += size_of(type_of(<< cmd));
			
			case .Complete_Interaction;
			cmd : *World_Complete_Interaction_Cmd = xx base;
			py.flags |= .Control;
			
			if active_entity {
				active_entity.interaction_state = .Hot;
				active_entity = xx 0;
			}
			active_interatction = .None;
			
			base += size_of(type_of(<< cmd));
			
			case;
			assert(false, "cmd not found");
		}
	}
}


load_entities :: () {
	
	for *tm : world_tileworld.tilemaps {
		
		for y: 0 .. Tilemap.row - 1{
			for x: 0 .. Tilemap.col - 1 {
				
				tile := tile_from_local_index(tm, .{xx x, xx y}, .gfx);
				paint := paints[tile.v[2]];
				
				e : *Entity;
				
				if paint.entity_kind == {
					case .Player;
					e = entity_alloc(.Control | .Animated | .Sloppy_Shadow);
					e.speed = 200;
					e.type = .Player;
					e.submerged = 0.2;
					py = e;
					e.color = r.COLOR_WHITE;
					
					case .Tree;
					e = entity_alloc(.Interactable);
					e.type = .Tree;
					e.submerged = 0.28;
					e.color = r.COLOR_WHITE;
					e.frame_n = cast(s32) (random_get() % 3);
					
					case .Ball;
					e = entity_alloc(0);
					e.color = r.COLOR_WHITE;
					
					//array_add(*entity_store.apples, e);
					
					case .Siren;
					e = entity_alloc(.Interactable);
					e.type = .Siren;
					e.submerged = 0.08;
					e.color = r.COLOR_WHITE;
					
					case .Husk;
					e = entity_alloc(.Chase_Entity);
					e.type = .Husk;
					e.color = r.COLOR_BLACK;
					e.submerged = 0.08;
				}
				
				if e {
					e.name = paint.name;
					e.art_id = paint.art_id;
					e.origin = paint.origin;
					e.size = paint.size;
					e.frame_x = paint.frame_x;
					e.frame_y = paint.frame_y;
					
					if e.type != .Tree {
						e.frame_n = paint.frame_n;
					}
					e.test_pos = .{(x + tm.index.x * tm.col) * 32. + 16, (y + tm.index.y * tm.row) * 32. + 16};
					e.pos = e.test_pos;
					
					e.tile_pos.x = xx (e.pos.x / 32.);
					e.tile_pos.y = xx (e.pos.y / 32.);
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
		
		//print("%", OPENING_PROMPT);
		
		push_world_start_interaction(.Opening);
		
		// some cutscene. Very short. Just the explosion
		
		for 0 .. entity_store.count - 1 {
			entity := entity_store.first + it;
			
			if entity.flags & .Inactive continue;
			
			if entity.flags & .Chase_Entity {
				entity.target_entity = py;
				entity.chase_state = .Hot;
			}
			
		}
		
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
	
	continue_text :: "space ->";
	
	text_rect := r.get_text_rect(font, continue_text, camera.size, text_size);
	
	bottom_right := camera.size - .{padding, padding};
	bottom_right.x -= (text_rect.max.x - text_rect.min.x);
	bottom_right.y -= (text_rect.max.y - text_rect.min.y);
	
	r.push_text(passes, font, continue_text, bottom_right, text_size);
	
	if os.event(events, .SPACE, .Pressed) {
		out = true;
	}
	
	return out;
}

draw_submerged_entities :: (passes : *r.Pass_List, pass : s32) {
	
	for entity_store.sort_list {
		dst : RectF32;
		dst.min.x = it.pos.x - it.origin.x;
		dst.min.y = it.pos.y - it.origin.y;
		dst.max.x = dst.min.x + it.size.x;
		dst.max.y = dst.min.y + it.size.y;
		
		sprite := r.push_sprite(passes, dst, it.color);
		sprite.pad2[0] = xx pass;
		sprite.pad2[1] = it.submerged;
		
		if it.flags & .Animated {
			
			anim := animations[it.anim_state];
			sprite.tex_id = arts[anim.art].tex.U64[1];
			
			width := 1. / anim.frame_x;
			
			if it.flipped {
				width = -width;
			}
			
			sprite.src = rectF32(it.frame_n * width, 0, width * (it.frame_n + 1), 1);
		} else {
			sprite.tex_id = arts[it.art_id].tex.U64[1];
			width := 1. / it.frame_x;
			
			sprite.src = rectF32(it.frame_n * width, 0, width * (it.frame_n + 1), 1);
		}
	}
}

AStar :: struct {
	g : s32;
	h : s32;
	pos : Vector2i;
	unwalkable : bool;
}

fcost :: (n : AStar) -> s32 {
	return n.g + n.h;
}

astar_from_pos :: (tw : *Tileworld, pos : Vector2) -> AStar {
	out : AStar;
	
	tile_pos := index_from_coords(pos);
	out.pos = tile_pos;
	
	tile := tile_from_index(tw, tile_pos, .occupied);
	//out.unwalkable = xx tile.v[0];
	
	return out;
}

/*
find_path :: (tw : *Tileworld, start : Vector2, end : Vector2) -> []*Tile {
	
	start := tile_from_index(tw, );
	//start_node = 
}
*/