#import "mizu_base";
#import "System";
#import "String";
#import "GL" (ENABLE_ALL_EXTENSIONS = true);

os :: #import "os";
#import "Basic";
#import "File";
#import "Math";

Scene_Data :: struct {
	screen_size : Vector2;
	screen_offset : Vector2;
	noise_id : u64;
	displacement_id : u64;
	pad : Vector2;
	delta : float;
	pad2 : float;
	draw_id : u64;
	water_id : u64;
	light_id : u64;
};

Image :: struct {
	id : GLuint;
	resident : GLuint64;
	w : u32;
	h : u32;
	next : *Image;
};

Framebuffer :: struct {
	// fb id
	id : GLuint;
	
	// color tex
	tex : GLuint;
	resident : GLuint64;
	
	// depth stencil rbo
	depth_stencil : GLuint;
	
	size : Vector2;
}

framebuffer :: (size : Vector2) -> Framebuffer {
	out : Framebuffer;
	out.size = size;
	
	glCreateFramebuffers(1, *out.id);
	width : u32 = xx size.x;
	height : u32 = xx size.y;
	
	// color attachment
	{
		glCreateTextures(GL_TEXTURE_2D, 1, *out.tex);
		glTextureParameteri(out.tex, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTextureParameteri(out.tex, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTextureStorage2D(out.tex, 1, GL_RGB8, width, height);
		
		resident := glGetTextureHandleARB(out.tex);
		glMakeTextureHandleResidentARB(resident);
		out.resident = resident;
		glNamedFramebufferTexture(out.id, GL_COLOR_ATTACHMENT0, out.tex, 0);
	}
	
	// depth and stencil attachment
	{
		renderbuffer : GLuint;
		glCreateRenderbuffers(1, *renderbuffer);
		glNamedRenderbufferStorage(renderbuffer, GL_DEPTH24_STENCIL8, width, height);
		glNamedFramebufferRenderbuffer(out.id, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, renderbuffer);
	}
	status := glCheckNamedFramebufferStatus(out.id, GL_FRAMEBUFFER);
	
	assert(status == GL_FRAMEBUFFER_COMPLETE, "fb not complete");
	return out;
}

size_from_image :: (h : Handle) -> Vector2i {
	img := h.U64[0];
	
	out : Vector2i;
	out.x = img.w;
	out.y = img.h;
	
	return out;
}

INST_BUFFER :: enum {
	UI;
	SPRITE;
	LIGHT;
	COUNT;
};

SHADER_PROG :: enum {
	UI;
	SPRITE;
	BEAM;
	WATER;
	FINAL;
	Light;
	GRID;
	COUNT;
};

vert_shader_paths :[SHADER_PROG.COUNT]string: .["ui.vert",
																								"sprite.vert",
																								"beam.vert",
																								"water.vert",
																								"final.vert",
																								"light.vert",
																								"grid.vert"
																								];

frag_shader_paths :[SHADER_PROG.COUNT]string: .["ui.frag",
																								"sprite.frag",
																								"beam.frag",
																								"water.frag",
																								"final.frag",
																								"light.frag",
																								"grid.frag"
																								];

State :: struct {
	arena : *Arena;
	
	scene_buffer : GLuint;
	shader_prog : [SHADER_PROG.COUNT] GLuint;
	inst_buffer : [INST_BUFFER.COUNT] GLuint;
	white_square : Handle;
	
	water_fb : Framebuffer;
	light_fb : Framebuffer;
	
	last_screen_size : Vector2;
	
	noise_id : Handle;
	displacement_id : Handle;
	
	free_images : *Image;
	
	base_path : string;
	shaders_folder : string;
	grid_buffer : GLuint;
};

state : *State;

using gl;

get_white_square :: inline () -> Handle {
	return state.white_square;
}

init :: (screen_size : Vector2) {
	arena := arena_init();
	state = push_struct(arena, State);
	state.arena = arena;
	
	print ("GL Vendor = %\n", to_string(glGetString(GL_VENDOR)));
	print ("GL Version = %\n", to_string(glGetString(GL_VERSION)));
	
	stupid_fucking_opengl : GLuint;
	glCreateVertexArrays(1, *stupid_fucking_opengl);
	glBindVertexArray(stupid_fucking_opengl);
	
	state.base_path = path_strip_filename(get_path_of_running_executable());
	state.shaders_folder = join(state.base_path, "../shaders");
	
	compile_shaders();
	
	for i : 0 .. INST_BUFFER.COUNT - 1 {
		state.inst_buffer[i] = make_buffer(MB(8));
	}
	
	state.scene_buffer = make_buffer(size_of(Scene_Data));
	state.grid_buffer = make_buffer(size_of(Grid));
	
	data : [1]s64 : .[0xFFFFFFFF];
	
	bmp := Bitmap.{data.data, 1, 1, 4};
	
	state.white_square = image(bmp);
	
	{
		// NOTE(mizu): :>
		state.water_fb = framebuffer(screen_size);
		state.light_fb = framebuffer(screen_size);
	}
	
	{
		data_folder := join(state.base_path, "../data/renderer");
		
		renderer_art_paths : [2]string = .["displacement.png",
																			 "noise.png"];
		
		for renderer_art_paths {
			
			filename := tprint("%/%", data_folder, it);
			data := read_entire_file(filename);
			defer free(data);
			
			bmp := bitmap(data);
			img := image(bmp);
			
			if it_index == 0 {
				state.displacement_id = img;
			} else {
				state.noise_id = img;
			}
			
		}
	}
}

uvec2_from_u64 :: (v : u64) -> u32, u32 {
	l : u32 = cast(u32) (v & 0xFFFFFFFF); 
	r: u32 = cast(u32) (v >> 32);
	
	return l, r;
}

present :: (target : Framebuffer, win : os.Handle) {
	
	screen_size := os.get_window_size(win);
	
	// copy to window fb
	{
		glBindFramebuffer(GL_FRAMEBUFFER, 0);
		glClear(GL_COLOR_BUFFER_BIT);
		glViewport(0, 0, xx screen_size.x, xx screen_size.y);
		shader := state.shader_prog[SHADER_PROG.FINAL];
		glUseProgram(shader);
		
		offset_loc := glGetUniformLocation(shader, "u_image_id");
		
		draw_fb_id := target.resident;
		
		l, r := uvec2_from_u64(draw_fb_id);
		
		glUniform2ui(offset_loc, l, r);
		
		glDrawArrays(GL_TRIANGLES, 0, 6);
	}
	
	os.swap_buffers(win);
}

submit :: (delta : float, target : Framebuffer, screen_size : Vector2,
					 passes : Pass_List,
					 screen_offset := Vector2.{0, 0}) {
	glBindFramebuffer(GL_FRAMEBUFFER, target.id);
	
	glViewport(0, 0, xx target.size.x, xx target.size.y);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	
	glClearColor(0.2, 0.2, 0.3, 1.0);
	glClear(GL_COLOR_BUFFER_BIT);
	glEnable(GL_BLEND);
	
	// scene buffer
	{
		scene_data : Scene_Data;
		scene_data.screen_size = .{screen_size.x, screen_size.y};
		scene_data.screen_offset = screen_offset;
		scene_data.noise_id = state.noise_id.U64[1];
		scene_data.displacement_id = state.displacement_id.U64[1];
		scene_data.delta = delta;
		scene_data.draw_id = target.resident;
		scene_data.water_id = state.water_fb.resident;
		scene_data.light_id = state.light_fb.resident;
		
		using state;
		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, scene_buffer);
		ssbo_data : *u8 = glMapNamedBufferRange(scene_buffer, 0, size_of(Scene_Data), GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
		
		memcpy(ssbo_data, *scene_data, size_of(Scene_Data));
		
		glUnmapNamedBuffer(scene_buffer);
	}
	
	// passes
	{
		pass := passes.first;
		while pass {
			defer pass = pass.next;
			
			if pass.kind == {
				case .UI;
				buffer := state.inst_buffer[INST_BUFFER.UI];
				shader := state.shader_prog[SHADER_PROG.UI];
				
				size : Vector2i;
				size.x = xx (pass.scissor.max.x - pass.scissor.min.x);
				size.y = xx (pass.scissor.max.y - pass.scissor.min.y);
				
				br: Vector2i;
				br.x = xx pass.scissor.min.x;
				br.y = xx (target.size.y - pass.scissor.max.y);
				
				//glEnable(GL_SCISSOR_TEST);
				
				if size.x >= 0 && size.y >= 0 {
					glScissor(xx br.x, xx br.y, xx size.x, xx size.y);
				}
				glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, buffer);
				glUseProgram(shader);
				
				batches := pass.batches;
				batch := batches.first;
				while batch	{
					ssbo_data : *u8 = glMapNamedBufferRange(buffer, 0, batch.size, GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
					
					memcpy(ssbo_data, batch.base, batch.size);
					
					glUnmapNamedBuffer(buffer);
					
					glDrawArraysInstanced(GL_TRIANGLES, 0, 6, batch.count);
					
					batch = batch.next;
				}
				glDisable(GL_SCISSOR_TEST);
				
				case .Beam;
				shader := state.shader_prog[SHADER_PROG.BEAM];
				glUseProgram(shader);
				
				offset_loc := glGetUniformLocation(shader, "u_offset");
				
				glUniform2fv(offset_loc, 1, *pass.beam_pos.component[0]);
				
				glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
				
				case .Begin_Water;
				glBindFramebuffer(GL_FRAMEBUFFER, state.water_fb.id);
				glClearColor(0., 0., 0., 1.0);
				glClear(GL_COLOR_BUFFER_BIT);
				
				case .End_Water;
				shader := state.shader_prog[SHADER_PROG.WATER];
				glUseProgram(shader);
				
				glBindFramebuffer(GL_FRAMEBUFFER, target.id);
				
				glDrawArrays(GL_TRIANGLES, 0, 6);
				
				case .Sprite;
				buffer := state.inst_buffer[INST_BUFFER.SPRITE];
				shader := state.shader_prog[SHADER_PROG.SPRITE];
				
				glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, buffer);
				glUseProgram(shader);
				
				batches := pass.batches;
				batch := batches.first;
				while batch	{
					ssbo_data : *u8 = glMapNamedBufferRange(buffer, 0, batch.size, GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
					
					memcpy(ssbo_data, batch.base, batch.size);
					
					glUnmapNamedBuffer(buffer);
					
					glDrawArraysInstanced(GL_TRIANGLES, 0, 6, batch.count);
					
					batch = batch.next;
				}
				
				case .Grid;
				shader := state.shader_prog[SHADER_PROG.GRID];
				glUseProgram(shader);
				
				buffer := state.grid_buffer;
				
				glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, buffer);
				
				ssbo_data : *u8 = glMapNamedBufferRange(buffer, 0, size_of(type_of(pass.grid)), GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
				
				memcpy(ssbo_data, *pass.grid, size_of(type_of(pass.grid)));
				
				glUnmapNamedBuffer(buffer);
				glDrawArrays(GL_TRIANGLES, 0, 6);
				
				case .Light;
				
				// draw lights to light fb.
				// samples draw fb
				{
					shader := state.shader_prog[SHADER_PROG.Light];
					glUseProgram(shader);
					
					buffer := state.inst_buffer[INST_BUFFER.LIGHT];
					
					glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, buffer);
					
					ssbo_data : *u8 = glMapNamedBufferRange(buffer, 0, size_of(type_of(pass.light)), GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
					
					memcpy(ssbo_data, *pass.light, size_of(type_of(pass.light)));
					
					glUnmapNamedBuffer(buffer);
					
					glBindFramebuffer(GL_FRAMEBUFFER, state.light_fb.id);
					
					glDrawArrays(GL_TRIANGLES, 0, 6);
				}
				
				// copy to draw fb
				{
					shader := state.shader_prog[SHADER_PROG.FINAL];
					glUseProgram(shader);
					
					offset_loc := glGetUniformLocation(shader, "u_image_id");
					
					draw_fb_id := state.light_fb.resident;
					
					l, r := uvec2_from_u64(draw_fb_id);
					
					glUniform2ui(offset_loc, l, r);
					
					glBindFramebuffer(GL_FRAMEBUFFER, target.id);
					glClear(GL_COLOR_BUFFER_BIT);
					
					glDrawArrays(GL_TRIANGLES, 0, 6);
				}
				
			}
		}
	}
}

check_compile_errors :: (shader : GLuint, type : *u8) {
	success : s32;
	infoLog: [1024]u8;
	
	glGetShaderiv(shader, GL_COMPILE_STATUS, *success);
	if !success {
		glGetShaderInfoLog(shader, 1024, xx 0, xx infoLog.data);
		print("% compilation error:\n%\n", to_string(type), to_string(infoLog.data));
		assert(false);
	}
}

check_link_errors :: (shader : GLuint, type : *u8) {
	success : s32;
	infoLog : [1024]u8;
	glGetProgramiv(shader, GL_LINK_STATUS, *success);
	if !success {
		glGetProgramInfoLog(shader, 1024, xx 0, xx infoLog.data);
		print("% linking error:\n%\n", to_string(type), to_string(infoLog.data));
		assert(false);
	}
}

make_shader_program :: (vertexShaderSource : string, fragmentShaderSource : string) -> GLuint {
	vert_shader := glCreateShader(GL_VERTEX_SHADER);
	glShaderSource(vert_shader, 1, *(vertexShaderSource.data), xx 0);
	glCompileShader(vert_shader);
	
	check_compile_errors(vert_shader, "vertex shader");
	
	frag_shader := glCreateShader(GL_FRAGMENT_SHADER);
	glShaderSource(frag_shader, 1, *(fragmentShaderSource.data), xx 0);
	glCompileShader(frag_shader);
	check_compile_errors(frag_shader, "fragment shader");
	
	shader_prog := glCreateProgram();
	glAttachShader(shader_prog, vert_shader);
	glAttachShader(shader_prog, frag_shader);
	
	glLinkProgram(shader_prog);
	check_link_errors(shader_prog, "vert/frag shader");
	
	glDeleteShader(vert_shader);
	glDeleteShader(frag_shader);
	
	return shader_prog;
}

make_buffer :: (size : u64) -> GLuint {
	ssbo : GLuint;
	glCreateBuffers(1, *ssbo);
	glNamedBufferData(ssbo, xx size, xx 0, GL_STREAM_DRAW);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, ssbo);
	
	return ssbo;
}

image :: (bmp : Bitmap, params := Tex_Params.Nearest) -> Handle {
	img : *Image = state.free_images;
	
	if img {
		state.free_images = state.free_images.next;
	} else {
		img = push_struct(state.arena, Image);
	}
	
	<< img = .{};
	
	id : GLuint;
	glCreateTextures(GL_TEXTURE_2D, 1, *id);
	
	if params == .Linear {
		glTextureParameteri(id, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTextureParameteri(id, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	} else {
		glTextureParameteri(id, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTextureParameteri(id, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	}
	
	glTextureStorage2D(id, 1, GL_RGBA32F, xx bmp.w, xx bmp.h);
	if bmp.data {
		glTextureSubImage2D(id, 0, 0, 0, xx bmp.w, xx bmp.h, GL_RGBA, GL_UNSIGNED_BYTE, bmp.data);
	}
	glTextureParameteri(id, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTextureParameteri(id, GL_TEXTURE_WRAP_T, GL_REPEAT);
	
	resident := glGetTextureHandleARB(id);
	glMakeTextureHandleResidentARB(resident);
	
	img.id = id;
	img.resident = resident;
	img.w = xx bmp.w;
	img.h = xx bmp.h;
	out : Handle;
	out.U64[0] = xx img;
	out.U64[1] = xx resident;
	
	out.U32[0] = xx bmp.w;
	out.U32[1] = xx bmp.h;
	
	return out;
}

// store free image node
free_image :: (handle : Handle) {
	image : *Image = xx handle.U64[0];
	glMakeTextureHandleNonResidentARB(image.resident);
	glDeleteTextures(1, *image.id);
	
	image.next = state.free_images;
	state.free_images = image;
}

free_shaders :: () {
	for i : 0 .. SHADER_PROG.COUNT - 1 {
		glDeleteShader(state.shader_prog[i]);
	}
}

compile_shaders :: () {
	for i : 0 .. SHADER_PROG.COUNT - 1 {
		
		vert_abs_path := tprint("%/%", state.shaders_folder, vert_shader_paths[i]);
		
		vert_shader_file := read_entire_file(vert_abs_path, true);
		defer free(vert_shader_file);
		
		frag_abs_path := tprint("%/%", state.shaders_folder, frag_shader_paths[i]);
		
		frag_shader_file := read_entire_file(frag_abs_path, true);
		defer free(frag_shader_file);
		
		state.shader_prog[i] = make_shader_program(vert_shader_file, frag_shader_file);
	}
}
