#import "SDL";
#import "mizu_base";
#import "Math";
#import "Basic";
#import "os/module";

Handle :: struct {
	U64 : [2]u64;
};

Key :: enum {
	NULL;
	
	F1; F2; F3; F4; F5; 
	F6; F7; F8; F9; F10;
	F11; F12;
	
	A; B; C; D; E;
	F; G; H; I; J;
	K; L; M; N; O;
	P; Q; R; S; T;
	U; V; W; X; Y;
	Z;
	
	_0; _1; _2; _3; _4; 
	_5; _6; _7; _8; _9;
	
	LCTRL; RCTRL; 
	LSHIFT; RSHIFT;
	LALT; RALT;
	
	LMB; RMB; MMB;
	
	LEFT; RIGHT; UP; DOWN;
	
	TAB;
	CAPS;
	ENTER;
	SPACE;
	
	ESC;
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
	win : Handle;
	mpos : Vector2;
	wheel : int;
};

EventList :: struct {
	first : *Event;
	last : *Event;
	count : u64;
};

CursorMode :: enum {
	Normal;
	Disabled;
};

push_event :: (list : *EventList) -> *Event {
	list.count+=1;
	
	out : *Event = talloc(size_of(Event));
	<< out = .{};
	
	if(!list.last) {
		list.first = out;
		list.last = out;
	}
	else {
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
			break;
		}
		cur = cur.next;
	}
	
	return out;
}

init :: () {
	SDL_Init(SDL_INIT_VIDEO);
	
#if OS == .WINDOWS {
		Windows :: #import "Windows";
		Windows.SetProcessDPIAware();
	}
}

// NOTE(mizu): Will probably fail if string isn't a literal

open_window :: (title : string, w : s32, h : s32) -> Handle {
	out : Handle;
	
	sdl_win := SDL_CreateWindow(title.data, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, w, h, SDL_WINDOW_SHOWN | SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);
	glContext := SDL_GL_CreateContext(sdl_win);
	out.U64[0] = xx sdl_win;
	out.U64[1] = xx glContext;
	
	return out;
}

poll_events :: () -> EventList {
	out : EventList;
	
	sdl_event : SDL_Event;
	
	while SDL_PollEvent(*sdl_event) {
		if sdl_event.type == {
			case SDL_QUIT;
			event := push_event(*out);
			event.kind = .CloseRequested;
			event.key = .NULL;
			
			case SDL_KEYDOWN;
			if sdl_event.key.repeat == 0 {
				event := push_event(*out);
				event.kind = .Pressed;
				event.key = key_from_sym(xx sdl_event.key.keysym.sym);
			}
			
			case SDL_KEYUP;
			event := push_event(*out);
			event.kind = .Released;
			event.key = key_from_sym(xx sdl_event.key.keysym.sym);
			
			case SDL_MOUSEBUTTONDOWN;
			event := push_event(*out);
			event.kind = .Pressed;
			event.key = key_from_sym(xx sdl_event.button.button);
			event.mpos.x = xx sdl_event.button.x;
			event.mpos.y = xx sdl_event.button.y;
			
			case SDL_MOUSEBUTTONUP;
			event := push_event(*out);
			event.kind = .Released;
			event.key = key_from_sym(xx sdl_event.button.button);
			event.mpos.x = xx sdl_event.button.x;
			event.mpos.y = xx sdl_event.button.y;
			
			case SDL_MOUSEMOTION;
			event := push_event(*out);
			event.kind = .MouseMove;
			event.mpos.x = xx sdl_event.motion.x;
			event.mpos.y = xx sdl_event.motion.y;
			
			case SDL_MOUSEWHEEL;
			event := push_event(*out);
			event.kind = .Scroll;
			event.wheel = sdl_event.wheel.y;
		}
	}
	
	return out;
}

key_from_sym :: (sym : SDL_Keycode) -> Key{
	out : Key = .NULL;
	
	if sym == {
		case SDLK_ESCAPE; out = .ESC;
		case SDLK_a; out = .A;
		case SDLK_b; out = .B;
		case SDLK_c; out = .C;
		case SDLK_d; out = .D;
		case SDLK_e; out = .E;
		case SDLK_f; out = .F;
		case SDLK_g; out = .G;
		case SDLK_h; out = .H;
		case SDLK_i; out = .I;
		case SDLK_j; out = .J;
		case SDLK_k; out = .K;
		case SDLK_l; out = .L;
		case SDLK_m; out = .M;
		case SDLK_n; out = .N;
		case SDLK_o; out = .O;
		case SDLK_p; out = .P;
		case SDLK_q; out = .Q;
		case SDLK_r; out = .R;
		case SDLK_s; out = .S;
		case SDLK_t; out = .T;
		case SDLK_u; out = .U;
		case SDLK_v; out = .V;
		case SDLK_w; out = .W;
		case SDLK_x; out = .X;
		case SDLK_y; out = .Y;
		case SDLK_z; out = .Z;
		
		case SDL_BUTTON_LEFT; out = .LMB;
		case SDL_BUTTON_RIGHT; out = .RMB;
		
		case SDLK_SPACE; out = .SPACE;
		case SDLK_LCTRL; out = .LCTRL;
		case SDLK_TAB; out = .TAB;
	}
	
	return out;
}

get_window_size :: (win : Handle) -> Vector2 {
	sdl_win : *SDL_Window = xx win.U64[0];
	
	w : s32;
	h : s32;
	SDL_GetWindowSize(sdl_win, xx *w, xx *h);
	
	out : Vector2 = .{xx w, xx h};
	return out;
}