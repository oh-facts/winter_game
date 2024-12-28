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
	
	ell_bmp : Bitmap;
	{
		filename := tprint("%/%", data_folder, "art/ell.png");
		ell_bmp = bitmap(arena, filename);;
	}
	
	ell := r.image(ell_bmp);
	
	impolo_bmp : Bitmap;
	{
		filename := tprint("%/%", data_folder, "art/impolo-east.png");
		impolo_bmp = bitmap(arena, filename);;
	}
	
	impolo_art := r.image(impolo_bmp, .NEAREST);
	py_pos : Vector2;
	counter : float32;
	mv : Vector2;
	
	while !quit {
		//print("%\n", frames);
		frames += 1;
		time_since_last := time_elapsed;
		
		events := os.poll_events();
		
		if os.event(*events, .NULL, .CloseRequested) || os.event(*events, .ESC, .Pressed){
			quit = true;
		}
		
		/*
		ui.begin(ui_cxt);
		ui.label(ui_cxt, "hello");
		ui.label(ui_cxt, "hello");
		ui.label(ui_cxt, "hello");
		
		ui.layout(ui_cxt.root);
		
		print("----\n");
		draw_children(ui_cxt.root);
		print("----\n");
		ui.end(ui_cxt);
		*/
		
		ui_batches : r.BatchList;
		
		// tilemap
		{
			for y: 0 .. 64 {
				for x: 0 .. 64 {
					dst : RectF32;
					dst.min.x = xx (x * 32);
					dst.min.y = xx (y * 32);
					dst.max.x = dst.min.x + 32;
					dst.max.y = dst.min.y + 32;
					
					colors := Vector4.[r.COLOR_BLACK,
														 r.COLOR_RED,
														 r.COLOR_GREEN,
														 r.COLOR_BLUE,
														 r.COLOR_YELLOW,
														 r.COLOR_CYAN,
														 r.COLOR_MAGENTA,];
					
					r.push_rect2(*ui_batches, dst, colors[(x + y) % colors.count]);
				}
			}
			
		}
		
		// player
		{
			if(os.event(*events, .W, .Pressed))
			{
				mv.y += -1;
			}
			else if(os.event(*events, .W, .Released))
			{
				mv.y -= -1;
			}
			
			if(os.event(*events, .A, .Pressed))
			{
				mv.x += -1;
			}
			else if(os.event(*events, .A, .Released))
			{
				mv.x -= -1;
			}
			
			if(os.event(*events, .D, .Pressed))
			{
				mv.x += 1;
			}
			else if(os.event(*events, .D, .Released))
			{
				mv.x -= 1;
			}
			
			if(os.event(*events, .S, .Pressed))
			{
				mv.y += 1;
			}
			else if(os.event(*events, .S, .Released))
			{
				mv.y -= 1;
			}
			
			py_speed :: 300.;
			py_pos.x += mv.x * xx delta * py_speed;
			py_pos.y += mv.y * xx delta * py_speed;
			
			counter += xx delta;
			
			width := 1.0 / 8.0;
			index := (xx (counter * 10)) % 8;
			
			py_size := Vector2.{128, 128};
			
			py_dst : RectF32;
			py_dst.min.x = py_pos.x;
			py_dst.min.y = py_pos.y;
			py_dst.max.x = py_dst.min.x + py_size.x;
			py_dst.max.y = py_dst.min.y + py_size.y;
			
			py_rect := r.push_rect2(*ui_batches, py_dst, .{1, 1, 1, 1});
			py_rect.tex_id = impolo_art.U64[1];
			py_rect.src = rectF32(index * width, 0, index * width + width, 1);
		}
		
		// debug text
		
		text := tprint("do not enter is written on the doorway,\nwhy can't everyone just go away");
		text_pos : Vector2 = .{0, 0};
		text_size := 0.6;
		
		ext := r.get_text_rect(font, text, text_pos, text_size);
		r.push_rect2(*ui_batches, ext, .{0, 0, 0, 0.9});
		
		r.push_text(*ui_batches, font, text, text_pos, text_size, r.COLOR_ORANGE);
		test := r.push_rect2(*ui_batches, rectF32(0, 400, 80, 480), .{1, 1, 1, 1});
		test.tex_id = ell.U64[1];
		
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