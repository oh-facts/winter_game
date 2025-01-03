UI_ID :: struct {
	owner : int;
	index : int;
	item: int;
};

operator == :: (a : UI_ID, b : UI_ID) -> bool{
	out : bool;
	if (a.owner == b.owner) && (a.index == b.index) && (a.item == b.item){
		out = true;
	}
	return out;
}

UI_Var :: struct {
	hash_next : *UI_Var;
	id : UI_ID;
	toggle : bool;
}

UI_Var_Slot :: struct {
	first : *UI_Var;
	last: *UI_Var;
};

UI_Var_Cache :: struct {
	num_slots :: 100;
	slots : [num_slots]UI_Var_Slot;
};

push_ui_var :: () -> *UI_Var {
	out := push_struct(ed_arena, UI_Var);
	return out;
}

// TODO(mizu): better hash func
ui_lookup_var :: (id : UI_ID) -> * UI_Var{
	index := ((id.owner << 1) + (id.index << 1) + (id.item << 1)) % ui_cxt.cache.num_slots;
	
	slot := *ui_cxt.cache.slots[index];
	out := slot.first;
	
	if out {
		while true {
			if out.id == id {
				break;
			}
			
			out = out.hash_next;
			if !out break;
		}
	}
	
	// allocate 
	if !out {
		out = push_ui_var();
		
		if slot.last {
			slot.last.hash_next = out;
			slot.last = out;
		}
		else {
			slot.first = out;
			slot.last = out;
		}
		
	}
	
	out.id = id;
	
	return out;
}

UI_Signal :: struct {
	hot : bool;
	active : bool;
	id : UI_ID;
	toggle : bool;
};

ui_cxt : struct {
	hot : UI_ID = .{-1, -1, -1};
	active : UI_ID = .{-1, -1, -1};
	text_pos : Vector2;
	ext : RectF32;
	batches : *r.BatchList;
	mouse_up : bool;
	mouse_down : bool;
	arena : *Arena;
	x_layout :: 10;
	cache : UI_Var_Cache;
	rect_max : Vector2;
};

ui_begin :: (batches : *r.BatchList, mouse_down : bool, mouse_up : bool) {
	ui_cxt.text_pos = .{};
	ui_cxt.ext = .{};
	ui_cxt.batches = batches;
	ui_cxt.mouse_down = mouse_down;
	ui_cxt.mouse_up = mouse_up;
	ui_cxt.hot = .{-1, -1, -1};
	default_text_color = Vector4.{1, 1, 1, 1};
	ui_rect : RectF32;
	ui_rect.max = ui_cxt.rect_max;
	r.push_rect2(batches, ui_rect, .{0, 0, 0, 0.9});
	ui_cxt.rect_max = .{};
}

ui_begin_parent :: () {
	ui_cxt.text_pos.x += ui_cxt.x_layout;
}

ui_end_parent :: () {
	ui_cxt.text_pos.x -= ui_cxt.x_layout;
}

ui_label :: (id : UI_ID, text : string, text_size := 0.4) -> UI_Signal {
	out : UI_Signal;
	out.id = id;
	text_color := default_text_color;
	
	ui_cxt.ext = r.get_text_rect(font, text, ui_cxt.text_pos, text_size);
	
	var := ui_lookup_var(id);
	out.toggle = var.toggle;
	inside := point_in_rect(mpos, ui_cxt.ext);
	
	if inside {
		ui_cxt.hot = id;
		out.hot = true;
	}
	
	if id == ui_cxt.active {
		text_color = active_text_color;
		if ui_cxt.mouse_up {
			if id == ui_cxt.hot {
				out.active = true;
				var.toggle = !var.toggle;
			}
			ui_cxt.active = .{-1, -1, -1};
		}
	}
	else if id == ui_cxt.hot {
		if ui_cxt.mouse_down {
			ui_cxt.active = id;
		}
		
		if ui_cxt.active == .{-1, -1, -1} {
			text_color = hot_text_color;
		}
	}
	
	if ui_cxt.ext.max.x > ui_cxt.rect_max.x {
		ui_cxt.rect_max.x = ui_cxt.ext.max.x;
	}
	
	if ui_cxt.ext.max.y > ui_cxt.rect_max.y {
		ui_cxt.rect_max.y = ui_cxt.ext.max.y;
	}
	
	r.push_text(ui_cxt.batches, font, text, ui_cxt.text_pos, text_size, text_color);
	
	ui_cxt.text_pos.y = ui_cxt.ext.max.y;
	
	return out;
}

ui_panel_in_focus :: () -> bool {
	ui_rect : RectF32;
	ui_rect.max = ui_cxt.rect_max;
	return point_in_rect(mpos, ui_rect);
}