#import "mizu_base";

#import "GL" (ENABLE_ALL_EXTENSIONS = true);

os :: #import "os";
#import "Basic";
#import "SDL";
#import "File";
#import "Math";

ui_vertex_shader := #run read_entire_file("shaders/ui.vert"); 
ui_frag_shader := #run read_entire_file("shaders/ui.frag");

SceneData :: struct {
	proj : Matrix4;
	view : Matrix4;
	screen_size : Vector2;
	pad : Vector2;
};

Image :: struct {
	id : GLuint;
	resident : GLuint64;
	w : u32;
	h : u32;
};

INST_BUFFER :: enum {
	UI;
	COUNT;
};

SHADER_PROG :: enum {
	UI;
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
	gl_load(*gl, SDL_GL_GetProcAddress);
	
	print ("GL Vendor = %\n", to_string(glGetString(GL_VENDOR)));
	print ("GL Version = %\n", to_string(glGetString(GL_VERSION)));
	
	stupid_fucking_opengl : GLuint;
	glCreateVertexArrays(1, *stupid_fucking_opengl);
	glBindVertexArray(stupid_fucking_opengl);
	
	SDL_GL_SetSwapInterval(1);
	
	vert_files : []string = .[
														ui_vertex_shader,
														];
	
	frag_files : []string = .[
														ui_frag_shader,
														];
	
	for i : 0 .. SHADER_PROG.COUNT - 1 {		
		state.shader_prog[i] = make_shader_program(vert_files[i].data, frag_files[i].data);
		
		state.inst_buffer[i] = make_buffer(MB(8));
	}
	
	state.scene_buffer = make_buffer(size_of(SceneData));
	
	data : []s64 = .[0xFFFFFFFF];
	
	bmp := Bitmap.{data.data, 1, 1, 4};
	
	state.white_square = image(bmp);
}

submit :: (win : os.Handle, ui_batches : BatchList, proj_view : Matrix4 = Matrix4_Identity) {
	glViewport(0, 0, xx 960, xx 540);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glEnable(GL_BLEND);
	
	glClearColor(1., 0, 1., 1.);
	glClear(GL_COLOR_BUFFER_BIT);
	
	batch := ui_batches.first;
	
	win_size_float : Vector2 = .{960, 540};
	
	// scene buffer
	{
		scene_data : SceneData;
		scene_data.proj = Matrix4_Identity;
		scene_data.view = Matrix4_Identity;
		scene_data.screen_size = .{960, 540};
		
		using state;
		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, scene_buffer);
		ssbo_data : *u8 = glMapNamedBufferRange(scene_buffer, 0, size_of(SceneData), GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
		
		memcpy(ssbo_data, *scene_data, size_of(SceneData));
		
		glUnmapNamedBuffer(scene_buffer);
	}
	
	while batch	{
		buffer := state.inst_buffer[INST_BUFFER.UI];
		shader := state.shader_prog[SHADER_PROG.UI];
		
		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, buffer);
		glUseProgram(shader);
		
		ssbo_data : *u8 = glMapNamedBufferRange(buffer, 0, size_of(Vector4) + size_of(Matrix4) + batch.count * size_of(Rect2), GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
		
		memcpy(ssbo_data, batch.base, size_of(Rect2) * batch.count);
		
		glUnmapNamedBuffer(buffer);
		
		glDrawArraysInstanced(GL_TRIANGLES, 0, 6, batch.count);
		
		batch = batch.next;
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

image :: (bmp : Bitmap) -> Handle {
	img : *Image = push_struct(state.arena, Image);
	
	id : GLuint;
	glCreateTextures(GL_TEXTURE_2D, 1, *id);	
	
	glTextureParameteri(id, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTextureParameteri(id, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	
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

/*
function void r_submit(OS_Handle win, R_BatchList *ui_batches, M4F proj_view)
{
	V2S win_size = os_getWindowSize(win);
	V2F win_size_float = {win_size.x, win_size.y};
	f32 color[3] = {0,0,1};
	glClearNamedFramebufferfv(0, GL_COLOR, 0, color);
	
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glEnable(GL_BLEND);
	glViewport(0, 0, win_size_float.x, win_size_float.y);
	
	for(R_Batch *batch = ui_batches->first; batch; batch = batch->next)
	{
		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, r_opengl_state->inst_buffer[R_OPENGL_INST_BUFFER_UI]);
		glUseProgram(r_opengl_state->shader_prog[R_OPENGL_SHADER_PROG_UI]);

		void *ssbo_data = glMapNamedBufferRange(r_opengl_state->inst_buffer[R_OPENGL_INST_BUFFER_UI], 0, sizeof(V4F) + sizeof(M4F) + batch->count * sizeof(R_Rect2), GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_BUFFER_BIT);
		
		memcpy(ssbo_data, &win_size_float, sizeof(win_size_float));
		memcpy((u8*)ssbo_data + sizeof(win_size_float), &proj_view, sizeof(M4F));
		memcpy((u8*)ssbo_data + sizeof(win_size_float) + sizeof(M4F), batch->base, batch->count * sizeof(R_Rect2));
		
		glUnmapNamedBuffer(r_opengl_state->inst_buffer[R_OPENGL_INST_BUFFER_UI]);
		
		glDrawArraysInstanced(GL_TRIANGLES, 0, 6, batch->count);
	}
}
*/