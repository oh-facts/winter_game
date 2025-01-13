#version 450 core

layout (std430, binding = 0) buffer ssbo {
	vec2 screen_size;
	vec2 screen_offset;
	uvec2 noise_id;
	uvec2 displacement_id;
	vec2 offset;
	float delta;
	float pad;
	uvec2 draw_id;
	uvec2 water_id;
};

out vec2 a_screen_size;
out vec2 a_uv;
out vec2 a_n_uv;

flat out uvec2 a_water_id;
flat out uvec2 a_noise_id;
flat out uvec2 a_displacement_id;
flat out float a_delta;
flat out vec2 a_offset;

void main() {
	vec2 vertices[] = 
	{
		{-1.0, -1.0},
		{ 1.0, -1.0},
		{-1.0,  1.0},
		
		{-1.0,  1.0},
		{ 1.0, -1.0},
		{ 1.0,  1.0}
	};
	
	vec2 base_uv[] = 
	{
		{0, 0},
		{1, 0},
		{0, 1},
		
		{0, 1},
		{1, 0},
		{1, 1}
	};
	
	vec2 vertex = vertices[gl_VertexID];
	
	a_offset = offset;
	a_noise_id = noise_id;
	a_displacement_id = displacement_id;
	a_delta = delta;
	a_uv = base_uv[gl_VertexID];
	a_n_uv = a_uv;
	a_n_uv.x *= screen_size.x / screen_size.y;
	a_water_id = water_id;
	
	gl_Position = vec4(vertex, 0.0, 1.0);
}
