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
		target_options.output_executable_name = "winter";
		target_options.output_path = ".build/";
		set_build_options(target_options, w);
		
		add_build_file("src/main.jai", w);
		
#if OS == .WINDOWS
			file_link(".build/SDL2.dll", "bin/SDL2.dll");
	}
	
	for args {
		if it == "clean" {
			delete_directory(".build/");
		}
	}
	
	set_build_options_dc(.{do_output=false});
	
	font := init_font("data/fonts/delius.ttf", 64);
	
	str : string;
	str.data = xx *font;
	str.count = size_of(type_of(font));
	
	write_entire_file("data/fonts/font.data", str);
	stbi_write_png("data/fonts/font.png", font.w, font.h, font.n, font.data, font.w * font.n);
}

#run build();

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
	
	padding : int;
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