#import "Windows";
#import "SDL";
#import "mizu_base";
#import "Math";
#import "Basic";

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
	CloseRequested;
};

Event :: struct {
	next : *Event;
	prev : *Event;
	key : Key;
	kind : EventKind;
	win : Handle;
	mpos : Vector2;
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

reserve :: (size : u64) -> *void {
	out := VirtualAlloc(xx 0, size, MEM_RESERVE, PAGE_READWRITE);
	assert(xx out);
	return xx out;
}

commit :: (ptr : *void, size : u64) -> bool {
	out := VirtualAlloc(ptr, size, MEM_COMMIT, PAGE_READWRITE);
	assert(xx out);
	return xx out;
}

decommit :: (ptr : *void, size : u64) {
	VirtualFree(ptr, size, MEM_DECOMMIT);
}

free :: (ptr : *void, size : u64) {
	VirtualFree(ptr, 0, MEM_RELEASE);
}

get_page_size :: () -> u64 {
	sysinfo :: SYSTEM_INFO;
	GetSystemInfo(*sysinfo);
	return sysinfo.dwPageSize;
}

get_perf_counter :: () -> s64 {
	counter : s64;
	QueryPerformanceCounter(*counter);
	return counter;
}

get_perf_freq :: () -> s64 {
	frequency : s64;
	QueryPerformanceFrequency(*frequency);
	return frequency;
}

load_library :: (name : *u8) -> Handle {
	out : Handle;
	dll : HMODULE = LoadLibraryA(name);
	out.U64[0] = xx dll;
	return out;
}

load_function :: (handle : Handle, name : *u8) -> *void {
	dll : HMODULE = handle.U64[0];
	out := GetProcAddress(dll, name);
	return out;
}

vulkan_load_library :: () -> Handle {
	return load_library("vulkan-1.dll");
}

push_event :: (list : *EventList) -> *Event {
	list.count+=1;
	
	out : *Event = talloc(size_of(Event));
	
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
}

// NOTE(mizu): Will probably fail if string isn't a literal

open_window :: (title : string, w : s32, h : s32) -> Handle {
	out : Handle;
	
	sdl_win := SDL_CreateWindow(title.data, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, w, h, SDL_WINDOW_SHOWN);
	out.U64[0] = xx sdl_win;
	
	return out;
}

poll_events :: () -> EventList {
	out : EventList;
	
	sdl_event : SDL_Event;
	
	while SDL_PollEvent(*sdl_event) {
		if (sdl_event.type == SDL_QUIT) {
			event := push_event(*out);
			event.key = .NULL;
			event.kind = .CloseRequested;
		}
		else if (sdl_event.type == SDL_KEYDOWN) {
			event := push_event(*out);
			event.key = key_from_sym(sdl_event.key.keysym.sym);
			event.kind = .Pressed;
		}
		else if (sdl_event.type == SDL_KEYUP) {
			event := push_event(*out);
			event.key = key_from_sym(sdl_event.key.keysym.sym);
			event.kind = .Released;
		}
	}
	
	return out;
}

key_from_sym :: (sym : SDL_Keycode) -> Key{
	out : Key = .NULL;
	
	if sym == SDLK_ESCAPE out = .ESC;
	else if sym == SDLK_a out = .A;
	else if sym == SDLK_b out = .B;
	else if sym == SDLK_c out = .C;
	else if sym == SDLK_d out = .D;
	else if sym == SDLK_e out = .E;
	else if sym == SDLK_f out = .F;
	else if sym == SDLK_g out = .G;
	else if sym == SDLK_h out = .H;
	else if sym == SDLK_i out = .I;
	else if sym == SDLK_j out = .J;
	else if sym == SDLK_k out = .K;
	else if sym == SDLK_l out = .L;
	else if sym == SDLK_m out = .M;
	else if sym == SDLK_n out = .N;
	else if sym == SDLK_o out = .O;
	else if sym == SDLK_p out = .P;
	else if sym == SDLK_q out = .Q;
	else if sym == SDLK_r out = .R;
	else if sym == SDLK_s out = .S;
	else if sym == SDLK_t out = .T;
	else if sym == SDLK_u out = .U;
	else if sym == SDLK_v out = .V;
	else if sym == SDLK_w out = .W;
	else if sym == SDLK_x out = .X;
	else if sym == SDLK_y out = .Y;
	else if sym == SDLK_z out = .Z;
	
	else if sym == SDLK_SPACE out = .SPACE;
	
	
	return out;
}

sleep :: (ms : s32) {
	Sleep(ms);
}