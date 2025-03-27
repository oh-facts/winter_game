// TODO(mizu): in case text doesnt fit in a certain width, render ...

// make editor widgets copy the string. right now it isnt a problem because my strings are always valid for the frame. In my text edit it was a problem so I am doing that there for now.

// Make the signal part of the widget impl.
// That way, you can make most widgets not care for signals
// and for the ones that do, you can add extra checks so if the widget flows outside
// its container, its signal can be rejected

// However, it is probably a good idea to make the library not submit draw commands
// for stuff that is outside its clip.

// TODO(mizu): Put this shit inside an editor ui state. And use the flags. And call the file widgets? And make it easier to pick
// No need to call it editor window.
// window is fine. Winter_Window maybe?
// 

// TODO(mizu): Do panels first, then do tabs. Make floating panels instead of floating tabs.

// For combat I am thinking, first it opens with tthe tree mortphing into psyvhologoy man.

// Maybe the window changes with every turn?

// So when its player's turn, you see him

// when you do the attack, you see him do the attack

// during enemy turn, you see the enemy 

// after every and during every attack, you see the reactions on people's faces?

// "I am sorry, demons can't go to heaven. I can kill him for you if you want. But I will do it later because I am tired. Still, I wouldnt worry because I sense nothing can hurt you."

editor_windows : [5]Editor_Window;
editor_windows_count : s32;

active_window :: () -> *Editor_Window {
	return editor_window_stack.top.v;
}

Editor_File_Id :: enum {
	Null;
	Scratch;
	Editor;
	Map_Editor;
	Simulation;
}

/*
0. index
1. depth
2. line #
3. file #
4. window #
*/

widget_key :: (index := 0, depth :*UI_ID = xx 0, loc : Source_Code_Location) -> UI_ID {
	out : UI_ID;
	
	out.v[0] = xx index;
	out.v[1] = xx depth;
	out.v[2] = xx loc.line_number;
	out.v[3] = xx active_window_file_id();
	out.v[4] = xx active_window().id;
	
	return out;
}

Editor_Window_Flags :: enum_flags {
	Draw_Titlebar;
	Resizable;
	Scrollable;
	Dialog;
}

Editor_Panel :: struct {
	first : *Editor_Panel;
	last : *Editor_Panel;
	next : *Editor_Panel;
	prev : *Editor_Panel;
	parent : *Editor_Panel;
	
	axis : UI_Axis;
	pct : float;
}

Editor_Tab_Flags :: enum {
	Menu_Tab;
}

Editor_Tab :: struct {
	kind : Mode;
	flags : Editor_Tab_Flags;
	pos : Vector2;
	size : Vector2;
}

Editor_Window :: struct {
	arena : *Arena;
	flags : Editor_Window_Flags;
	
	pre_fullscreen_size : Vector2;
	
	tabs : [Mode.COUNT]Editor_Tab;
	
	hide : bool;
	events : *os.EventList;
	
	last_grabbed_tick : int;
	
	win_target : r.Framebuffer;
	game_target : r.Framebuffer;
	
	client_rect : *UI_Widget;
	game_target_rect : *UI_Widget;
	
	// titlebar
	title : string;
	grabbed : bool;
	titlebar_height :: 32;
	last_mpos : Vector2;
	id : s32;
	last_touched : int;
	
	root : *UI_Widget;
	tb : *UI_Widget;
	pos : Vector2;
	dst : RectF32;
	tb_dst : RectF32;
	
	resize_grabbed : bool;
	size : Vector2;
	close_requested : bool;
	fullscreen : bool;
	scroll_offset : float;
	
	file_id_stack : struct {
		top : *Editor_File_Id_Node;
		free : *Editor_File_Id_Node;
	};
	
	root_panel : *Editor_Panel;
}

editor_window_stack : struct {
	top : *Editor_Window_Meta_Node;
	free : *Editor_Window_Meta_Node;
};

