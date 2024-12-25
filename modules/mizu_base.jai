u128 :: struct {
	U64: [2]u64;
};

operator == :: (a : u128, b : u128) -> bool {
	return ((a.U64[0] == b.U64[0]) && (a.U64[1] == b.U64[1]));
}

KB :: (v : u64) -> u64 {
	return v * 1024;
}

MB :: (v : u64) -> u64 {
	return KB(v) * 1024;
}

GB :: (v : u64) -> u64 {
	return MB(v) * 1024;
}

TB :: (v : u64) -> u64 {
	return GB(v) * 1024;
}

isPow2 :: (addr : u64) -> bool {
	return (addr & (addr-1)) == 0;
}

ARENA_COMMIT_SIZE :: #run KB(64);
ARENA_RESERVE_SIZE :: #run MB(64);
ARENA_HEADER_SIZE :: 128;

Arena :: struct {
	base : *u8;
	used : u64;
	align: u64;
	cmt : u64;
	res : u64;
};
