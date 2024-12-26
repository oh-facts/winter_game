os :: #import "os";
#import "Basic";

u128 :: struct {
	U64: [2]u64;
};

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

arena_push :: (arena : *Arena, type : Type, count : u64) -> *void #expand {
	return arena_push_impl(arena, size_of(type) * count);
}

talloc_array :: (type : Type, count : s64) -> [] Type {
	memory := talloc(count * size_of(Type));
	
	out : [] Type;
	out.count = xx count;
	out.data = memory;
	
	return out;
}