Editor_File_Id_Node :: struct {
	next : *Editor_File_Id_Node;
	v : Editor_File_Id;
}

editor_push_file_id :: (v : Editor_File_Id) {
	node := active_window().file_id_stack.free;
	
	if !node {
		node = push_struct(active_window().arena, Editor_File_Id_Node);
	} else {
		active_window().file_id_stack.free = active_window().file_id_stack.free.next;
		<< node = .{};
	}
	
	node.v = v;
	
	node.next = active_window().file_id_stack.top;
	active_window().file_id_stack.top = node;
}

editor_pop_file_id :: () {
	to_free := active_window().file_id_stack.top;
	
	active_window().file_id_stack.top = active_window().file_id_stack.top.next; 
	
	to_free.next = active_window().file_id_stack.free;
	active_window().file_id_stack.free = to_free;
}

Editor_Window_Meta_Node :: struct {
	next : *Editor_Window_Meta_Node;
	v : *Editor_Window;
}

editor_clock : int;

editor_tick_clock :: () {
	editor_clock += 1;
}

editor_in_focus :: (window : Editor_Window) -> bool {
	
	out : bool;
	
	if window.last_touched + 1 < editor_clock {
		return false;
	}
	
	if window.resize_grabbed || window.grabbed {
		return true;
	}
	
	out = point_in_rect(mpos, window.dst);
	
	if !(window.flags & .Dialog) {
		if point_in_rect(mpos - .{0, 32}, window.client_rect.dst) {
			out = false;
		}
	}
	
	return out;
}

any_editor_in_focus :: () -> bool {
	out : bool;
	
	for 0 .. editor_windows_count - 1 {
		res := editor_in_focus(editor_windows[it]);
		
		if res {
			out = true;
			break;
		}
	}
	
	return out;
}

Editor_Panel_Rec :: struct {
	v : *Editor_Panel;
	push : int;
	pop : int;
}

depth_first_preorder :: (v : *Editor_Panel) -> Editor_Panel_Rec {
	out : Editor_Panel_Rec;
	
	if v.first {
		out.v = v.first;
		out.push = 1;
	} else {
		cur : * Editor_Panel = v;
		
		while cur {
			if cur.next {
				out.v = v.next;
				break;
			}
			out.pop += 1;
			cur = cur.parent;
		}
	}
	
	return out;
}

editor_init_window :: (title : string, flags : Editor_Window_Flags, pos : Vector2 = .{}, size : Vector2 = .{400, 300}) -> *Editor_Window {
	out := *editor_windows[0] + editor_windows_count;
	out.id = editor_windows_count;
	editor_windows_count += 1;
	out.title = title;
	
	if flags & .Dialog {
		out.size = size;
		out.pos = pos;
	} else {
		out.size = os.get_window_size(win);
		out.pos = os.get_window_pos(win);
		out.win_target = r.framebuffer(out.size);
		out.game_target = r.framebuffer(.{1920, 1024});
	}
	
	out.arena = arena_init();
	out.flags = flags;
	out.root_panel = push_struct(arena, Editor_Panel);
	out.root_panel.axis = .X;
	out.root_panel.pct = 1;
	
	
	return out;
}

