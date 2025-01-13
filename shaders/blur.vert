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
	uvec2 bloom_id;
	uvec2 blur1_id;
	uvec2 blur2_id;
};

flat out uvec2 a_noise_id;
flat out uvec2 a_draw_id;
flat out uvec2 a_bloom_id;
flat out uvec2 a_blur1_id;
flat out uvec2 a_blur2_id;

out vec2 a_uv;
flat out vec2 a_screen_size;

void main()
{
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
	
	a_noise_id = noise_id;
	a_uv = base_uv[gl_VertexID];
	vec2 vertex = vertices[gl_VertexID];
	
	float aspect_ratio = screen_size.x / screen_size.y;
	
	vec2 norm_pos = vertex;// / screen_size.xy * 2.0 - 1.0;
	//norm_pos.x *= aspect_ratio;
	
	a_bloom_id = bloom_id;
	a_screen_size = screen_size;
	gl_Position = vec4(norm_pos, 0, 1);
	a_draw_id = draw_id;
}