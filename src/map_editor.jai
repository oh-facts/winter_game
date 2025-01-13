text_size := 0.4;

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

editor_update :: (delta : float32, events : *os.EventList, 
									passes : *r.Pass_List) {
	
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
	draw_tilemap(editor_tileworld, editor_tilemap, passes);
	draw_entities(editor_tilemap, passes);
	
	if grid_toggle {
		draw_grid(passes);
		draw_outline(passes);
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
				tile_from_local_index(editor_tilemap, tile_pos).paint_index = xx active_paint_index;
			}
			// erase
			else if rmb_held{
				tile_from_local_index(editor_tilemap, tile_pos).paint_index = 0;
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
					
					r.push_rect2(passes, dst, r.COLOR_CYAN);
				}
				// selection ended
				else {
					//print("selection ended\n");
					
					selection_started = false;
					selection_yes = true;
					
					
					for y : tile_select_range.min.y .. tile_select_range.max.y {
						
						for x : tile_select_range.min.x .. tile_select_range.max.x {
							tile_from_local_index(editor_tilemap, .{xx x, xx y, xx tile_pos.z}).paint_index = xx active_paint_index;
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
							
							tile := tile_from_local_index(editor_tilemap, .{xx x, xx y, tile_pos.z});
							
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
					
					dst := tile_rect_from_index(it.pos + mv);
					r.push_rect2(passes, dst, r.COLOR_ORANGE);
				}
			}
			
			if moving_yes {
				mv := move_end - move_start;
				
				for *selection_buffer {
					tile1 := tile_from_local_index(editor_tilemap, it.pos);
					tile1.paint_index = 0;
					
					tile := tile_from_local_index(editor_tilemap, mv + it.pos);
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
					
					dst := tile_rect_from_index(it.pos);
					r.push_rect2(passes, dst, .{0, 0, 1, 0.3});
					
				}
				
				// delete selection
				if os.event(events, .DEL, .Pressed) {
					// empty buffer
					for selection_buffer {
						tile := tile_from_local_index(editor_tilemap, it.pos);
						tile.paint_index = 0;
					}
					
					array_reset_keeping_memory(*selection_buffer);
					selection_yes = false;
				}
			}
		}
		
		// preview tile pos
		r.push_rect2(passes, tile_rect_from_index(tile_pos), .{0, 0, 0, 1});
	}
	
	// @panel
	editor_window_begin(map_editor_window);
	
	if !map_editor_window.hide {
		text := tprint("%\nmpos: %\nwmpos:{% %}\ntpos:%", delta, mpos, cast(s32) wmpos.x, cast(s32) wmpos.y, tile_pos);
		
		editor_label(text);
		
		tool_id : [tools.count]ui.ID;
		
		operator == :: (a : ui.ID, b : ui.ID) -> bool {
			return (memcmp(*a, *b, size_of(ui.ID)) == 0);
		}
		
		for tools {
			text = tprint("%", it.name);
			
			signal := editor_label(text, it_index);
			tool_id[it_index] = signal.widget.key;
			if(signal.active) {
				active_tool_index = xx it_index;
			}
			
			if(active_tool_index == xx Tool_Kind.Paint && (signal.widget.key == tool_id[Tool_Kind.Paint])) {
				
				ui.push_padding_node(editor_ui_cxt, .{16, 0});
				defer ui.pop_padding_node(editor_ui_cxt);
				for 1 .. paints.count - 1{
					paint := paints[it];
					text = tprint("%", paint.name);
					
					if(editor_label(text, it).active) {
						active_paint_index = xx it;
					}
				}
			}
		}
		
		text = tprint("%", selection_buffer.count);
		editor_label(text);
		
		text = tprint("% %", move_start, move_end);
		editor_label(text);
		
		text = tprint("toggle grid");
		grid_toggle = !editor_label(text).toggle;
		
		text = tprint("save");
		if editor_label(text).active {
			save_tileworld(editor_tileworld);
		}
		
		text = tprint("load");
		if editor_label(text).active {
			load_tileworld(*editor_tileworld);
		}
		
		
		text = tprint("%", active_tilemap_index);
		editor_label(text);
	}
	editor_window_end(map_editor_window);
}