editor_window_begin :: (window : *Editor_Window, events : *os.EventList) {
	window.last_touched = editor_clock;
	window.events = events;
	
	// push to active window stack
	{
		node := editor_window_stack.free;
		
		if !node {
			node = push_struct(arena, Editor_Window_Meta_Node);
		} else {
			editor_window_stack.free = editor_window_stack.free.next;
			<< node = .{};
		}
		
		node.v = window;
		
		node.next = editor_window_stack.top;
		editor_window_stack.top = node;
	}
	
	editor_push_file_id(.Editor);
	
	ui_push_flags_node(UI_Floating, true);
	ui_push_size_x_node(ui_size_px(window.size.x), true);
	
	if window.hide {
		ui_push_size_y_node(ui_size_children_sum(), true);
	} else {
		ui_push_size_y_node(ui_size_px(window.size.y), true);
	}
	
	root := ui_widget_from_key(widget_key(0, xx 0, .{}));
	//root.scissor = root.dst;
	root.child_layout_axis = .Y;
	
	if window.flags & .Dialog {
		root.computed_pos = window.pos.component;
	}
	
	window.dst = root.dst;
	ui_push_parent_node(root);
	
	// titlebar
	if window.flags & .Draw_Titlebar {
		ui_push_flags_node(.Bg, true);
		ui_push_size_x_node(ui_size_pct(1.), true);
		ui_push_size_y_node(ui_size_px(32), true);
		ui_push_bg_color_node(.{0.639, 0.624, 0.584, 1}, true);
		editor_row_begin();
		
		ui_push_size_x_node(ui_size_pct(0.35, 0));
		ui_push_size_y_node(ui_size_pct(1, 0));
		ui_push_hover_color_node(r.COLOR_BLACK);
		
		ui_push_size_node(ui_size_px(32, 1), true);
		
		if editor_image(editor_titlebar_art, .{.{0, 0}, .{0.25, 1}}, .{0.459, 0.439, 0.402, 1}).active {
			window.hide = !window.hide;
		}
		
		editor_spacer(ui_size_pct(1, 0));
		
		ui_push_size_x_node(ui_size_txt(), true);
		sig := editor_label(active_window().title);
		sig = ui_signal(sig.widget);
		
		if sig.active {
			window.grabbed = true;
		}
		
		editor_spacer(ui_size_pct(1, 0));
		
		if !(window.flags & .Dialog) {
			// minimize
			ui_push_size_node(ui_size_px(32, 1));
			if editor_image(editor_titlebar_art, .{.{0.25, 0}, .{0.5, 1}}, .{0.459, 0.439, 0.402, 1}).active {
				os.minimize_window(win);
			}
			
			// maximize
			if editor_image(editor_titlebar_art, .{.{0.5, 0}, .{0.75, 1}}, .{0.459, 0.439, 0.402, 1}).active {
				
				if !window.fullscreen {
					window.pre_fullscreen_size = window.size;
					window.size.x = 1920;
					window.size.y = 1080;
				} else {
					window.size = window.pre_fullscreen_size;
				}
				window.fullscreen = !window.fullscreen;
				os.set_fullscreen(win, window.fullscreen);
				window.flags ^= .Resizable;
				window.win_target = r.framebuffer(window.size);
			}
			
			// close
			if editor_image(editor_titlebar_art, .{.{0.75, 0}, .{1, 1}}, .{0.459, 0.439, 0.402, 1}).active {
				window.close_requested = true;
			}
			ui_pop_size_node();
		}
		
		ui_pop_hover_color_node();
		
		ui_pop_size_node();
		
		editor_row_end();
	}
	
	if point_in_rect(mpos, window.dst) {
		
		if active_window().flags & .Scrollable {
			scroll_event := os.event(events, .NULL, .Scroll);
			scroll_up, scroll_down : bool;
			
			if scroll_event {
				
				if scroll_event.wheel > 0 {
					scroll_up = true;
				}
				
				else if scroll_event.wheel < 0 {
					scroll_down = true;
				}
			}
			
			if scroll_up {
				window.scroll_offset += 4;
			}
			
			if scroll_down {
				window.scroll_offset -= 4;
			}
		}
	}
	
	ui_push_size_node(ui_size_pct(1, 0), true);
	editor_row_begin();
	
	row_parent := active_cxt().parent_stack.top.v;
	
	ui_push_size_node(ui_size_pct(1, 0), true);
	ui_push_border_color_node(r.COLOR_MAGENTA, true);
	editor_col_begin();
	col_parent := active_cxt().parent_stack.top.v;
	col_parent.offset[1] = window.scroll_offset;
	col_parent.flags |= .Bg;
	
	if window.flags & .Dialog {
		col_parent.flags |= .Scissor;
	}
	
	window.client_rect = col_parent;
	
	//col_parent.scissor = col_parent.dst;
	editor_pop_file_id();
}

