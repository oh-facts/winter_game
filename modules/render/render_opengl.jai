#import "mizu_base";

#import "GL" (ENABLE_ALL_EXTENSIONS = true);

os :: #import "os";
#import "Basic";
#import "SDL";
#import "File";
#import "Math";

ui_vertex_shader := #run read_entire_file("shaders/ui.vert"); 
ui_frag_shader := #run read_entire_file("shaders/ui.frag");

sprite_vertex_shader := #run read_entire_file("shaders/sprite.vert"); 
sprite_frag_shader := #run read_entire_file("shaders/sprite.frag");

beam_vertex_shader := #run read_entire_file("shaders/beam.vert"); 
beam_frag_shader := #run read_entire_file("shaders/beam.frag");

SceneData :: struct {
	screen_size : Vector2;
	screen_offset : Vector2;
};

Image :: struct {
	id : GLuint;
	resident : GLuint64;
	w : u32;
	h : u32;
};

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
	COUNT;
};

SHADER_PROG :: enum {
	UI;
	SPRITE;
	BEAM;
	COUNT;
};

State :: struct {
	arena : *Arena;
	
	scene_buffer : GLuint;
	shader_prog : [SHADER_PROG.COUNT] GLuint;
	inst_buffer : [INST_BUFFER.COUNT] GLuint;
	white_square : Handle;
};

state : *State;

using gl;

get_white_square :: inline () -> Handle {
	return state.white_square;
}

init :: () {
	arena := arena_init();
	state = push_struct(arena, State);
	state.arena = arena;
	
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);
	SDL_GL_SetAttribute(SDL_GL_FRAMEBUFFER_SRGB_CAPABLE, 1);
	
	glEnable(GL_FRAMEBUFFER_SRGB);
	
	gl_load(*gl, SDL_GL_GetProcAddress);
	
	print ("GL Vendor = %\n", to_string(glGetString(GL_VENDOR)));
	print ("GL Version = %\n", to_string(glGetString(GL_VERSION)));
	
	stupid_fucking_opengl : GLuint;
	glCreateVertexArrays(1, *stupid_fucking_opengl);
	glBindVertexArray(stupid_fucking_opengl);
	
	SDL_GL_SetSwapInterval(1);
	
	vert_files : []string = .[
														ui_vertex_shader,
														sprite_vertex_shader,
														beam_vertex_shader
														];
	
	frag_files : []string = .[
														ui_frag_shader,
														sprite_frag_shader,
														beam_frag_shader
														];
	
	for i : 0 .. SHADER_PROG.COUNT - 1 {		
		state.shader_prog[i] = make_shader_program(vert_files[i].data, frag_files[i].data);
	}
	
	for i : 0 .. INST_BUFFER.COUNT - 1 {		
		state.inst_buffer[i] = make_buffer(MB(8));
	}
	
	
	state.scene_buffer = make_buffer(size_of(SceneData));
	
	data : []s64 = .[0xFFFFFFFF];
	
	bmp := Bitmap.{data.data, 1, 1, 4};
	
	state.white_square = image(bmp);
}

submit :: (win : os.Handle, screen_size : Vector2, ui_batches : BatchList, sprite_batches : BatchList,
					 screen_offset := Vector2.{0, 0}) {
	
	glViewport(0, 0, xx screen_size.x, xx screen_size.y);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glEnable(GL_BLEND);
	
	glClearColor(1., 0, 1., 1.);
	glClear(GL_COLOR_BUFFER_BIT);
	
	// scene buffer
	{
		scene_data : SceneData;
		scene_data.screen_size = .{screen_size.x, screen_size.y};
		scene_data.screen_offset = screen_offset;
		
		using state;
		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, scene_buffer);
		ssbo_data : *u8 = glMapNamedBufferRange(scene_buffer, 0, size_of(SceneData), GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
		
		memcpy(ssbo_data, *scene_data, size_of(SceneData));
		
		glUnmapNamedBuffer(scene_buffer);
	}
	
	// sprite pass
	{
		buffer := state.inst_buffer[INST_BUFFER.SPRITE];
		shader := state.shader_prog[SHADER_PROG.SPRITE];
		
		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, buffer);
		glUseProgram(shader);
		
		batch := sprite_batches.first;
		while batch	{
			ssbo_data : *u8 = glMapNamedBufferRange(buffer, 0, batch.size, GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
			
			memcpy(ssbo_data, batch.base, batch.size);
			
			glUnmapNamedBuffer(buffer);
			
			glDrawArraysInstanced(GL_TRIANGLES, 0, 6, batch.count);
			
			batch = batch.next;
		}
	}
	
	// beam
	{
		shader := state.shader_prog[SHADER_PROG.BEAM];
		glUseProgram(shader);
		glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
	}
	
	// ui pass
	{
		buffer := state.inst_buffer[INST_BUFFER.UI];
		shader := state.shader_prog[SHADER_PROG.UI];
		
		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, buffer);
		glUseProgram(shader);
		
		batch := ui_batches.first;
		while batch	{
			ssbo_data : *u8 = glMapNamedBufferRange(buffer, 0, batch.size, GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
			
			memcpy(ssbo_data, batch.base, batch.size);
			
			glUnmapNamedBuffer(buffer);
			
			glDrawArraysInstanced(GL_TRIANGLES, 0, 6, batch.count);
			
			batch = batch.next;
		}
	}
	
	SDL_GL_SwapWindow(xx win.U64[0]);
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

make_shader_program :: (vertexShaderSource : *u8, fragmentShaderSource : *u8) -> GLuint {
	vert_shader := glCreateShader(GL_VERTEX_SHADER);
	glShaderSource(vert_shader, 1, *vertexShaderSource, xx 0);
	glCompileShader(vert_shader);
	check_compile_errors(vert_shader, "vertex shader");
	
	frag_shader := glCreateShader(GL_FRAGMENT_SHADER);
	glShaderSource(frag_shader, 1, *fragmentShaderSource, xx 0);
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

image :: (bmp : Bitmap, params := TexParams.LINEAR) -> Handle {
	img : *Image = push_struct(state.arena, Image);
	
	id : GLuint;
	glCreateTextures(GL_TEXTURE_2D, 1, *id);	
	
	if params == .LINEAR {
		glTextureParameteri(id, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTextureParameteri(id, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	}
	else {
		glTextureParameteri(id, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTextureParameteri(id, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	}
	
	glTextureStorage2D(id, 1, GL_SRGB8_ALPHA8, xx bmp.w, xx bmp.h);
	glTextureSubImage2D(id, 0, 0, 0, xx bmp.w, xx bmp.h, GL_RGBA, GL_UNSIGNED_BYTE, bmp.data);
	
	resident := glGetTextureHandleARB(id);
	glMakeTextureHandleResidentARB(resident);
	
	img.id = id;
	img.resident = resident;
	img.w = xx bmp.w;
	img.h = xx bmp.h;
	out : Handle;
	out.U64[0] = xx img;
	out.U64[1] = xx resident;
	
	return out;
}

free_image :: (handle : Handle) {
	image : *Image = handle.U64[0];
	glMakeTextureHandleNonResidentARB(image.resident);
	glDeleteTextures(1, *image.id);
}