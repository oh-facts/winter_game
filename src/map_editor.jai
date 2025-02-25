text_size := 0.4;

// I don't have the energy to add text edit.
// Therefore, we will use pre-written names

//output_levels : [5]string : .[""];

ME_Mode :: enum {
	Tile;
	Entity;
	Count;
}

Tool_Kind :: enum {
	Select;
	Paint;
	Move;
	Fill;
}

Tool_Kind2 :: enum {
	Select;
	Create;
	Move;
}

Tool :: struct {
	kind : Tool_Kind;
	name : string;
};

Tool2 :: struct {
	kind : Tool_Kind2;
	name : string;
};

tile_tools : [4]Tool : .[.{kind = .Select, name = "select"},
												 .{kind = .Paint, name = "paint"},
												 .{kind = .Move, name = "move"},
												 .{kind = .Fill, name = "fill"}
												 ];

entity_tools : [3]Tool2 : .[.{kind = .Select, name = "select"},
														.{kind = .Create, name = "create"},
														.{kind = .Move, name = "move"}
														];

editor_tileworld : Tileworld;
editor_entity_store : Entity_Store;

tile_pos : Vector2i;
paint_layer : int;

grid_toggle : bool = true;
active_tool_index := 0;
active_paint_index := 0;
active_entity_index := 0;
me_mode := ME_Mode.Tile;

SelectionTile :: struct {
	tile : Tile;
	pos : Vector2i;
	layer : int;
}

selection_started : bool;
selection_tile_start : Vector2i;
selection_tile_end : Vector2i;
selection_buffer : [..]SelectionTile;
selection_yes : bool;

move_start : Vector2i;
move_end : Vector2i;
moving_started := false;
moving_yes := false;
active_tilemap_index : Vector2i;
map_editor_lmb_held : bool;

ed_initialized : bool;

map_editor_window : *Editor_Window;
editor_tilemap : *Tilemap;

