#import "Basic";
#import "mizu_base";
#import "Math";
r :: #import "render";

main :: () {
	print("Do not enter is written on the doorway, why can't everyone just go away\n");
	print("Except for you, you can stay\n");
	
	os.init();
	win := os.open_window("winter steam game", 960, 540);
	
	r.init();
	
	quit : bool;
	
	start := os.get_perf_counter();
	freq := os.get_perf_freq();
	
	time_elapsed : float64;
	delta : float64;
	
	mv : Vector2;
	pos : Vector2;
	
	while !quit {
		time_since_last := time_elapsed;
		
		events := os.poll_events();
		
		if os.event(*events, .NULL, .CloseRequested) || os.event(*events, .ESC, .Pressed){
			quit = true;
		}

		ui_batches : r.BatchList;

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
		print("%\n", delta);
		
		reset_temporary_storage();
	}
	
	print("quit safely\n");
}