#if OS == .WINDOWS #import "Windows";

#import "freetype255";
#import "Basic";
#import "Compiler";
#import "File";
#import "stb_image_write";
r :: #import "render";

build :: () {
	options := get_build_options();
	args := options.compile_time_command_line;
	print("args: %\n", args);
	
	if !args {
		w := compiler_create_workspace("winter");
		target_options := get_build_options(w);
		target_options.backend = .X64;
		target_options.output_executable_name = "winter";
		target_options.output_path = ".build/";
		set_build_options(target_options, w);
		
		compiler_begin_intercept(w);
		add_build_file("src/main.jai", w);
		
		message_loop();
		compiler_end_intercept(w);
		
#if OS == .WINDOWS
			file_link(".build/SDL2.dll", "bin/SDL2.dll");
	}
	
	for args {
		if it == "clean" {
			delete_directory(".build/");
		}
	}
	
	set_build_options_dc(.{do_output=false});
	
	font := init_font("data/fonts/delius.ttf", 16);
	
	str : string;
	str.data = xx *font;
	str.count = size_of(type_of(font));
	
	write_entire_file("data/fonts/font.data", str);
	stbi_write_png("data/fonts/font.png", font.w, font.h, font.n, font.data, font.w * font.n);
}

#run build();
render_import : *Message_Import;

message_loop :: () {
	
	while true {
		message := compiler_wait_for_message();
		if message.kind == {
			case .IMPORT;
			import := cast(*Message_Import)message;
			if import.module_name == "render"
				render_import = import;
			
			case .TYPECHECKED;
			typechecked := cast(*Message_Typechecked) message;
			for typechecked.structs
				note_struct(it.expression);
			case .PHASE;
			phase := cast(*Message_Phase) message;
			if phase.phase == .TYPECHECKED_ALL_WE_CAN {
				if !generated_code {
					generate_code(message.workspace);
					generated_code = true;
				}
			}
			
			case .COMPLETE;
			break;
		}
	}
}

generated_code := false;

Style :: struct {
	name : string;
	type : string;
	
	Name : string;
}

upper_snake_from_lower_snake :: (name : string) -> string {
	
	out := copy_string(name);
	
	out.data[0] = to_upper(name.data[0]);
	
	for 1 .. out.count - 1 {
		if out.data[it] == #char "_"{
			out.data[it] = to_upper(name.data[it]);
		}
	}
	
	return out;
}

styles : [12]Style = .[.{"parent", "*UI_Widget", ""},
											 .{"size_x", "UI_Size", ""},
											 .{"size_y", "UI_Size", ""},
											 .{"offset", "[2]float32", ""},
											 .{"scissor", "RectF32", ""},
											 .{"flags", "UI_Flags", ""},
											 .{"text_padding", "float32", ""},
											 .{"bg_color", "Vector4", ""},
											 .{"text_align", "UI_Text_Align", ""},
											 .{"border_color", "Vector4", ""},
											 .{"hover_color", "Vector4", ""},
											 .{"passes", "*r.Pass_List", ""}];

STYLES_TEMPLATE :: #string DONE
UI_%2_Node :: struct {
	next : *UI_%2_Node;
	v : %3;
	auto : bool;
}
DONE

PUSH_TEMPLATE :: #string DONE
ui_push_%1_node :: (v : %3, auto : bool = false) {
	node : *UI_%2_Node = xx tpush_struct(UI_%2_Node);
	node.v = v;
	node.next = active_cxt.%1_stack.top;
	node.auto = auto;
	active_cxt.%1_stack.top = node;
}
DONE

POP_TEMPLATE :: #string DONE
ui_pop_%1_node :: () {
	active_cxt.%1_stack.top = active_cxt.%1_stack.top.next;
}
DONE

UI_STATE_TEMPLATE :: #string DONE
UI_State :: struct {
	arena : *Arena;
	slots : []Slot;
	frame_index : u64;
	free : *UI_Widget;
	count : u32;
	mpos : Vector2;
	events : *os.EventList;
	atleast_one_hot : bool;
	atleast_one_hot_last : bool;
	
	%1;
	
	root : *UI_Widget;
}
DONE

UI_STACKS_TEMPLATE :: #string DONE

%1_stack : struct {
	top : *UI_%2_Node;
	free : *UI_%2_Node;
	auto_pop : bool;
};

DONE

AUTO_POP_TEMPLATE :: #string DONE
if active_cxt.%_stack.top.auto {
	ui_pop_%_node();
}
DONE

MEGA_AUTO_POP_TEMPLATE :: #string DONE
ui_auto_pop :: () {
	%
}
DONE

