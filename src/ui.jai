// TODO(mizu): I am thinking ui layer has keys instead of ids.
// the editor layer can make use of owner, index, item, window id, etc. to make produce different keys. The question is, how do i resolve collisions? Since the ui layer wont know how the keys are produced? A) callback to resolve collisions. B) opaque ids?
// so UI_ID becomes u32[6] for eg. and high level layers can adjust as they see fit. I like this idea more.

text_size := 0.4;

UI_WidgetFlags :: enum_flags u64 {
	Click;
}

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

UI_Widget :: struct {
	hash_next : *UI_Widget;
	id : UI_ID;
	toggle : bool;
}

UI_Widget_Slot :: struct {
	first : *UI_Widget;
	last: *UI_Widget;
};

UI_Widget_Cache :: struct {
	num_slots :: 100;
	slots : [num_slots]UI_Widget_Slot;
};

push_ui_var :: () -> *UI_Widget {
	out := push_struct(arena, UI_Widget);
	return out;
}

// TODO(mizu): better hash func
ui_lookup_var :: (id : UI_ID) -> * UI_Widget{
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

UI_Axis :: enum {
	Y;
	X;
}

UI_Layout :: struct {
	text_pos : Vector2;
	origin : Vector2;
	rect_max : Vector2;
	axis : UI_Axis; 
};

ui_cxt : struct {
	hot : UI_ID = .{-1, -1, -1};
	active : UI_ID = .{-1, -1, -1};
	batches : *r.BatchList;
	mouse_up : bool;
	mouse_down : bool;
	x_layout :: 10;
	cache : UI_Widget_Cache;
	
	using layout : *UI_Layout;
};

ui_select_layout :: (layout : *UI_Layout) {
	ui_cxt.layout = layout;
}

ui_begin :: (batches : *r.BatchList, mouse_down : bool, mouse_up : bool) {
	
	ui_cxt.batches = batches;
	ui_cxt.mouse_down = mouse_down;
	ui_cxt.mouse_up = mouse_up;
	ui_cxt.hot = .{-1, -1, -1};
	default_text_color = Vector4.{1, 1, 1, 1};
}

ui_begin_parent :: () {
	ui_cxt.text_pos.x += ui_cxt.x_layout;
}

ui_end_parent :: () {
	ui_cxt.text_pos.x -= ui_cxt.x_layout;
}

ui_label :: (id : UI_ID, text : string) -> UI_Signal {
	return ui_impl(id, text, 0);
}

ui_button :: (id : UI_ID, text : string) -> UI_Signal {
	return ui_impl(id, text, .Click);
}

ui_impl :: (id : UI_ID, text : string, flags : UI_WidgetFlags) -> UI_Signal {
	out : UI_Signal;
	out.id = id;
	text_color := default_text_color;
	
	ext := r.get_text_rect(font, text, ui_cxt.text_pos, text_size);
	ext.max += .{32, 16};
	
	var := ui_lookup_var(id);
	out.toggle = var.toggle;
	inside := point_in_rect(mpos, ext);
	
	if flags & .Click {
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
	}
	
	if ext.max.x > ui_cxt.rect_max.x {
		ui_cxt.rect_max.x = ext.max.x;
	}
	
	if ext.max.y > ui_cxt.rect_max.y {
		ui_cxt.rect_max.y = ext.max.y;
	}
	
	text_pos := ui_cxt.text_pos;
	text_pos.y += 8;
	
	if flags & .Click {
		bg := r.push_rect2(ui_cxt.batches, ext, .{});
		bg.border_color = r.COLOR_WHITE;
		bg.radius = 4;
		bg.border_thickness = 2;
		text_pos.x += 16;
	}
	
	r.push_text(ui_cxt.batches, font, text, text_pos, text_size, text_color);
	
	
	if ui_cxt.axis == {
		case .X;
		ui_cxt.text_pos.x = ext.max.x;
		case .Y;
		ui_cxt.text_pos.y = ext.max.y;
	}
	
	return out;
}
