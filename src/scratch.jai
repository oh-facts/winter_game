scratch_initialized : bool;
scratch_window : *Editor_Window;

counter : u64;

scratch_update :: (delta : float32, events : *os.EventList,
									 passes : *r.Pass_List) {
	if !scratch_initialized {
		scratch_initialized = true;
	}
	
	counter += 1;
}