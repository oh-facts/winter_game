// TODO(mizu): Get resizing to work properly, then continue with refactors
// first figure out why window size is wrong
// before that add the input module

#import "mizu_base";
#import "Math";
#import "Basic";
#import "os/module";
#import "GL" (ENABLE_ALL_EXTENSIONS = true);

#import "Window_Type";

wc :: #import "Window_Creation";
input :: #import "Input";

Handle :: struct {
	U64 : [2]u64;
};

Key :: enum {
	using input.Key_Code;
	
	NULL :: UNKNOWN;
	
	LMB :: MOUSE_BUTTON_LEFT; 
	RMB :: MOUSE_BUTTON_RIGHT; 
	MMB :: MOUSE_BUTTON_MIDDLE;
	
	LEFT :: ARROW_LEFT; 
	RIGHT :: ARROW_RIGHT; 
	UP :: ARROW_UP; 
	DOWN :: ARROW_DOWN;
	
	SPACE :: SPACEBAR;
	DEL :: DELETE;
	BACK :: BACKSPACE;
	
	ESC :: ESCAPE;
	
	A :: 65 ; 
	B; C; D; E;
	F; G; H; I; J;
	K; L; M; N; O;
	P; Q; R; S; T;
	U; V; W; X; Y;
	Z :: 90;
	
	_0 :: 48; 
	_1; _2; _3; _4;
	_5; _6; _7; _8; 
	_9 :: 57;
};

EventKind :: enum {
	NULL;
	Pressed;
	Released;
	MouseMove;
	Scroll;
	CloseRequested;
};

Event :: struct {
	next : *Event;
	prev : *Event;
	key : Key;
	kind : EventKind;
	wheel : int;
	text : bool;
	char : u8;
	shift_held : bool;
};

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

event :: (list : *EventList, key : Key, kind : EventKind) -> *Event {
	out : *Event;
	cur := list.first;
	while cur {
		if((cur.key == key) && (cur.kind == kind)) {
			out = eat_event(list, cur);
			if kind == .Pressed {
				a_ew2 := 3;
			}
			
			break;
		}
		cur = cur.next;
	}
	
	return out;
}

event_any_text :: (list : *EventList) -> *Event {
	out : *Event;
	cur := list.first;
	while cur {
		if (cur.kind == .Pressed) && (cur.text == true){
			out = eat_event(list, cur);
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
	
	gl_create_context(the_window, 4, 6);
	gl_load(*gl);
	
	return out;
}

poll_events :: () -> EventList {
	out : EventList;
	
	input.update_window_events();
	
	for input.events_this_frame {
		event := push_event(*out);
		event.key = xx it.key_code;
		
		if it.type == {
			case .KEYBOARD;
			if it.key_pressed {
				event.kind = .Pressed;
			} else {
				event.kind = .Released;
			}
			
			case .MOUSE_WHEEL;
			event.kind = .Scroll;
			
			case .QUIT;
			event.kind = .CloseRequested;
		}
		
		event.wheel = it.wheel_delta;
	}
	
	return out;
}

get_window_size :: (win : Handle) -> Vector2 {
	out : Vector2;
	rect : RECT;
	hwnd : HWND = xx win.U64[0];
	GetClientRect(hwnd, *rect);
	out.x = xx (rect.right - rect.left);
	out.y = xx (rect.bottom - rect.top);
	
	return out;
}

set_window_pos :: (win : Handle, pos : Vector2) {
	hwnd : HWND = xx win.U64[0];
	rect : RECT;
	size := get_window_size(win);
	SetWindowPos(hwnd, xx 0, xx pos.x, xx pos.y, xx size.x, xx size.y, SWP_NOZORDER);
}

get_window_pos :: (win : Handle) -> Vector2 {
	out : Vector2;
	rect : RECT;
	hwnd : HWND = xx win.U64[0];
	GetWindowRect(hwnd, *rect);
	out.x = xx (rect.left);
	out.y = xx (rect.top);
	
	return out;
}

get_global_mouse_pos :: (win : Handle) -> Vector2 {
	out : Vector2;
	
	pt : POINT;
	GetCursorPos(*pt);
	
	out.x = xx pt.x;
	out.y = xx pt.y;
	
	return out;
}

get_mouse_pos :: (win : Handle) -> Vector2 {
	out : Vector2;
	
	pt : POINT;
	GetCursorPos(*pt);
	hwnd : HWND = xx win.U64[0];
	
	ScreenToClient(hwnd, *pt);
	
	out.x = xx pt.x;
	out.y = xx pt.y;
	
	return out;
}

set_window_size :: (win : Handle, size : Vector2) {
	rect : RECT;
	hwnd : HWND = xx win.U64[0];
	
	GetWindowRect(hwnd, *rect);
	
	SetWindowPos(hwnd, xx 0, rect.left, rect.top, xx size.x, xx size.y, SWP_NOZORDER);
	// breaks because of the -9 +9 thing I did
	// Just include it as if it were part of your project and make it work like you want it to
	// 
}

set_maximized :: (win : Handle, flag : bool) {
	rect : RECT;
	hwnd : HWND = xx win.U64[0];
	input.is_f = flag;
	
	if flag {
		ShowWindow(hwnd, SW_MAXIMIZE);
	} else {
		ShowWindow(hwnd, SW_RESTORE);
	}
}

minimize_window :: (win : Handle) {
	hwnd : HWND = xx win.U64[0];
	
	ShowWindow(hwnd, SW_MINIMIZE);
}

swap_buffers :: (win : Handle) {
	hwnd : HWND  = xx win.U64[0];
	
	dc := GetDC(hwnd);
	SwapBuffers(dc);
}

set_cursor :: (mode : Cursor_Mode) {
	
}