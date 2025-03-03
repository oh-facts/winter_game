scratch_initialized : bool;
scratch_window : *Editor_Window;

counter : u64;

scratch_update :: (delta : float32, events : *os.EventList,
									 passes : *r.Pass_List) {
	if !scratch_initialized {
		scratch_initialized = true;
	}
	
	scope := tex.scope_open();
	
	bg := r.push_rect2(passes, rectF32(0, 0, 1920, 1080), r.COLOR_WHITE);
	bg.tex_id = tex.handle_from_hash(scope, arts[ArtId.Fat].hash).U64[1];
	tex.scope_close(scope);
	
	text := tprint("%", delta);
	r.push_text(passes, font, text, .{}, text_size, r.COLOR_BLACK);
	
	counter += 1;
}