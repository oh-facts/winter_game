#import "mizu_base";
#import "Math";
#import "Basic";
#import "os/module";
#import "GL" (ENABLE_ALL_EXTENSIONS = true);

wc :: #import "Window_Creation";
input :: #import "Input";

Handle :: struct {
	U64 : [2]u64;
};

Event :: struct {
	prev : *Event;
	next : *Event;
	shift_held : bool;
	using base : input.Event;
}

EventList :: struct {
	first : *Event;
	last : *Event;
	count : u64;
};

Cursor_Mode :: enum {
	Arrow;
	Hand;
	COUNT;
};

push_event :: (list : *EventList) -> *Event {
	list.count+=1;
	
	out : *Event = talloc(size_of(Event));
	<< out = .{};
	
	if(!list.last) {
		list.first = out;
		list.last = out;
	} else {
		out.prev = list.last;
		list.last.next = out;
		list.last = out;
	}
	
	return out;
}

eat_event :: (list : *EventList, event : *Event) -> *Event {
	list.count -= 1;
	
	if(event.prev) {
		event.prev.next = event.next;
	}
	else {
		list.first = event.next;
	}
	
	if(event.next) {
		event.next.prev = event.prev;
	}
	else {
		list.last = event.prev;
	}
	
	return event;
}

quit_event :: (list : *EventList) -> bool {
	cur := list.first;
	out : bool;
	while cur {
		if cur.type == .QUIT {
			eat_event(list, cur);
			out = true;
			break;
		}
		cur = cur.next;
	}
	
	return out;
}

key_pressed :: (list : *EventList, key_code : input.Key_Code) -> *Event {
	out : *Event;
	cur := list.first;
	
	while cur {
		if cur.key_pressed && (cur.key_code == key_code) {
			out = eat_event(list, cur);
			break;
		}
		cur = cur.next;
	}
	
	return out;
}

key_released :: (list : *EventList, key_code : input.Key_Code) -> *Event {
	out : *Event;
	cur := list.first;
	
	while cur {
		if !cur.key_pressed && (cur.key_code == key_code) {
			out = eat_event(list, cur);
			break;
		}
		cur = cur.next;
	}
	
	return out;
}

scroll :: (list : *EventList) -> s32 {
	out : s32;
	cur := list.first;
	
	while cur {
		if cur.type == .MOUSE_WHEEL {
			out = eat_event(list, cur).wheel_delta;
			break;
		}
		cur = cur.next;
	}
	
	return out;
}

open_window :: (title : string, w : s32, h : s32) -> Handle {
	
	screenWidth := GetSystemMetrics(SM_CXSCREEN);
	screenHeight := GetSystemMetrics(SM_CYSCREEN);
	
	// Calculate the position to center the window
	x := (screenWidth - w) / 2;
	y := (screenHeight - h) / 2;
	
	the_window := wc.create_window(w, h, title, x, y);
	
	out : Handle;
	out.U64[0] = xx the_window;
	
	return out;
}

poll_events :: () -> EventList {
	out : EventList;
	
	input.update_window_events();
	
	for input.events_this_frame {
		event := push_event(*out);
		event.base = it;
	}
	
	return out;
}

get_window_size :: (win : Handle) -> Vector2 {
	out : Vector2;
	
	return out;
}

set_window_size :: (win : Handle, size : Vector2) {
	
}

set_window_pos :: (win : Handle, pos : Vector2) {
	
}

get_window_pos :: (win : Handle) -> Vector2 {
	out : Vector2;
	
	return out;
}

get_global_mouse_pos :: (win : Handle) -> Vector2 {
	out : Vector2;
	
	return out;
}

set_fullscreen :: (win : Handle, flag : bool) {
	
}

minimize_window :: (win : Handle) {
	
}

swap_buffers :: (win : Handle) {
	
}

set_cursor :: (mode : Cursor_Mode) {
	
}