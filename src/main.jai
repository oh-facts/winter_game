#import "Basic";
#import "mizu_base";
#import "Math";

os:: #import "os";

main :: () {
	print("Do not enter is written on the doorway, why can't everyone just go away\n");
	print("Except for you, you can stay\n");
	
	vk_dll : os.Handle = os.vulkan_load_library();
	assert(xx vk_dll.U64[0]);
	
	os.init();
	win := os.open_window("winter steam game", 960, 540);
	
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
		
		end := os.get_perf_counter();
		time_elapsed = (end - start) / (freq * 1.);
		delta = time_elapsed - time_since_last;
		
		// poor man's vsync--------------------------------
		time_left : float64 = (1 / 60.) - delta;
		if (time_left > 0) 
		{
			os.sleep(xx (time_left * 1000));
		}
		// -------------------------------------------------
		
		//print("%\n", delta);
		
	}
	
	print("quit safely\n");
}