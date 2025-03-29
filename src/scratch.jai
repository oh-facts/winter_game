// TODO(mizu): maximize button, recreate framebuffers, get rid of camera stupid abstraction work on "tabs" and make the map editor and game different tabs and work on letting the map editor have windows and fix scissors and then :) :) :) put the map editor, and sim inside of main.
scratch_initialized : bool;
//scratch_window : *Editor_Window;

counter : u64;
current_art : *Art;
files : []string;

scratch_update :: (delta : float32, events : *os.EventList,
									 passes : *r.Pass_List) {
	if !scratch_initialized {
		scratch_initialized = true;
	}
	
	//text := tprint("%", delta);
	//r.push_text(passes, font, text, .{}, text_size, r.COLOR_BLACK);
	
	counter += 1;
}