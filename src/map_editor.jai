text_size := 0.4;

// I don't have the energy to add text edit.
// Therefore, we will use pre-written names

//output_levels : [5]string : .[""];

ME_Mode :: enum {
	Tile;
	Entity;
	Count;
}

ME_Tool_Kind :: enum {
	Select;
	Paint;
	Move;
	Fill;
	Create;
	Inspect;
}

SelectionTile :: struct {
	tile : Tile;
	pos : Vector2i;
	layer : int;
}

ME_Tool :: struct {
	kind : ME_Tool_Kind;
	filter : ME_Mode;
	entity_kind : Entity_Kind;
	paint_index : s32;
	
	// used by selection and moving
	started : bool;
	start : Vector2i;
	end : Vector2i;
	buffer : [..]SelectionTile;
	in_progress : bool;
};

// which layer to modify
paint_layer : int;

me_tools : [6]ME_Tool : .[.{kind = .Select, filter = .Tile},
													.{kind = .Paint, filter = .Tile},
													.{kind = .Move, filter = .Tile},
													.{kind = .Fill, filter = .Tile},
													.{kind = .Create, filter = .Entity},
													.{kind = .Inspect, filter = .Entity},
													];

editor_tileworld : Tileworld;
editor_entity_store : Entity_Store;

tile_pos : Vector2i;

grid_toggle : bool = true;
active_tool_index := 0;

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
	
	tool := *me_tools[active_tool_index];
	
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
		
		if tool.filter  == .Tile {
			
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
	
	ui_push_size_node(ui_size_pct(1, 0));
	editor_col_begin();
	ui_pop_size_node();
	
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
		
		editor_spacer(ui_size_px(8));
		
		if editor_button("save").active {
			save_tileworld(editor_tileworld);
		}
		
		if editor_button("load").active {
			load_tileworld(*editor_tileworld);
		}
		
		editor_spacer(ui_size_px(8));
		
		ui_push_size_x_node(ui_size_pct(1, 0));
		ui_push_size_y_node(ui_size_px(24, 1));
		
		editor_row_begin();
		ui_pop_size_node();
		
		ui_push_size_x_node(ui_size_pct(1, 0));
		ui_push_size_y_node(ui_size_px(24, 1));
		
		for 0 .. ME_Mode.Count - 1 {
			if tool.filter == it {
				ui_push_border_color_node(r.COLOR_ORANGE, true);
			}
			text = tprint("%", it); 
			if editor_button(text, xx it).active {
				me_mode = it;
			}
		}
		
		ui_pop_size_node();
		editor_row_end();
		
		if me_mode == .Tile {
			
			ui_push_size_x_node(ui_size_pct(1, 0), true);
			ui_push_size_y_node(ui_size_px(24, 1), true);
			
			editor_row_begin();
			
			ui_push_size_x_node(ui_size_pct(1, 0));
			ui_push_size_y_node(ui_size_px(24, 1));
			
			for tile_tools {
				text = tprint("%", it.name);
				
				if it_index == active_tool_index {
					ui_push_border_color_node(r.COLOR_ORANGE, true);
				}
				
				if editor_button(text, it_index).active {
					active_tool_index = xx it_index;
				}
				
			}
			
			ui_pop_size_node();
			editor_row_end();
			
			if active_tool_index == xx Tool_Kind.Paint {
				ui_push_size_node(ui_size_children_sum(1), true);
				editor_row_begin();
				
				ui_push_size_x_node(ui_size_px(256, 0));
				ui_push_size_y_node(ui_size_px(24, 1));
				
				for paints {
					text = tprint("%", it.name);
					
					if it_index == active_paint_index {
						ui_push_border_color_node(r.COLOR_ORANGE, true);
					}
					
					if editor_button(text, it_index).active {
						active_paint_index = it_index;
					}
				}
				
				ui_pop_size_node();
				editor_row_end();
			}
			
		} else if me_mode == .Entity {
			
			ui_push_size_x_node(ui_size_pct(1, 0), true);
			ui_push_size_y_node(ui_size_px(24, 1), true);
			
			editor_row_begin();
			
			ui_push_size_x_node(ui_size_pct(1, 0));
			ui_push_size_y_node(ui_size_px(24, 1));
			
			for entity_tools {
				text = tprint("%", it.name);
				
				if it_index == active_entity_tool_index {
					ui_push_border_color_node(r.COLOR_ORANGE, true);
				}
				
				if editor_button(text, xx it_index).active {
					active_entity_tool_index = xx it_index;
				}
				
			}
			
			ui_pop_size_node();
			editor_row_end();
			
			if active_entity_tool_index == xx Entity_Tool_Kind.Create {
				
				ui_push_size_node(ui_size_children_sum(1), true);
				editor_row_begin();
				
				ui_push_size_x_node(ui_size_px(256, 0));
				ui_push_size_y_node(ui_size_px(24, 1));
				
				for 0 .. Entity_Kind.Count - 1 {
					text = tprint("%", it);
					
					if it == xx active_entity_index {
						ui_push_border_color_node(r.COLOR_ORANGE, true);
					}
					
					if editor_button(text, xx it).active {
						active_entity_index = xx it;
					}
				}
				
				ui_pop_size_node();
				editor_row_end();
			}
		}
		
		ui_pop_size_node();
	}
	
	editor_row_end();
	
	editor_pop_file_id(map_editor_window);
	editor_window_end(map_editor_window);
}