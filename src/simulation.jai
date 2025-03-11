// main editor window
// option to edit levels
// option to play scenes
// scenes reference levels

// I think mimic trees will just have
// a demon shadow ??

// TODO(mizu): entity direction

// focus on entity when you double click

// TODO(mizu): Alloc entities, save them, quit, open, rename them, save them, quit, open. Entity names are shorter than they are supposed to be. I am guessing name.count isn't saved idk

World_Cmd_Kind :: enum {
	Null;
	Test_Interaction;
	Start_Interaction;
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

World_Cmd_Buffer :: struct {
	base : *u8;
	count : int;
	size : s64;
	cap : s64;
}

world_cmds : World_Cmd_Buffer;

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

Entity_Kind :: enum {
	Nothing;
	Opening;
	Player;
	Tree;
	Siren;
	Husk;
	Ball;
	Tower;
	Aos;
	Count;
}

Entity_Flags :: enum_flags u64 {
	Control;
	Animated;
	Inactive;
	Interactable;
	Sloppy_Shadow;
	Chase_Entity;
	Hostile;
	Dead;
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
	art_id : ArtId;
	speed : float32;
}

animations : [2]Animation : .[.{art_id = .Impolo, speed = 0},
															.{art_id = .Impolo_East, speed = 7}];

Entity :: struct {
	next : *Entity;
	name : string;
	kind : Entity_Kind;
	flags : Entity_Flags;
	
	dir : Vector2i;
	speed : float32;
	
	test_pos : Vector2;
	
	pos : Vector2;
	tile_pos : Vector2i;
	
	target_entity : *Entity;
	chase_state : Chase_State;
	
	src : RectF32;
	art_id : ArtId;
	frame_n : s32;
	flipped : bool;
	
	anim_state : Animation_State;
	anim_counter : float32;
	
	color : Color;
	interaction_state : Interaction_State;
	submerged : float;
	
	attack_state : Attack_State;
	
	auto : bool;
	
	editor_hover : bool;
};

Color :: Vector4;

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
	
	if e.kind == {
		case .Tree; return .Tree;
		case .Siren; return .Siren;
		case .Opening; return .Opening;
	}
	
	return .None;
}

active_interatction : Interaction_Id;
active_entity : *Entity;

entity_alloc :: (es : *Entity_Store) -> *Entity {
	out := es.free;
	
	if out {
		es.free = es.free.next;
		es.inactive_count -= 1;
	} else {
		out = push_struct(es.arena, Entity);
	}
	
	<< out = .{};
	
	es.count += 1;
	
	return out;
}

entity_free :: (es : *Entity_Store, entity : *Entity) {
	entity.next = es.free;
	es.free = entity;
	entity.flags |= .Inactive;
	es.inactive_count += 1;
}

entity_window : *Editor_Window;
world_window : *Editor_Window;

entity_store_init :: () -> Entity_Store {
	out : Entity_Store;
	
	out.arena = arena_init();
	out.first = push_struct(out.arena, void);
	
	return out;
}

// NOTE(mizu): Temp, for combat demo
py : *Entity;

Stage :: enum {
	Sim;
	Combat;
}

stage : Stage = .Sim;
//stage : Stage = .Combat;

world_update :: (delta : float32, events : *os.EventList,
								 passes : *r.Pass_List) {
	if !world_initialized {
		world_initialized = true;
		
		entity_window = editor_init_window("entity inspector");
		world_window = editor_init_window("world inspector");
	}
	
	for 0 .. entity_store.count - 1{
		e := entity_store.first + it;
		if e.kind == .Player {
			py = e;
			break;
		}
	}
	
	if stage == {
		case .Sim;
		tick(events, passes, delta);
		
		case .Combat;
		combat_stage(events, passes, delta);
	}
	
}