AUTO_STYLING :: #string DONE
out.
DONE

generate_styles :: () -> string {
	builder: String_Builder;
	builder2: String_Builder;
	builder3: String_Builder;
	
	for *styles {
		it.Name = upper_snake_from_lower_snake(it.name);
		//print("%\n", it.Name);
	}
	
	for styles {
		
		print_to_builder(*builder, STYLES_TEMPLATE, it.name, it.Name, it.type);
		print_to_builder(*builder, PUSH_TEMPLATE, it.name, it.Name, it.type);
		print_to_builder(*builder, POP_TEMPLATE, it.name, it.Name, it.type);
		
		print_to_builder(*builder2, UI_STACKS_TEMPLATE, it.name, it.Name, it.type);
		print_to_builder(*builder3, AUTO_POP_TEMPLATE, it.name, it.name);
	}
	
	stacks := builder_to_string(*builder2);
	auto_pops := builder_to_string(*builder3);
	
	print_to_builder(*builder2, UI_STATE_TEMPLATE, stacks);
	print_to_builder(*builder3, MEGA_AUTO_POP_TEMPLATE, auto_pops);
	
	state := builder_to_string(*builder2);
	mega_auto_pops := builder_to_string(*builder3);
	
	print_to_builder(*builder, "%\n%", state, mega_auto_pops);
	
	return builder_to_string(*builder);
}

generate_code :: (w : Workspace) {
	//print("%", generate_styles());
	
	if render_import {
		add_build_string("codex : int = 3;", w,  render_import);
	} else {
		print("couldn't find render module\n");
	}
	
	add_build_string(generate_styles(), w);
}

note_struct :: (code_struct: *Code_Struct) {
	//print("%\n", << code_struct.block);
}

init_font :: (path : string, font_size : u32) -> r.Font {
	
	font_file_data := read_entire_file(path);
	
	out : r.Font;
	out.size = font_size;
	library : *FT_Library;
	FT_Init_FreeType(*library);
	
	face : FT_Face;
	FT_New_Memory_Face(library, font_file_data.data, xx font_file_data.count, 0, *face);
	FT_Set_Pixel_Sizes(face, 0, font_size);
	
	out.ascent = face.size.metrics.ascender >> 6;
	out.descent = face.size.metrics.descender >> 6;
	out.line_height = (face.size.metrics.ascender - face.size.metrics.descender) >> 6;
	
	padding : int = 1;
	row : int;
	col := padding;
	
	temp_buffer : *u8 = talloc(out.w * out.h);
	
	for i : 32 .. 126 {
		glyph_index := FT_Get_Char_Index(face, xx i);
		
		FT_Load_Glyph(face, glyph_index, FT_LOAD_RENDER);
		
		if(col + face.glyph.bitmap.width + padding >= out.w) {
			col = padding;
			row += font_size;
		}
		
		// copy to buffer
		
		for y : 0 .. face.glyph.bitmap.rows - 1 {
			for x : 0 .. face.glyph.bitmap.width - 1 {
				
				temp_buffer[(row + y) * out.w + col + x] = face.glyph.bitmap.buffer[y * face.glyph.bitmap.width + x];
			}
		}
		
		glyph := *out.glyphs[i];
		glyph.uv.x = xx col;
		glyph.uv.y = xx row;
		glyph.size.x = xx face.glyph.bitmap.width;
		glyph.size.y = xx face.glyph.bitmap.rows;
		glyph.advance.x = xx face.glyph.advance.x >> 6;
		glyph.advance.y = xx face.glyph.advance.y >> 6;
		glyph.offset.x = xx face.glyph.bitmap_left;
		glyph.offset.y = xx face.glyph.bitmap_top;
		
		col += face.glyph.bitmap.width + padding;
	}
	
	FT_Done_Face(face);
	FT_Done_FreeType(library);
	
	out.data = talloc(out.w * out.h * out.n); 
	
	dest_row :*u8= out.data;
	//src_row := temp_buffer + out.w * (out.h - 1);
	src_row := temp_buffer + out.w * (out.h - 1);
	
	for y : 0 .. out.h - 1 {
		dest :*u32 = xx dest_row;
		src := src_row;
		
		for x : 0 .. out.w - 1 {
			alpha :s64= <<src;
			a :s64= alpha << 24;
			b :: 0xFF << 16;
			g :: 0xFF << 8;
			r :: 0xFF;
			
			color := a | b | g | r;
			
			dest_pixel :*s64= xx dest; 
			<< dest_pixel = color;
			
			src += 1;
			dest += 1;
		}
		dest_row += 4 * out.w;
		src_row -= out.w;
	}
	
	return out;
}