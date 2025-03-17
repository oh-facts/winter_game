// main editor window
// option to edit levels
// option to play scenes
// scenes reference levels

// I think mimic trees will just have
// a demon shadow ??

// TODO(mizu): entity direction

// focus on entity when you double click

// TODO(mizu): Redo interaction system fully
// I want to interact with girl and see a box
// that asks what you want to do with her
// 

World_Cmd_Buffer :: struct {
	base : *u8;
	count : int;
	size : s64;
	cap : s64;
}

World_Cmd_Header :: struct {
	kind : Type;
	size : int;
}

World_Test_Interaction_Cmd :: struct {
	header : World_Cmd_Header;
	tile_pos : Vector2i;
}

World_Input_Interact_Cmd :: struct {
	header : World_Cmd_Header;
	tile_pos : Vector2i;
}

World_Start_Interaction_Cmd :: struct {
	header : World_Cmd_Header;
	e : *Entity;
}

World_Complete_Interaction_Cmd :: struct {
	header : World_Cmd_Header;
	e : *Entity;
}

world_cmds : World_Cmd_Buffer;

push_world_impl :: ($T : Type) -> *T {
	data : *T = xx (world_cmds.base + world_cmds.size);
	data.header.kind = T;
	data.header.size = size_of(T);
	
	world_cmds.count += 1;
	world_cmds.size += data.header.size;
	
	return data;
}

push_world_input_interact :: (tile_pos : Vector2i) {
	data := push_world_impl(World_Input_Interact_Cmd);
	data.tile_pos = tile_pos;
}

push_world_test_interaction :: (tile_pos : Vector2i) {
	data := push_world_impl(World_Test_Interaction_Cmd);
	data.tile_pos = tile_pos;
}

push_world_start_interaction :: (e : *Entity) {
	data := push_world_impl(World_Start_Interaction_Cmd);
	data.e = e;
}

push_world_complete_interaction :: (e : *Entity) {
	data := push_world_impl(World_Complete_Interaction_Cmd);
	data.e = e;
}

begin_world_cmd :: () {
	world_cmds.cap = xx MB(1);
	world_cmds.base = talloc(world_cmds.cap);
	world_cmds.size = 0;
	world_cmds.count = 0;
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
	Has_Quest;
}

Interaction_State :: enum {
	Cold;
	Hot;
	Active;
}

Animation_State :: enum {
	Idle;
	Move;
}

Animation :: struct {
	art_id : ArtId;
	speed : float32;
}

Animation_Node :: struct {
	using v : Animation;
	next : *Animation_Node;
	state : Animation_State;
	kind : Entity_Kind;
}

Animation_Slot :: struct {
	first : *Animation_Node;
	last : *Animation_Node;
}

Animation_Store :: struct {
	slots : []Animation_Slot;
}

Quest_Phase :: enum {
	AoS_Opening_Dialogue;
	AoS_Demo_Dialogue;
	AoS_Demo_Main;
}

Quest_Kind :: enum {
	Talk;
}

Quest_Status :: enum {
	Unassigned;
	Assigned;
	Completed;
}

Quest :: struct {
	kind : Quest_Kind;
	
	status : Quest_Status;
	phase : Quest_Phase;
	
	opening_dialogues : Dialogue_List;
	demo_dialogues : Dialogue_List;
	
	dialogue_phase : *Dialogue;
	dialogue_phase_index : int;
}

Dialogue_Flags :: enum_flags {
	Text;
	Option;
}

Dialogue :: struct {
	flags : Dialogue_Flags;
	next : *Dialogue;
	text : string;
	option : string;
}

Dialogue_List :: struct {
	first : *Dialogue;
	last : *Dialogue;
	count : int;
}

push_dialogue :: (list : *Dialogue_List) -> *Dialogue{
	out : *Dialogue = push_struct(arena, Dialogue);
	
	if !list.last {
		list.first = out;
		list.last = out;
	} else {
		list.last.next = out;
		list.last = out;
	}
	
	list.count += 1;
	
	return out;
}