combat_stage :: (events : *os.EventList, passes : *r.Pass_List, delta : float32) {
	
	
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
	
	world_tilemap := tilemap_from_key(*tileworld, tm_index);
	
	r.begin_water(passes);
	draw_tilemap(tileworld, world_tilemap, passes);
	
	generate_collisions(*tileworld, entity_store);
	draw_tilemap_collisions(tileworld, world_tilemap, passes);
	
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
				
				tile := tile_from_index(tileworld, .{test_tile_pos.x, test_tile_pos.y, xx it});
				
				if tile.paint_index {
					valid = true;
				}
			}
		}
		
		// other entities
		
		tile := tile_from_index(tileworld, .{test_tile_pos.x, test_tile_pos.y}, .Occupied);
		
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
			
			frame_x := arts[anim.art_id].frame_x;
			
			entity.anim_counter += xx delta;
			entity.frame_n = (cast(s32)(entity.anim_counter * anim.speed)) % xx frame_x;
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
		
	}
	
	calculate_beam_pos :: () -> Vector2 {
		c := py.pos;//tm_index;
		t :: Vector2i.{10 * Tilemap.tile_size * Tilemap.col, 10 * Tilemap.tile_size * Tilemap.row};
		
		out : Vector2;
		
		out.x = (cast(float32)c.x) / t.x - 0.5;;
		out.y = (cast(float32)c.y) / t.y;
		
		return out;
	}
	
	beam_pos := calculate_beam_pos();
	
	r.push_beam(passes, beam_pos);
	intro_sort(entity_store.sort_list, sort_entitties);
	draw_submerged_entities(entity_store, passes, -1);
	
	//r.push_beam(passes);
	r.end_water(passes);
	
	draw_submerged_entities(entity_store, passes, 1);
	
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
	
	clear_collisions(*tileworld);
}

entity_init_from_kind :: (e : *Entity, kind : Entity_Kind, pos : Vector2) {
	e.kind = kind;
	
	if kind == {
		case .Player;
		e.flags |= .Control | .Animated | .Sloppy_Shadow;
		e.art_id = .Impolo;
		e.speed = 200;
		e.submerged = 0.3;
		e.color = r.COLOR_WHITE;
		
		case .Tree;
		e.flags |= .Interactable;
		e.art_id = .Tree;
		e.submerged = 0.28;
		e.color = r.COLOR_WHITE;
		e.frame_n = cast(s32) (random_get() % 3);
		
		case .Ball;
		e.art_id = .Ball;
		e.color = r.COLOR_WHITE;
		
		case .Siren;
		e.flags |= .Interactable;
		e.art_id = .Siren;
		e.submerged = 0.08;
		e.color = r.COLOR_WHITE;
		
		case .Husk;
		e.art_id = .Impolo;
		e.flags |= .Chase_Entity;
		e.color = r.COLOR_BLACK;
		e.submerged = 0.08;
		
		case .Aos;
		e.art_id = .Aos;
		e.color = r.COLOR_WHITE;
	}
	
	e.pos = pos;
	e.test_pos = pos;
	e.tile_pos.x = xx (pos.x / 32.);
	e.tile_pos.y = xx (pos.y / 32.);
}

