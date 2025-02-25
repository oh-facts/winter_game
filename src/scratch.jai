// ui todo :
// more styling
// text alignment
// more widgets
// 1. Slider
// 2. Color Picker
// panels

scratch_initialized : bool;
scratch_window : *Editor_Window;

checked : [2]bool;
slider : float = 0.5;
counter : int;

scratch_update :: (delta : float32, events : *os.EventList, 
									 passes : *r.Pass_List) {
	if !scratch_initialized {
		scratch_initialized = true;
		scratch_window = editor_init_window("editor window");
	}
	
	editor_window_begin(scratch_window, events);
	editor_push_file_id(scratch_window, .Scratch);
	text : string;
	
	
	editor_pop_file_id(scratch_window);
	editor_window_end(scratch_window);
}