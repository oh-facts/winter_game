#import "Windows";
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
	sysinfo : SYSTEM_INFO;
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

sleep :: (ms : s32) {
	Sleep(ms);
}