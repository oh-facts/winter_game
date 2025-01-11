// I don't have the energy to add text edit.
// Therefore, we will use pre-written names

//output_levels : [5]string : .[""];

Tool_Kind :: enum {
	Select;
	Paint;
	Move;
	Fill;
}

Tool :: struct {
	kind : Tool_Kind;
	name : string;
};

tools : [4]Tool : .[.{kind = .Select, name = "select"},
										.{kind = .Paint, name = "paint"},
										.{kind = .Move, name = "move"},
										.{kind = .Fill, name = "fill"}
										];

editor_tileworld : Tileworld;

tile_pos : Vector3i;

grid_toggle : bool = true;
active_tool_index := 0;
active_paint_index := 0;
active_entity_index := 0;

SelectionTile :: struct {
	tile : Tile;
	pos : Vector3i;
}

selection_started : bool;
selection_tile_start : Vector3i;
selection_tile_end : Vector3i;
selection_buffer : [..]SelectionTile;
selection_yes : bool;

move_start : Vector3i;
move_end : Vector3i;
moving_started := false;
moving_yes := false;
active_tilemap_index : Vector2i;

ed_initialized : bool;

map_editor_window : *Editor_Window;
editor_tilemap : *Tilemap;

editor_update :: (delta : float32, events : *os.EventList, sprite_batches : *r.BatchList, ui_batches : *r.BatchList) {
	
	if !ed_initialized {
		ed_initialized = true;
		
		// alloc tilemap memory
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
	draw_tilemap(editor_tilemap, sprite_batches);
	draw_entities(editor_tilemap, sprite_batches);
	
	if grid_toggle {
		draw_grid(ui_batches);
		draw_outline(ui_batches);
	}
	
	// TODO(mizu): i don't want events to be shared like this.
	
	if scroll_up {
		tile_pos.z += 1;
	}
	else if scroll_down {
		tile_pos.z -= 1;
	}
	
	tile_pos.z = clamp(tile_pos.z, 0, 2);
	
	// world space coords -> tile pos
	tile_pos.x = xx ((mpos.x) / Tilemap.tile_size);
	tile_pos.y = xx ((mpos.y) / Tilemap.tile_size);
	
	tilemap_in_focus := !any_editor_in_focus() && point_in_rect(mpos, Tilemap.rect);
	
	if tilemap_in_focus {
		
		tool := *tools[active_tool_index];
		
		if tool.kind == .Paint {
			
			// collect input events
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
			
			// paint
			if lmb_held {
				tile_from_index(editor_tilemap, tile_pos).paint_index = xx active_paint_index;
			}
			// erase
			else if rmb_held{
				tile_from_index(editor_tilemap, tile_pos).paint_index = 0;
			}
		}
		else if tool.kind == .Fill {
			
			// selection started
			if (lmb_held || rmb_held) && !selection_started {
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
				if (lmb_held || rmb_held) {
					//print("selectioning ...\n");
					
					selection_tile_end = tile_pos;
					
					// draw selection outline
					dst : RectF32;
					dst.min.x = tile_select_range.min.x * 32.;
					dst.min.y = tile_select_range.min.y * 32.;
					dst.max.x = (tile_select_range.max.x + 1) * 32.;
					dst.max.y = (tile_select_range.max.y + 1) * 32.;
					
					r.push_rect2(ui_batches, dst, r.COLOR_CYAN);
				}
				// selection ended
				else {
					//print("selection ended\n");
					
					selection_started = false;
					selection_yes = true;
					
					
					for y : tile_select_range.min.y .. tile_select_range.max.y {
						
						for x : tile_select_range.min.x .. tile_select_range.max.x {
							tile_from_index(editor_tilemap, x, y, tile_pos.z).paint_index = xx active_paint_index;
						}
					}
				}
			}
		}
		else if tool.kind == .Select {
			
			// selection started
			if lmb_held && !selection_started {
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
				if lmb_held {
					//print("selectioning ...\n");
					
					selection_tile_end = tile_pos;
					
					// draw selection outline
					dst : RectF32;
					dst.min.x = tile_select_range.min.x * 32.;
					dst.min.y = tile_select_range.min.y * 32.;
					dst.max.x = (tile_select_range.max.x + 1) * 32.;
					dst.max.y = (tile_select_range.max.y + 1) * 32.;
					
					r.push_rect2(ui_batches, dst, r.COLOR_CYAN);
				}
				// selection ended
				else {
					//print("selection ended\n");
					selection_started = false;
					selection_yes = true;
					
					// add valid tiles in the selection rect to the selection buffer 
					for y : tile_select_range.min.y .. tile_select_range.max.y {
						for x : tile_select_range.min.x .. tile_select_range.max.x {
							
							tile := tile_from_index(editor_tilemap, x, y, tile_pos.z);
							
							if tile.paint_index {
								select_tile : SelectionTile;
								select_tile.tile = << tile;
								select_tile.pos = .{x, y, tile_pos.z};
								
								array_add(*selection_buffer, select_tile);
							}
						}
					}
				}
			}
		}
		else if tool.kind == .Move {
			if lmb_down {
				move_start = tile_pos;
				moving_started = true;
			}
			
			if lmb_up {
				move_end = tile_pos;
				moving_yes = true;
				moving_started = false;
			}
			
			if moving_started {
				mv := tile_pos - move_start;
				
				for selection_buffer {
					
					dst := tile_rect_from_index(editor_tilemap, it.pos + mv);
					r.push_rect2(ui_batches, dst, r.COLOR_ORANGE);
				}
			}
			
			if moving_yes {
				mv := move_end - move_start;
				
				for *selection_buffer {
					tile1 := tile_from_index(editor_tilemap, it.pos);
					tile1.paint_index = 0;
					
					tile := tile_from_index(editor_tilemap, mv + it.pos);
					<< tile = it.tile;
					it.pos = mv + it.pos;
				}
				
				moving_yes = false;
			}
		}
		
		if (tool.kind == .Move) || (tool.kind == .Select) {
			if os.event(events, .RMB, .Pressed) || os.event(events, .LMB, .Pressed) {
				selection_yes = false;
				
				array_reset_keeping_memory(*selection_buffer);
			}
			
			// preview selection
			if selection_yes {
				
				for selection_buffer {
					
					dst := tile_rect_from_index(editor_tilemap, it.pos);
					r.push_rect2(ui_batches, dst, .{0, 0, 1, 0.3});
					
				}
				
				// delete selection
				if os.event(events, .DEL, .Pressed) {
					// empty buffer
					for selection_buffer {
						tile := tile_from_index(editor_tilemap, it.pos);
						tile.paint_index = 0;
					}
					
					array_reset_keeping_memory(*selection_buffer);
					selection_yes = false;
				}
			}
		}
		
		// preview tile pos
		r.push_rect2(ui_batches, tile_rect_from_index(editor_tilemap, tile_pos), .{0, 0, 0, 1});
	}
	
	// @panel
	editor_window_begin(ui_batches, map_editor_window);
	
	if !map_editor_window.hide {
		text := tprint("%\nmpos: %\nwmpos:{% %}\ntpos:%", delta, mpos, cast(s32) wmpos.x, cast(s32) wmpos.y, tile_pos);
		ui_label(.{0, 0, 0}, text);
		
		for tools {
			text = tprint("%", it.name);
			
			if(active_tool_index == xx it_index) {
				default_text_color = r.COLOR_ORANGE;
			}
			
			signal := ui_button(.{0, it_index, 1}, text);
			
			default_text_color = r.COLOR_WHITE;
			
			if(signal.active) {
				active_tool_index = xx it_index;
			}
			
			if(active_tool_index == xx Tool_Kind.Paint && (signal.id == .{0, xx Tool_Kind.Paint, 1})) {
				ui_begin_parent();
				for 1 .. paints.count - 1{
					paint := paints[it];
					text = tprint("%", paint.name);
					
					if(active_paint_index == xx it) {
						default_text_color = r.COLOR_ORANGE;
					}
					
					if(ui_button(.{0, it, 2}, text).active) {
						active_paint_index = xx it;
					}
					
					default_text_color = r.COLOR_WHITE;
					
				}
				ui_end_parent();
			}
		}
		
		text = tprint("%", selection_buffer.count);
		ui_label(.{0, 0, 3}, text);
		
		text = tprint("% %", move_start, move_end);
		ui_label(.{0, 0, 4}, text);
		
		text = tprint("toggle grid");
		
		grid_toggle = !ui_button(.{0, 0, 5}, text).toggle;
		
		text = tprint("save");
		if ui_button(.{0, 0, 8}, text).active {
			save_tileworld(editor_tileworld);
		}
		
		text = tprint("load");
		if ui_button(.{0, 0, 9}, text).active {
			load_tileworld(*editor_tileworld);
		}
		
		text = tprint("%", active_tilemap_index);
		ui_label(.{0, 0, 10}, text);
		
	}
}