editor_window_update :: (window : *Editor_Window) {
	
	if window.client_rect {
		window.client_rect.scissor = window.client_rect.dst;
	}
	
	mmpos := os.get_global_mouse_pos(win);
	
	if window.grabbed {
		window.last_grabbed_tick = editor_clock;
		window.pos +=  mmpos - window.last_mpos;
		//print("% % %\n", window.pos, os.get_global_mouse_pos(win), window.last_mpos);
		
		if os.event(window.events, .LMB, .Released) {
			window.grabbed = false;
		}
	}
	
	if window.resize_grabbed {
		window.size += mmpos - window.last_mpos;
		
		window.size.x = clamp_bot(32., window.size.x);
		window.size.y = clamp_bot(32 * 3., window.size.y);
		
		//scratch_window.win_target.size = scratch_window.size;
		
		if os.event(window.events, .LMB, .Released) {
			window.resize_grabbed = false;
			
			if window.flags & .Dialog {
				
			} else {
				window.win_target = r.framebuffer(window.size);
				window.game_target = r.framebuffer(.{1920, 1024});
			}
			
		}
	}
	
	window.last_mpos = mmpos;
}

editor_window_end :: (window : *Editor_Window) {
	assert(window == active_window());
	
	editor_push_file_id(.Editor);
	
	editor_row_end();
	
	if window.flags & .Resizable {
		// scroll bar ====
		if !window.hide {
			ui_push_size_x_node(ui_size_px(32, 1), true);
			ui_push_size_y_node(ui_size_pct(1, 1), true);
			editor_col_begin();
			
			col_parent := active_cxt().parent_stack.top.v;
			col_parent.flags |= .Bg;
			
			editor_spacer(ui_size_pct(1, 0));
			
			ui_push_size_node(ui_size_px(32, 1), true);
			
			if editor_image(r.get_white_square(), color = .{0.698, 0.694, 0.651, 1}).active {
				window.resize_grabbed = true;
			}
			
			editor_row_end();
			// ===============
		}
	}
	
	editor_row_end();
	
	ui_pop_parent_node();
	
	editor_pop_file_id();
	
	// pop from editor window stack
	{
		to_free := editor_window_stack.top;
		editor_window_stack.top = editor_window_stack.top.next;
		
		to_free.next = editor_window_stack.free;
		editor_window_stack.free = to_free;
	}
	
	/*
				if point_in_rect(mpos, window.root.dst) {
					os.event(window.events, .LMB, .Pressed);
					os.event(window.events, .RMB, .Pressed);
					
					os.event(window.events, .LMB, .Released);
					os.event(window.events, .RMB, .Released);
				}
				*/
	
}

editor_label :: (text : string, index := 0, depth : *UI_ID = xx 0, loc := #caller_location) -> UI_Signal {
	
	id := widget_key(index, depth, loc);
	
	out := ui_widget_impl(.Text, id);
	out.widget.text = text;
	
	return out;
}

editor_button :: (text : string, index := 0, depth : *UI_ID = xx 0, loc := #caller_location) -> UI_Signal {
	
	id := widget_key(index, depth, loc);
	
	out := ui_widget_impl(.Text | .Clickable | .Shadow, id);
	out = ui_signal(out.widget);
	
	out.widget.text = text;
	return out;
}

Action_Kind :: enum {
	Null;
	Insert;
	Lost;
}

