#import "Basic";
#import "mizu_base";
#import "Math";
r :: #import "render";
ui :: #import "ui";

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
		
		print("----\n");
		draw_children(ui_cxt.root);
		print("----\n");
		ui.end(ui_cxt);
		ui_batches : r.BatchList;
		
		r.push_rect2(*ui_batches, rectF32(0, 0, 30, 30), .{1, 1, 1, 1});
		
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