entity_from_kind :: (es : *Entity_Store, kind : Entity_Kind, pos : Vector2) -> *Entity {
	
	out := entity_alloc(es);
	entity_init_from_kind(out, kind, pos);
	return out;
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

sort_entitties :: (a : *Entity, b : *Entity) -> int {
	pos_a := a.pos;
	pos_b := b.pos;
	
	out : int = 1;
	if pos_a.y < pos_b.y {
		out = -1;
	}
	
	return out;
}

// TODO(mizu): Needs cleanup

draw_submerged_entities :: (es : Entity_Store, passes : *r.Pass_List, pass : s32) {
	
	scope := tex.scope_open();
	
	for es.sort_list {
		
		origin := arts[it.art_id].origin;
		
		art_id : int;
		
		if it.flags & .Animated {
			anim := animations[it.anim_state];
			art_id = xx anim.art_id;
		} else {
			art_id = xx it.art_id;
		}
		
		bmp := tex.handle_from_hash(scope, arts[art_id].hash);
		
		size : Vector2;
		size.x = xx bmp.U32[0];
		size.y = xx bmp.U32[1];
		
		if it.art_id == .Aos {
			size.x /= 2;
			size.y /= 2;
		}
		
		frame_x := arts[art_id].frame_x;
		
		width := 1. / frame_x;
		
		size.x *= width;
		
		size.x *= 2;
		size.y *= 2;
		
		dst : RectF32;
		dst.min.x = it.pos.x - origin.x;
		dst.min.y = it.pos.y - origin.y;
		dst.max.x = dst.min.x + size.x;
		dst.max.y = dst.min.y + size.y;
		
		sprite := r.push_sprite(passes, dst, it.color);
		sprite.pad2[0] = xx pass;
		sprite.pad2[1] = it.submerged;
		
		if it.flags & .Animated {
			
			sprite.tex_id = bmp.U64[1];
			
			if it.flipped {
				width = -width;
			}
			
			sprite.src = rectF32(it.frame_n * width, 0, width * (it.frame_n + 1), 1);
		} else {
			
			sprite.tex_id = bmp.U64[1];
			
			sprite.src = rectF32(it.frame_n * width, 0, width * (it.frame_n + 1), 1);
		}
	}
	
	tex.scope_close(scope);
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
	
	tile := tile_from_index(tw, tile_pos, .Occupied);
	//out.unwalkable = xx tile.v[0];
	
	return out;
}

/*
find_path :: (tw : *Tileworld, start : Vector2, end : Vector2) -> []*Tile {

	start := tile_from_index(tw, );
	//start_node =
}
*/

/*
Entity save file

count
Entity array
name strings

*/

save_entities :: (es : Entity_Store) {
	filename := tprint("%/%", data_folder, "entity_data");
	
	save_arena := arena_init();
	data := push_array(save_arena, u8, 0);
	
	// count
	count : *int = xx push_struct(save_arena, int);
	<< count = es.count;
	
	// entities
	entities : *Entity = xx push_array(save_arena, Entity, xx es.count);
	memcpy(entities, es.first, size_of(Entity) * es.count);
	
	// strings
	
	for 0 .. es.count - 1 {
		src := es.first + it;
		dst := entities + it;
		push_array(save_arena, u8, xx 0);
		dst.name.data = xx (save_arena.used - ARENA_HEADER_SIZE);;
		name : *u8 = push_array(save_arena, u8, xx src.name.count);
		
		memcpy(name, src.name.data, src.name.count);
	}
	
	write_entire_file(filename, data, xx save_arena.used - ARENA_HEADER_SIZE);
	
	print("ended saving\n");
}

// TODO(mizu): I am thinking, this just creates a new one and returns and then you free the old one

load_entities :: (es : *Entity_Store) {
	filename := tprint("%/%", data_folder, "entity_data");
	
	file_data := read_entire_file(filename);
	
	es.arena.used = ARENA_HEADER_SIZE;
	es.first = push_array(es.arena, Entity, 0);
	es.count = 0;
	es.inactive_count = 0;
	es.free = xx 0;
	
	array_reset_keeping_memory(*es.sort_list);
	
	if file_data {
		head := file_data.data;
		
		count : int = << cast(*int) head;
		head += size_of(int);
		
		entities : *Entity = xx head;
		head += size_of(Entity) * count;
		
		es.first = push_array(es.arena, Entity, xx count);
		memcpy(es.first, entities, size_of(Entity) * count);
		es.count = count;
		
		for 0 .. es.count - 1 {
			src := entities + it;
			dst := es.first + it;
			
			name := alloc_string(src.name.count);
			
			offset :int= xx src.name.data;
			
			memcpy(name.data, file_data.data + offset, src.name.count);
			dst.name = name;
		}
		
		free (file_data);
	}
}