editor_text_edit :: (display_text : string, action : *Action_Kind, index := 0,
										 depth : *UI_ID = xx 0, loc := #caller_location) -> UI_Signal {
	id := widget_key(index, depth, loc);
	
	out := ui_widget_impl(.Bg | .Text_Edit | .Text, id);
	out.widget.bg_color = .{0.776, 0.776, 0.769, 1};
	
	out = ui_signal(out.widget);
	
	w := out.widget;
	w.text = tprint("%", display_text);
	
	if w.focus {
		// first time focus?
		if w.focus && !w.focus_last {
			w.text_edit_pos = display_text.count;
		}
		
		events := active_window().events;
		event : *os.Event;
		
		{
			// TODO(mizu): Technically, I should walk through each event instead of taking one and dipping because many events can come per frame
			cur := events.first;
			while cur {
				defer cur = cur.next;
				
				if cur.kind == .Pressed {
					event = os.eat_event(events, cur);
					break;
				}
			}
		}
		
		if event {
			if event.key == {
				
				case .ENTER; #through;
				case .LMB;
				w.focus = false;
				
				case .LEFT;
				w.text_edit_pos -= 1;
				
				case .RIGHT;
				w.text_edit_pos += 1;
				
				case .BACK;
				
				if display_text.count > 0 {
					if w.text_edit_pos == display_text.count {
						out.text_edit.data = display_text.data;
						out.text_edit.count = display_text.count - 1;
						w.text = out.text_edit;
						
						<< action = .Insert;
						w.text_edit_pos -= 1;
					} else {
						pre : string;
						pre.data = *w.text.data[0];
						pre.count = w.text_edit_pos - 1;
						
						post : string;
						post.data = *w.text.data[w.text_edit_pos];
						post.count = w.text.count - w.text_edit_pos;
						
						out.text_edit = tprint("%0%0", pre, post);
						
						<< action = .Insert;
						w.text_edit_pos -= 1;
					}
				}
				
				case;
				if event.text {
					
					char : string;
					char.data = *event.char;
					
					if event.shift_held {
						<< char.data = << char.data - 32;
					}
					
					char.count = 1;
					
					if w.text_edit_pos == display_text.count {
						out.text_edit = tprint("%0%0", display_text, char);
						w.text = out.text_edit;
					} else {
						pre : string;
						pre.data = *w.text.data[0];
						pre.count = w.text_edit_pos;
						
						post : string;
						post.data = *w.text.data[w.text_edit_pos];
						post.count = w.text.count - w.text_edit_pos;
						
						out.text_edit = tprint("%0%0%0", pre, char, post);
						
						rerer : int;
					}
					<< action = .Insert;
					w.text_edit_pos += 1;
				}
			}
		}
	}
	
	w.text_edit_pos = clamp_bot(w.text_edit_pos, 0);
	
	w.text_edit_pos = clamp_top(w.text_edit_pos, w.text.count);
	
	return out;
}

editor_check_box :: (checked : *bool, index := 0,
										 depth : *UI_ID = xx 0, loc := #caller_location) -> UI_Signal {
	id := widget_key(index, depth, loc);
	
	out := ui_widget_impl(.Check_Box, id);
	out = ui_signal(out.widget);
	
	if out.active {
		<< checked = ! << checked;
	}
	
	out.widget.checked = << checked;
	return out;
}

editor_slider :: (v : *float, index := 0, depth : *UI_ID = xx 0, loc := #caller_location) -> UI_Signal {
	id := widget_key(index, depth, loc);
	
	out := ui_widget_impl(.Slider, id);
	
	out.widget.value = << v;
	
	return out;
}

editor_image :: (image : r.Handle, src : RectF32 = .{.{0, 0}, .{1, 1}}, color : Vector4 = r.COLOR_WHITE, index := 0, depth : *UI_ID = xx 0, loc := #caller_location) -> UI_Signal {
	id := widget_key(index, depth, loc);
	
	out := ui_widget_impl(.Image, id);
	out = ui_signal(out.widget);
	
	out.widget.image = image;
	out.widget.src = src;
	out.widget.image_color = color;
	
	return out;
}

editor_image_cant_click_lol_bro :: (image : r.Handle, src : RectF32 = .{.{0, 0}, .{1, 1}}, color : Vector4 = r.COLOR_WHITE, index := 0, depth : *UI_ID = xx 0, loc := #caller_location) -> UI_Signal {
	id := widget_key(index, depth, loc);
	
	out := ui_widget_impl(.Image, id);
	
	out.widget.image = image;
	out.widget.src = src;
	out.widget.image_color = color;
	
	return out;
}