push_dialogue_text :: (list : *Dialogue_List, text : string) {
	out := push_dialogue(list);
	out.flags = .Text;
	out.text = text;
}

push_dialogue_option :: (list : *Dialogue_List, option : string) {
	out := push_dialogue(list);
	out.flags = .Option;
	out.option = option;
}

// TODO(mizu): So I am thinking dialogues, interactions, fetch quests, fights, etc. are all  quests. The word quest isn't appropriate for this.

// But every quest has a quest kind that sets thigns up and optionally locks things if certain quests aren't completed.

// I will eventually make a fn ptr for this and use a void* data because I think this would have lots of different kinds of data

// Maybe not fn ptr but void * data certainly

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
	
	src : RectF32;
	art_id : ArtId;
	frame_n : s32;
	flipped : bool;
	
	anim_state : Animation_State;
	anim_counter : float32;
	
	color : Color;
	interaction_state : Interaction_State;
	submerged : float;
	
	auto : bool;
	
	editor_hover : bool;
	
	quest : *Quest;
};

Color :: Vector4;

Game :: struct {
	aos_quest : *Quest;
}

game : Game;

Entity_Store :: struct {
	arena : *Arena;
	first : *Entity;
	count : int;
	inactive_count : int;
	free : *Entity;
	
	// per frame
	sort_list : [..]*Entity;
}

entity_store : Entity_Store;
anim_store : Animation_Store;

active_count :: () -> int {
	return entity_store.count - entity_store.inactive_count;
}

world_initialized := false;

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

entity_store_init :: () -> Entity_Store {
	out : Entity_Store;
	
	out.arena = arena_init();
	out.first = push_struct(out.arena, void);
	
	return out;
}

hash_from_animation :: (state : Animation_State, kind : Entity_Kind) -> int {
	
	hash := 5381;
	
	hash = ((hash << 5) + hash) + xx state;
	hash = ((hash << 5) + hash) + xx kind;
	
	return hash;
}

register_animation :: (as : *Animation_Store, art_id : ArtId, state : Animation_State, kind : Entity_Kind, anim_speed := 0.) {
	
	node : *Animation_Node = xx push_struct(arena, Animation_Node);
	node.art_id = art_id;
	node.state = state;
	node.kind = kind;
	node.speed = anim_speed;
	hash := hash_from_animation(state, kind);
	
	slot_index := hash % xx as.slots.count;
	
	slot := as.slots.data + slot_index;
	
	if !slot.last {
		slot.first = node;
		slot.last = node;
	} else {
		slot.last.next = node;
		slot.last = node;
	}
	
}

get_animation :: (as : *Animation_Store, state : Animation_State, kind : Entity_Kind) -> Animation {
	
	out : Animation;
	hash := hash_from_animation(state, kind);
	slot_index := hash % xx as.slots.count;
	slot := as.slots.data + slot_index;
	{
		cur := slot.first;
		
		while cur {
			if cur.kind == kind && cur.state == state {
				out = cur.v;
			}
			cur = cur.next;
		}
	}
	
	return out;
}

