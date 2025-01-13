#version 450 core

layout (std430, binding = 0) buffer ssbo {
	vec2 screen_size;
	vec2 screen_offset;
	uvec2 noise_id;
	uvec2 displacement_id;
	vec2 offset;
	float delta;
	float pad;
};

flat out uvec2 a_noise_id;
out vec2 a_uv;

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
	
	
	gl_Position = vec4(norm_pos, 0, 1);
	
}