active_window_file_id :: () -> Editor_File_Id {
	return active_window().file_id_stack.top.v;
}

editor_row_begin :: (index := 0, depth : *UI_ID = xx 0, loc := #caller_location) -> UI_Signal {
	id := widget_key(index, depth, loc);
	
	out := ui_widget_from_key(id);
	ui_push_parent_node(out);
	out.child_layout_axis = .X;
	
	return .{};
}

editor_col_begin :: (index := 0, depth : *UI_ID = xx 0, loc := #caller_location) -> UI_Signal {
	id := widget_key(index, depth, loc);
	
	out := ui_widget_from_key(id);
	ui_push_parent_node(out);
	out.child_layout_axis = .Y;
	
	return .{};
}

editor_row_end :: () {
	ui_pop_parent_node();
}

editor_spacer :: (size : UI_Size, index := 0, depth : *UI_ID = xx 0, loc := #caller_location) -> UI_Signal {
	id := widget_key(index, depth, loc);
	
	ui_push_size_node(size);
	
	out := ui_widget_impl(0, id);
	ui_pop_size_node();
	
	return out;
}

// TODO(mizu): Ok, will need a smarter method
// Depth isnt nearly enough. Member was stupid. Its basically array index lol. I am thinking instead of depth, I do recursion parent?
// here's another hit, barry bonds??

editor_struct_edit :: (any : Any, depth : *UI_ID = xx 0, index : int = 0) {
	text : string;
	
	ui_push_size_node(ui_size_children_sum(1), true);
	editor_col_begin();
	
	ti := cast(*Type_Info_Struct)any.type;
	
	for member: ti.members {
		
		ui_push_size_node(ui_size_children_sum(1), true);
		editor_row_begin();
		
		ui_push_text_align_node(.Left);
		ui_push_size_x_node(ui_size_px(128, 0));
		ui_push_size_y_node(ui_size_px(24, 1));
		
		text = tprint("%", member.name);
		label_sig := editor_label(text, it_index, depth);
		if !label_sig.toggle {
			//if true {
			
			if it_index == xx active_edit_index {
				ui_push_border_color_node(r.COLOR_ORANGE, true);
			}
			
			field := get_field(ti, member.name);
			
			data := cast(*u8)any.value_pointer + field.offset_in_bytes;
			
			if field.type.type == {
				case .STRING;
				text = tprint("%", << cast(*string)data);
				
				case .FLOAT;
				text = tprint("%", << cast(*float)data);
				ui_push_text_align_node(.Right, true);
			}
			
			if field.type.type == {
				
				case .FLOAT; #through;
				case .STRING;
				action : Action_Kind;
				
				ui_push_size_x_node(ui_size_px(120, 0), true);
				sig := editor_text_edit(text, *action, it_index, depth);
				
				active_edit_index = -1;
				
				if sig.focus {
					active_edit_index = it_index;
				}
				
				if active_edit_index == it_index {
					
					if action == {
						case .Insert;
						
						if field.type.type == {
							case .STRING;
							string_var := cast(*string) data;
							
							free(<< string_var);
							<< string_var = copy_string(sig.text_edit);
							
							case .FLOAT;
							float_var := cast(*float) data;
							
							text_float := string_to_float(sig.text_edit);
							
							<< float_var = text_float;
						}
					}
				}
				
				case .BOOL;
				bool_var := cast(*bool) data;
				
				ui_push_size_x_node(ui_size_px(24, 0), true);
				editor_check_box(bool_var, it_index);
				
				case .STRUCT;
				m_tis := member.type.(*Type_Info_Struct);
				
				if m_tis == type_info(Color) {
					editor_color_picker(0, *label_sig.widget.key);
				} else if m_tis == xx type_info(Pather) {
					action : Action_Kind;
					pather_var := cast(*Pather) data;
					
					sig := editor_filepath_picker(pather_var, *action, index, *label_sig.widget.key);
					if action == {
						case .Insert;
						
						free(pather_var.path);
						
						pather_var.path = copy_string(files[sig.widget.file_index]);
						//<< string_var = ;
						
					}
				} else {
					
					address := (cast(*u8) any.value_pointer) + member.offset_in_bytes;
					
					any2: Any = ---;
					any2.type = member.type;
					any2.value_pointer = address;
					
					editor_struct_edit(any2, *label_sig.widget.key);
				}
				case;
				
				address := (cast(*u8) any.value_pointer) + member.offset_in_bytes;
				
				any2: Any = ---;
				any2.type = member.type;
				any2.value_pointer = address;
				
				text := tprint("%", any2);
				editor_label(text, it_index, *label_sig.widget.key);
			}
		}
		
		ui_pop_size_node();
		ui_pop_text_align_node();
		editor_row_end();
	}
	
	editor_row_end();
}

