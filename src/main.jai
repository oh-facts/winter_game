#import "System";
#import "String";
#import "Basic";
#import "mizu_base";
#import "Math";
#import "File";
r :: #import "render";
ui :: #import "ui";
#import "Random";
draw_children :: (root : *ui.Widget) {
	
	print("%\n", root.pref_size);
	
	{
		child :=  root.first;
		while child {
			draw_children(child);
			child = child.next;
		}
		
	}
}

main :: () {
	print("Do not enter is written on the doorway, why can't everyone just go away\n");
	print("Except for you, you can stay\n");
	
	os.init();
	win := os.open_window("winter steam game", 960, 540);
	
	r.init();
	
	ui_cxt := ui.init();
	
	quit : bool;
	
	start := os.get_perf_counter();
	freq := os.get_perf_freq();
	
	time_elapsed : float64;
	delta : float64;
	
	mv : Vector2;
	pos : Vector2;
	
	frames : u64;
	
	arena := arena_init();
	
	base_path := path_strip_filename(get_path_of_running_executable());
	data_folder := join(base_path, "../data");
	
	font : *r.Font;
	
	{
		filename := tprint("%/%", data_folder, "fonts/font.data");
		data := read_entire_file(filename);
		font = xx data.data;
	}
	
	{
		filename := tprint("%/%", data_folder, "fonts/font.png");
		font.bmp = bitmap(arena, filename);
	}
	
	font.img = r.image(font.bmp);
	
	while !quit {
		//print("%\n", frames);
		frames += 1;
		time_since_last := time_elapsed;
		
		events := os.poll_events();
		
		if os.event(*events, .NULL, .CloseRequested) || os.event(*events, .ESC, .Pressed){
			quit = true;
		}
		
		ui.begin(ui_cxt);
		ui.label(ui_cxt, "hello");
		ui.label(ui_cxt, "hello");
		ui.label(ui_cxt, "hello");
		
		ui.layout(ui_cxt.root);
		
		//print("----\n");
		//draw_children(ui_cxt.root);
		//print("----\n");
		ui.end(ui_cxt);
		ui_batches : r.BatchList;
		
		text := "do not enter is written on the doorway";
		text_pos : Vector2 = .{0, -17};
		text_size := 0.6;
		
		ext := r.get_text_rect(font, text, text_pos, text_size);
		text_pos.y += (ext.max.y - ext.min.y);
		
		//ext = r.get_text_rect(font, text, text_pos, text_size);
		
		//r.push_rect2(*ui_batches, ext, .{1, 0, 0, 0.7});
		r.push_text(*ui_batches, font, text, text_pos, text_size);
		
		r.submit(win, ui_batches);
		
		end := os.get_perf_counter();
		time_elapsed = (end - start) / (freq * 1.);
		delta = time_elapsed - time_since_last;
		
		// poor man's vsync--------------------------------
		ifx false {
			time_left : float64 = (1 / 60.) - delta;
			if (time_left > 0) 
			{
				os.sleep(xx (time_left * 1000));
			}
		}
		// -------------------------------------------------
		//print("%\n", delta);
		
		reset_temporary_storage();
	}
	
	print("quit safely\n");
}