animation_store_init :: () -> Animation_Store {
	out : Animation_Store;
	out.slots.count = 256;
	out.slots.data = push_array(arena, Animation_Slot, xx out.slots.count);
	
	register_animation(*out, .Impolo, .Idle, .Player);
	register_animation(*out, .Impolo_East, .Move, .Player, 7);
	
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
		
		// root
		{
			game.aos_quest = xx push_struct(arena, Quest);
			game.aos_quest.kind = .Talk;
		}
		
		// dialogue 1
		{
			d := *game.aos_quest.opening_dialogues;
			push_dialogue_text(d, AoS_Opening_0);
			push_dialogue_text(d, AoS_Opening_1);
			push_dialogue_text(d, AoS_Opening_2);
			push_dialogue_text(d, AoS_Opening_3);
			push_dialogue_text(d, AoS_Opening_4);
			push_dialogue_text(d, AoS_Opening_5);
			game.aos_quest.dialogue_phase = game.aos_quest.opening_dialogues.first;
		}
		
		// dialogue 2
		{
			d := *game.aos_quest.demo_dialogues;
			push_dialogue_option(d, AoS_Demo_0_Option_1);
			push_dialogue_text(d, AoS_Demo_1);
			push_dialogue_text(d, AoS_Demo_2);
			push_dialogue_option(d, AoS_Demo_3_Option_1);
			push_dialogue_text(d, AoS_Demo_4);
			push_dialogue_text(d, AoS_Demo_5);
		}
		
		for 0 .. entity_store.count - 1{
			e := entity_store.first + it;
			if e.kind == .Aos {
				e.quest = game.aos_quest;
				break;
			}
		}
		
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
	
	begin_world_cmd();
	
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
			
			if mv.x != 0 || mv.y != 0 {
				entity.dir.x = xx mv.x;
				entity.dir.y = xx mv.y;
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
			
			if entity.dir.x < 0 {
				entity.flipped = xx 1;
			} else {
				entity.flipped = xx 0;
			}
			
			entity.test_pos = test_pos;
			
			push_world_test_interaction(entity.tile_pos + entity.dir);
			
			if os.event(events, .E, .Pressed) {
				push_world_input_interact(entity.tile_pos + entity.dir);
			}
			
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
		
		tile,map := tile_from_index(tileworld, .{test_tile_pos.x, test_tile_pos.y}, .Occupied);
		
		if !map {
			valid = false;
		}
		
		if tile {
			valid = !tile.entity;
			if tile.entity == entity {
				valid = true;
			}
		}
		else {
			reer : int;
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
	
	// update animations
	for 0 .. entity_store.count - 1 {
		entity := entity_store.first + it;
		
		if entity.flags & .Inactive continue;
		
		if entity.flags & .Animated {
			
			anim := get_animation(*anim_store, entity.anim_state, entity.kind);
			
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
			/*
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
*/
			
			art_id : int;
			
			if entity.flags & .Animated {
				anim := get_animation(*anim_store, entity.anim_state, entity.kind);
				
				art_id = xx anim.art_id;
			} 
			scope := tex.scope_open();
			
			bmp := tex.handle_from_hash(scope, arts[art_id].hash);
			origin := arts[entity.art_id].origin;
			size : Vector2;
			size.x = xx bmp.U32[0] * 2.;
			size.y = xx bmp.U32[1] * 2.;
			
			dst : RectF32;
			dst.min.x = entity.pos.x - origin.x;
			dst.min.y = entity.pos.y - origin.y;
			dst.max.x = dst.min.x + size.x;
			dst.max.y = dst.min.y + size.y;
			
			shadow := r.push_sprite(passes, dst, .{0, 0, 0, 0.4});
			shadow.tex_id = bmp.U64[1];
			tex.scope_close(scope);
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
		
		if entity.interaction_state == {
			case .Hot;
			entity.interaction_state = .Cold;
			
			case .Active;
			quest := entity.quest;
			
			if quest.kind ==  {
				case .Talk;
				
				if quest.phase == {
					case .AoS_Opening_Dialogue;
					editor_dialogue_begin(events);
					
					editor_label(quest.dialogue_phase.text);
					
					editor_dialogue_end();
					
					if os.event(events, .E, .Pressed) {
						quest.dialogue_phase = quest.dialogue_phase.next;
						quest.dialogue_phase_index += 1;
					}
					
					if quest.dialogue_phase_index > quest.opening_dialogues.count - 1 {
						push_world_complete_interaction(entity);
						quest.dialogue_phase_index = 0;
						quest.dialogue_phase = quest.demo_dialogues.first;
						quest.phase = .AoS_Demo_Dialogue;
					}
					
					case .AoS_Demo_Dialogue;
					editor_dialogue_begin(events);
					
					if quest.dialogue_phase.flags & .Text {
						editor_label(quest.dialogue_phase.text);
					}
					
					if quest.dialogue_phase.flags & .Option {
						if editor_button(quest.dialogue_phase.option).active { 
							quest.dialogue_phase = quest.dialogue_phase.next;
							quest.dialogue_phase_index += 1;
						}
					}
					else if os.event(events, .E, .Pressed) {
						quest.dialogue_phase = quest.dialogue_phase.next;
						quest.dialogue_phase_index += 1;
					}
					
					editor_dialogue_end();
					
					if quest.dialogue_phase_index > quest.demo_dialogues.count - 1 {
						push_world_complete_interaction(entity);
						quest.phase = .AoS_Demo_Main;
						entity.flags &= ~.Interactable;
					}
				}
			}
		}
	}
	
	// process cmds
	{
		base := world_cmds.base;
		i : s32;
		
		while i < world_cmds.count {
			defer i+=1;
			
			header : *World_Cmd_Header = xx base;
			
			if header.kind == {
				
				case World_Test_Interaction_Cmd;
				cmd : *World_Test_Interaction_Cmd = xx base;
				
				tile := tile_from_index(tileworld, cmd.tile_pos, .Occupied);
				
				if tile && tile.entity {
					
					if tile.entity.flags & .Interactable {
						
						if tile.entity.interaction_state == .Cold {
							tile.entity.interaction_state = .Hot;
						}
						
					}
					
				}
				
				case World_Input_Interact_Cmd;
				cmd : *World_Input_Interact_Cmd = xx base;
				
				tile := tile_from_index(tileworld, cmd.tile_pos, .Occupied);
				
				if tile && tile.entity {
					
					if tile.entity.flags & .Interactable {
						
						if tile.entity.interaction_state == .Hot {
							push_world_start_interaction(tile.entity);
						}
						
					}
					
				}
				
				case World_Start_Interaction_Cmd;
				cmd : *World_Start_Interaction_Cmd = xx base;
				cmd.e.interaction_state = .Active;
				cmd.e.quest.status = .Assigned;
				
				py.flags &= ~.Control;
				
				case World_Complete_Interaction_Cmd;
				cmd : *World_Complete_Interaction_Cmd = xx base;
				cmd.e.quest.status = .Completed;
				cmd.e.interaction_state = .Hot;
				
				py.flags |= .Control;
			}
			
			base += header.size;
			
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
		e.frame_n = 1;
		e.flags |= .Interactable | .Has_Quest;
		e.submerged = 0.4;
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
			anim := get_animation(*anim_store, it.anim_state, it.kind);
			
			art_id = xx anim.art_id;
		} else {
			art_id = xx it.art_id;
		}
		
		bmp := tex.handle_from_hash(scope, arts[art_id].hash);
		
		size : Vector2;
		size.x = xx bmp.U32[0];
		size.y = xx bmp.U32[1];
		
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
			
			if it.flipped {
				width = -width;
			}
			
			sprite.tex_id = bmp.U64[1];
			
			sprite.src = rectF32(it.frame_n * width, 0, width * (it.frame_n + 1), 1);
		} else {
			
			sprite.tex_id = bmp.U64[1];
			
			sprite.src = rectF32(it.frame_n * width, 0, width * (it.frame_n + 1), 1);
		}
	}
	
	tex.scope_close(scope);
}

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

editor_dialogue_begin :: (events : *os.EventList) {
	editor_window_begin(dialogue_window, events);
	editor_push_file_id(dialogue_window, .Simulation);
	
	ui_push_size_node(ui_size_pct(1, 0), true);
	editor_row_begin();
	row_parent := editor_ui_cxt.parent_stack.top.v;
	row_parent.offset[0] = 10;
	
	ui_push_size_node(ui_size_pct(1, 0), true);
	editor_col_begin();
	
	ui_push_text_align_node(.Left);
	ui_push_size_x_node(ui_size_pct(0.2));
	ui_push_size_y_node(ui_size_px(32));
	
	editor_spacer(ui_size_px(10));
}

editor_dialogue_end :: () {
	editor_row_end();
	editor_row_end();
	ui_pop_text_align_node();
	ui_pop_size_node();
	
	editor_pop_file_id(dialogue_window);
	editor_window_end(dialogue_window);
}