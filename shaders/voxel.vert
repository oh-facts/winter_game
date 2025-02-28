#version 450 core

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
	
	vec2 pos = vertices[gl_VertexID];
	
	gl_Position = vec4(pos.x, pos.y, 0, 1.0);
	a_uv = base_uv[gl_VertexID];
}