editor_filepath_picker :: (pather : *Pather, action : *Action_Kind, index := 0,
													 depth : *UI_ID = xx 0, loc := #caller_location) -> UI_Signal {
	id := widget_key(index, depth, loc);
	
	ui_push_size_x_node(ui_size_px(164, 1), true);
	ui_push_size_y_node(ui_size_children_sum(), true);
	editor_col_begin();
	
	ui_push_size_x_node(ui_size_pct(1));
	
	out := ui_widget_impl(.Clickable | .Text, id);
	out = ui_signal(out.widget);
	
	found, left, right := split_from_right(pather.path, #char "/");
	out.widget.text = right;
	
	if out.toggle {
		
		for files {
			
			ext := path_extension(it);
			
			if ext == {
				case "png"; #through;
				case "jpg"; #through;
				case "jpeg";
				
				found, left, right := split_from_right(it, #char "/");
				
				if editor_button(right, it_index, depth).active {
					out.widget.file_index = it_index;
					<< action = .Insert;
					out.widget.toggle = false;
				}
			}
		}
		
		//ui_pop_parent_node();
		
	}
	ui_pop_size_x_node();
	editor_row_end();
	
	return out;
}

editor_color_picker :: (index := 0,
												depth : *UI_ID = xx 0, loc := #caller_location) -> UI_Signal {
	id := widget_key(index, depth, loc);
	
	out := ui_widget_impl(.Text, id);
	
	out.widget.text = "TODO";
	
	return out;
}

draw_children :: (passes : *r.Pass_List, root : *UI_Widget) {
	
	if root.flags & .Scissor {
		
		scissor1 := passes.last.scissor;
		scissor2 := root.scissor;
		
		scissor2.min.x = max(scissor1.min.x, scissor2.min.x);
		scissor2.min.y = max(scissor1.min.y, scissor2.min.y);
		scissor2.max.x = min(scissor1.max.x, scissor2.max.x);
		scissor2.max.y = min(scissor1.max.y, scissor2.max.y);
		
		r.push_scissor(passes, scissor2);
	}
	
	color := r.COLOR_WHITE;
	font_size := 1.;
	
	if root.hot {
		color = root.hover_color;
	}
	
	if root.flags & .Slider {
		// bar
		{
			dst := root.dst;
			color := Vector4.{0.776, 0.776, 0.769, 1};
			
			if root.hot {
				color *= 1.2;
			}
			
			r.push_rect2(passes, dst, color);
		}
		
		// notch
		{
			dst := root.dst;
			dst.max.x = dst.min.x + root.size.y;
			dst.min.x += root.value * root.size.x;
			dst.max.x += root.value * root.size.x;
			
			dst.min.x -= 8;
			dst.max.x -= 8;
			r.push_rect2(passes, dst, .{0.1, 0.4, 0.8, 0.3});
		}
		
		// slider text value
		{
			text_pos := root.pos;
			text_pos.x += root.size.x / 2;
			text_pos.x -= 13;
			text_pos.y += 2;
			text := tprint("%", root.value);
			
			//r.push_scissor(passes, root.dst);
			r.push_text(passes, font, text, text_pos, 1., r.COLOR_WHITE);
			//r.pop_scissor(passes);
		}
	}
	
	if root.flags & .Bg {
		img := r.push_rect2(passes, root.dst, root.bg_color);
		img.border_color = .{0.545, 0.541, 0.498, 1};
		img.border_thickness = 3.5;;
	}
	
	text_pos_delta : Vector2;
	button_dst := root.dst;
	
	if root.flags & .Shadow {
		dst := root.dst;
		
		dst_off := dst;
		dst_off.min.x += 1.5;
		dst_off.min.y += 1.5;
		dst_off.max.x += 1.5;
		dst_off.max.y += 1.5;
		sh := r.push_rect2(passes, dst_off, .{0, 0, 0, 0.4});
	}
	
	if root.flags & .Offset {
		text_pos_delta.x += 1.5;
		text_pos_delta.y += 1.5;
		
		button_dst.min.x += 1.5;
		button_dst.min.y += 1.5;
		button_dst.max.x += 1.5;
		button_dst.max.y += 1.5;
	}
	
	if root.flags & .Clickable {
		//font_size = 0.9;
		bg := r.push_rect2(passes, button_dst, .{0.698, 0.694, 0.651, 1});
		bg.border_thickness = 3;
		bg.border_color = .{0.459, 0.439, 0.402, 1};
	}
	
	if root.flags & .Image {
		img := r.push_rect2(passes, root.dst, root.image_color);
		img.tex_id = root.image.U64[1];
		img.src = root.src;
		img.border_thickness = 3;
		img.border_color = .{0.545, 0.541, 0.498, 1};
	}
	
	if root.flags & .Check_Box {
		dst := root.dst;
		
		cb_bg := r.push_rect2(passes, dst, color);
		cb_bg.border_color = r.COLOR_BLACK;
		cb_bg.border_thickness = 3;
		
		if root.checked {
			cb := r.push_rect2(passes, dst, r.COLOR_MAGENTA);
			cb.border_color = r.COLOR_WHITE;
			cb.border_thickness = 4;
			cb.radius = 4;
		}
		
	}
	
	if root.flags & .Text {
		text_rect := r.get_text_rect(font, root.text, .{}, font_size);
		text_height := text_rect.max.y - text_rect.min.y;
		
		if root.size.y > text_height {
			text_pos_delta.y += (root.size.y - text_height) / 2;
		}
		
		if root.text_align == .Middle {
			text_width := text_rect.max.x - text_rect.min.x;
			if root.size.x > text_width {
				text_pos_delta.x += (root.size.x - text_width) / 2;
			}
		} else if root.text_align == .Left {
			text_pos_delta.x += 4;
		} else if root.text_align == .Right {
			text_width := text_rect.max.x - text_rect.min.x;
			
			if root.size.x > text_width {
				text_pos_delta.x += root.size.x - text_width - 4;
			}
			
		}
		
		r.push_text(passes, font, root.text, root.pos + text_pos_delta, font_size, .{0.459, 0.439, 0.402, 1});
	}
	
	if root.flags & .Text_Edit {
		if root.focus {
			before_cursor_text := root.text;
			before_cursor_text.count = root.text_edit_pos;
			
			text_rect := r.get_text_rect(font, before_cursor_text, .{}, 1);
			
			dst := root.dst;
			dst.min.x += text_rect.max.x + text_pos_delta.x;
			dst.max.x = dst.min.x + 4;
			
			r.push_rect2(passes, dst, color);
		}
	}
	
	{
		child :=  root.first;
		while child {
			draw_children(passes, child);
			child = child.next;
		}
	}
	
	if root.flags & .Scissor {
		r.pop_scissor(passes);
	}
}