editor_update :: (delta : float32, events : *os.EventList, 
									passes : *r.Pass_List) {
	
	if !ed_initialized {
		ed_initialized = true;
		
		editor_entity_store = entity_store_init();
		editor_tileworld = init_tileworld();
		
		map_editor_window = editor_init_window("map editor");
		//editor_set_window_pos(map_editor_window, .{800, 0});
		load_tileworld(*editor_tileworld);
		//active_tilemap_index = Vector2i.{0, 10};
	}
	
	mv : Vector2i;
	if(os.event(events, .W, .Pressed))
	{
		mv.y -= 1;
	}
	
	if(os.event(events, .A, .Pressed))
	{
		mv.x -= 1;
	}
	if(os.event(events, .D, .Pressed))
	{
		mv.x += 1;
	}
	
	if(os.event(events, .S, .Pressed))
	{
		mv.y += 1;
	}
	
	set_camera_pos(active_tilemap_index);
	
	active_tilemap_index += mv;
	
	active_tilemap_index.x = max(active_tilemap_index.x, 0);
	active_tilemap_index.y = max(active_tilemap_index.y, 0);
	
	
	editor_tilemap = tilemap_from_key(*editor_tileworld, active_tilemap_index);
	
	// draw map
	draw_tilemap(editor_tileworld, editor_tilemap, passes);
	
	if grid_toggle {
		draw_grid(passes);
		draw_outline(passes);
	}
	
	// TODO(mizu): i don't want events to be shared like this.
	
	if scroll_up {
		paint_layer += 1;
	}
	else if scroll_down {
		paint_layer -= 1;
	}
	
	paint_layer = clamp(paint_layer, 0, 2);
	
	// world space coords -> tile pos
	tile_pos.x = xx ((mpos.x) / Tilemap.tile_size);
	tile_pos.y = xx ((mpos.y) / Tilemap.tile_size);
	
	tilemap_in_focus := !any_editor_in_focus() && point_in_rect(mpos, Tilemap.rect);
	
	if tilemap_in_focus {
		
		// collect input events
		
		lmbup_event := os.event(events, .LMB, .Released);
		lmbdown_event := os.event(events, .LMB, .Pressed);
		
		if lmbdown_event {
			map_editor_lmb_held = true;
		}
		
		if lmbup_event {
			map_editor_lmb_held = false;
		}
		
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
		
		if me_mode == .Tile {
			
			
			tool := *tile_tools[active_tool_index];
			
			if tool.kind == .Paint {
				// paint
				if map_editor_lmb_held {
					tile_from_local_index(editor_tilemap, tile_pos, .Gfx).v[paint_layer] = xx active_paint_index;
					
				}
				// erase
				else if rmb_held{
					tile_from_local_index(editor_tilemap, tile_pos, .Gfx).v[paint_layer] = 0;
				}
			}
			else if tool.kind == .Fill {
				
				// selection started
				if (map_editor_lmb_held || rmb_held) && !selection_started {
					selection_started = true;
					selection_tile_start = tile_pos;
				}
				
				if selection_started {
					tile_select_range : RectS32;
					
					// tile selection range
					tile_select_range.min.x = min(selection_tile_start.x, selection_tile_end.x);
					tile_select_range.min.y = min(selection_tile_start.y, selection_tile_end.y);
					
					tile_select_range.max.x = max(selection_tile_start.x, selection_tile_end.x);
					tile_select_range.max.y = max(selection_tile_start.y, selection_tile_end.y);
					
					// selection in progress
					if (map_editor_lmb_held || rmb_held) {
						//print("selectioning ...\n");
						
						selection_tile_end = tile_pos;
						
						// draw selection outline
						dst : RectF32;
						dst.min.x = tile_select_range.min.x * 32.;
						dst.min.y = tile_select_range.min.y * 32.;
						dst.max.x = (tile_select_range.max.x + 1) * 32.;
						dst.max.y = (tile_select_range.max.y + 1) * 32.;
						
						r.push_rect2(passes, dst, r.COLOR_CYAN);
					}
					// selection ended
					else {
						//print("selection ended\n");
						
						selection_started = false;
						selection_yes = true;
						
						
						for y : tile_select_range.min.y .. tile_select_range.max.y {
							
							for x : tile_select_range.min.x .. tile_select_range.max.x {
								tile_from_local_index(editor_tilemap, .{xx x, xx y}, .Gfx).v[paint_layer] = xx active_paint_index;
							}
						}
					}
				}
			}
			else if tool.kind == .Select {
				// selection started
				if map_editor_lmb_held && !selection_started {
					selection_started = true;
					selection_tile_start = tile_pos;
				}
				
				if selection_started {
					tile_select_range : RectS32;
					
					// tile selection range
					tile_select_range.min.x = min(selection_tile_start.x, selection_tile_end.x);
					tile_select_range.min.y = min(selection_tile_start.y, selection_tile_end.y);
					
					tile_select_range.max.x = max(selection_tile_start.x, selection_tile_end.x);
					tile_select_range.max.y = max(selection_tile_start.y, selection_tile_end.y);
					
					// selection in progress
					if map_editor_lmb_held {
						//print("selectioning ...\n");
						
						selection_tile_end = tile_pos;
						
						// draw selection outline
						dst : RectF32;
						dst.min.x = tile_select_range.min.x * 32.;
						dst.min.y = tile_select_range.min.y * 32.;
						dst.max.x = (tile_select_range.max.x + 1) * 32.;
						dst.max.y = (tile_select_range.max.y + 1) * 32.;
						
						r.push_rect2(passes, dst, r.COLOR_CYAN);
					}
					// selection ended
					else {
						//print("selection ended\n");
						selection_started = false;
						selection_yes = true;
						
						// add valid tiles in the selection rect to the selection buffer 
						for y : tile_select_range.min.y .. tile_select_range.max.y {
							for x : tile_select_range.min.x .. tile_select_range.max.x {
								
								tile := tile_from_local_index(editor_tilemap, .{xx x, xx y}, .Gfx);
								
								if tile.v[paint_layer] {
									select_tile : SelectionTile;
									select_tile.tile = << tile;
									select_tile.pos = .{x, y};
									select_tile.layer = paint_layer;
									
									array_add(*selection_buffer, select_tile);
								}
							}
						}
					}
				}
			}
			else if tool.kind == .Move {
				if lmbdown_event {
					move_start = tile_pos;
					moving_started = true;
				}
				
				if lmbup_event {
					move_end = tile_pos;
					moving_yes = true;
					moving_started = false;
				}
				
				if moving_started {
					mv := tile_pos - move_start;
					
					for selection_buffer {
						
						dst := tile_rect_from_index(it.pos + mv);
						r.push_rect2(passes, dst, r.COLOR_ORANGE);
					}
				}
				
				if moving_yes {
					mv := move_end - move_start;
					
					for *selection_buffer {
						tile1 := tile_from_local_index(editor_tilemap, it.pos, .Gfx);
						tile1.v[it.layer] = 0;
						
						tile := tile_from_local_index(editor_tilemap, mv + it.pos, .Gfx);
						<< tile = it.tile;
						it.pos = mv + it.pos;
					}
					
					moving_yes = false;
				}
			}
			
			if (tool.kind == .Move) || (tool.kind == .Select) {
				if rmbdown_event {
					selection_yes = false;
					
					array_reset_keeping_memory(*selection_buffer);
				}
				
				// preview selection
				if selection_yes {
					
					for selection_buffer {
						
						dst := tile_rect_from_index(it.pos);
						r.push_rect2(passes, dst, .{0, 0, 1, 0.3});
						
					}
					
					// delete selection
					if os.event(events, .DEL, .Pressed) {
						// empty buffer
						for selection_buffer {
							tile := tile_from_local_index(editor_tilemap, it.pos, .Gfx);
							tile.v[it.layer] = 0;
						}
						
						array_reset_keeping_memory(*selection_buffer);
						selection_yes = false;
					}
				}
			}
			
			// preview tile pos
			r.push_rect2(passes, tile_rect_from_index(tile_pos), .{0, 0, 0, 1});
		}
		else if me_mode == .Entity {
			
			if lmbdown_event {
				entity_from_kind(*editor_entity_store, xx active_entity_index, wmpos);
			}
			
		}
	} 
	
	// @draw entities
	for 0 .. editor_entity_store.count - 1 {
		entity := editor_entity_store.first + it;
		
		array_add(*editor_entity_store.sort_list, entity);
	}
	
	intro_sort(editor_entity_store.sort_list, sort_entitties);
	
	draw_submerged_entities(editor_entity_store, passes, -1);
	draw_submerged_entities(editor_entity_store, passes, 1);
	array_reset_keeping_memory(*editor_entity_store.sort_list);
	
	// @panel
	editor_window_begin(map_editor_window, events);
	editor_push_file_id(map_editor_window, .Map_Editor);
	
	if !map_editor_window.hide {
		ui_push_size_x_node(ui_size_pct(0.4, 0));
		ui_push_size_y_node(ui_size_px(24, 1));
		ui_push_text_align_node(.Left);
		text := tprint("mpos %", mpos);
		editor_label(text);
		
		text = tprint("wmpos %", wmpos);
		editor_label(text);
		
		text = tprint("tile_pos %", tile_pos);
		editor_label(text);
		
		text = tprint("tilemap %", active_tilemap_index);
		editor_label(text);
		ui_pop_text_align_node();
		
		ui_push_size_x_node(ui_size_pct(1, 0));
		ui_push_size_y_node(ui_size_px(24, 1));
		
		editor_row_begin();
		ui_pop_size_node();
		
		ui_push_size_x_node(ui_size_pct(1, 0));
		ui_push_size_y_node(ui_size_px(24, 1));
		
		if editor_button("Entity").active {
			me_mode = .Entity;
		}
		
		if editor_button("Tile").active {
			me_mode = .Tile;
		}
		
		ui_pop_size_node();
		editor_row_end();
		
		if me_mode == .Tile {
			
			ui_push_size_node(ui_size_children_sum(1));
			editor_row_begin();
			ui_pop_size_node();
			
			ui_push_size_x_node(ui_size_px(256, 0));
			ui_push_size_y_node(ui_size_px(24, 1));
			
			for tile_tools {
				text = tprint("%", it.name);
				if editor_button(text, it_index).active {
					active_tool_index = xx it_index;
				}
			}
			
			ui_pop_size_node();
			
			editor_row_end();
			
			if active_tool_index == xx Tool_Kind.Paint {
				ui_push_size_node(ui_size_children_sum(1));
				editor_row_begin();
				ui_pop_size_node();
				
				ui_push_size_x_node(ui_size_px(256, 0));
				ui_push_size_y_node(ui_size_px(24, 1));
				
				for paints {
					text = tprint("%", it.name);
					if editor_button(text, it_index).active {
						active_paint_index = it_index;
					}
				}
				
				ui_pop_size_node();
				
				editor_row_end();
			}
			
			
		} else if me_mode == .Entity {
			for 0 .. Entity_Kind.Count {
				text = tprint("%", it);
				if editor_button(text, xx it).active {
					active_entity_index = xx it;
				}
			}
		}
		ui_pop_size_node();
	}
	
	editor_pop_file_id(map_editor_window);
	editor_window_end(map_editor_window);
}