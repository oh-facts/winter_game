scratch_initialized : bool;
scratch_window : *Editor_Window;

hash : [4]u128;
counter : u64;

scratch_update :: (delta : float32, events : *os.EventList,
									 passes : *r.Pass_List) {
	if !scratch_initialized {
		scratch_initialized = true;
		
		paths : [4]string = .[
													"art/fat/1.png",
													"art/impolo-idle.png",
													"art/ball.png",
													"art/siren.png"
													];
		
		for 0 .. 3 {
			filename := tprint("%/%", data_folder, paths[it]);
			file := file_open(filename, false, true, true);
			defer file_close(*file);
			file_size := file_length(file);
			
			arena := arena_init(xx file_size, xx file_size);
			temp_file_data := read_entire_file(file);
			defer free(temp_file_data);
			
			data : string;
			data.data = push_array(arena, u8, xx temp_file_data.count);
			data.count = temp_file_data.count;
			
			memcpy(data.data, temp_file_data.data, data.count);
			
			hash[it] = tex.hash_from_key_data(paths[it], .{.[xx it]}, data, arena);
			
		}
		
		//thread_entry : Thread_Proc; 
		
		//thread : Thread;
		
		//thread_init(*thread, tex.evict_textures);
		
		//thread_start(*thread);
	}
	
	ell := r.push_rect2(passes, rectF32(0, 0, 1920, 1080), r.COLOR_WHITE);
	scope := tex.scope_open();
	
	ell.tex_id = tex.handle_from_hash(scope, hash[(counter / 165) % 4]).U64[1];
	
	tex.scope_close(scope);
	
	counter += 1;
}