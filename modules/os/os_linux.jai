#import "POSIX";
reserve :: (size : u64) -> *void {
    out := mmap(xx 0, size, PROT_NONE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
	assert(xx out);
	return xx out;
}

commit :: (ptr : *void, size : u64) -> bool {
    out := mprotect(ptr, size, PROT_READ | PROT_WRITE);
	assert((xx out != -1));
	return xx out;
}

decommit :: (ptr : *void, size : u64) {
    madvise(ptr, size, MADV_DONTNEED);
	mprotect(ptr, size, PROT_NONE);
}

free :: (ptr : *void, size : u64) {
    munmap(ptr, size);
}

get_page_size :: () -> u64 {
    return xx getpagesize();
}

get_perf_counter :: () -> s64 {
	ts : timespec;
	clock_gettime(.MONOTONIC, *ts);
	return ts.tv_sec * 1000000000 + ts.tv_nsec;
}

get_perf_freq :: () -> s64 {
    return 1000000000;
}

load_library :: (name : *u8) -> Handle {
	out : Handle;
	dll := dlopen(name, RTLD_NOW);
	out.U64[0] = xx dll;
	return out;
}

load_function :: (handle : Handle, name : *u8) -> *void {
	dll : *void = handle.U64[0];
	out := dlsym(dll, name);
	return out;
}

sleep :: (ms : s32) {
    ts : timespec;
	ts.tv_sec = ms / 1000;
	ts.tv_nsec = (ms % 1000) * 1000000;
	nanosleep(*ts, xx 0);
}