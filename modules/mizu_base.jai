os :: #import "os";
#import "Basic";
#import "stb_image";
#import "Math";

Vector2i :: struct {
	x : s32;
	y : s32;
}

Vector3i :: struct {
	x : s32;
	y : s32;
	z: s32;
}

u128 :: struct {
	U64 : [2]u64;
};

RectF32 :: struct {
	min : Vector2;
	max : Vector2;
};

RectS32 :: struct {
	min : Vector2i;
	max : Vector2i;
};

rectF32 :: (min_x : float32, min_y : float32, max_x : float32, max_y : float32) -> RectF32 {
	out : RectF32;
	
	out.min.x = min_x;
	out.min.y = min_y;
	
	out.max.x = max_x;
	out.max.y = max_y;
	
	return out;
}

operator == :: (a : u128, b : u128) -> bool {
	return ((a.U64[0] == b.U64[0]) && (a.U64[1] == b.U64[1]));
}

KB :: (v : u64) -> u64 #expand {
	return v * 1024;
}

MB :: (v : u64) -> u64 #expand {
	return KB(v) * 1024;
}

GB :: (v : u64) -> u64 #expand {
	return MB(v) * 1024;
}

TB :: (v : u64) -> u64 #expand {
	return GB(v) * 1024;
}

is_pow_2 :: (addr : u64) -> bool #expand{
	return (addr & (addr-1)) == 0;
}

align_pow_2 :: (x: u64, b: u64) -> u64 #expand{
	return (((x) + (b) - 1)&(~((b) - 1)));
}

clamp_top :: (a : $A, x : A) -> A #expand {
	return min(a,x);
}

clamp_bot :: (x : $X, b : X) -> X #expand {
	return max(x,b);
}

ARENA_COMMIT_SIZE :: #run KB(64);
ARENA_RESERVE_SIZE :: #run MB(64);
ARENA_HEADER_SIZE :: 128;
DEFAULT_ALIGN :: size_of(*void);

Arena :: struct {
	base : *u8;
	used : u64;
	align: u64;
	cmt : u64;
	res : u64;
};

arena_init :: (cmt := ARENA_COMMIT_SIZE, res := ARENA_RESERVE_SIZE) -> *Arena {
	out : *Arena;
	
	page_size := os.get_page_size();
	res = align_pow_2(res, page_size);
	cmt = align_pow_2(cmt, page_size);
	
	memory := os.reserve(res);
	os.commit(memory, cmt);
	
	out = xx memory;
	out.used = ARENA_HEADER_SIZE;
	out.align = DEFAULT_ALIGN;
	
	out.cmt = cmt;
	out.res = res;
	
	return out;
}

arena_push_impl :: (arena : *Arena, size : u64) -> *void {
	pos_mem := align_pow_2(arena.used, arena.align);
	pos_new := pos_mem + size;
	
	if(arena.res < pos_new)
	{
		// TODO(mizu): deal with reserving more (chain arenas)
		// I am not too keen on working on this because I can always reserve more, but I think it will be good for robustness so it can handle arbitrary sizes without me having to increasing reserve size and recompiling. (Argument is a bit weak because 64 bit processes have an insanely large virtual address space.)
		assert(false);
	}
	
	if(arena.cmt < pos_new)
	{
		cmt_new_aligned, cmt_new_clamped, cmt_new_size : u64;
		
		cmt_new_aligned = align_pow_2(pos_new, ARENA_COMMIT_SIZE);
		cmt_new_clamped = clamp_top(cmt_new_aligned, arena.res);
		cmt_new_size    = cmt_new_clamped - arena.cmt;
		os.commit(cast(*u8)arena + arena.cmt, cmt_new_size);
		arena.cmt = cmt_new_clamped;
	}
	
	memory : *void;
	
	if (arena.cmt >= pos_new)
	{
		memory = cast(*u8)arena + pos_mem;
		arena.used = pos_new;
	}
	
	return memory;
}

push_struct :: (arena : *Arena, type : Type) -> *void #expand{
	return arena_push_impl(arena, size_of(type));
}

push_array :: (arena : *Arena, type : Type, count : u64) -> [] Any #expand {
	memory := arena_push_impl(arena, size_of(type) * count);
	out : [] Any;
	out.count = xx count;
	out.data = memory;
	return out;
}

// Isn't zeroed!
tpush_struct :: (type : Type) -> *Type #expand {
	return talloc(size_of(type));
}

tzpush_struct :: (type : Type) -> *void #expand{
	out := tpush_struct(type);
	memset(out, 0, size_of(type));
	return out;
}

// Isn't zeroed!
tpush_array :: (type : Type, count : s64) -> [] Any {
	memory := talloc(count * size_of(type));
	
	out : [] Any;
	out.count = xx count;
	out.data = memory;
	
	return out;
}

Bitmap :: struct {
	data : *void;
	w : s32;
	h : s32;
	n : s32;
}

bitmap :: (arena : *Arena, path : string) -> Bitmap {
	out : Bitmap;
	stbi_set_flip_vertically_on_load(1);
	
	w, h, n : s32;
	
	bytes := stbi_load(path.data, *w, *h, *n, 4);
	
	out.w = w;
	out.h = h;
	out.n = 4;
	out.data = push_array(arena, u8, xx (out.w * out.h * out.n)).data;
	memcpy(out.data, bytes, out.w * out.h * out.n);
	
	stbi_image_free(bytes);
	
	return out;
}