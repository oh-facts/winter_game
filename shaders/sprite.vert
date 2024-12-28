#version 450

#define Corner_00 0
#define Corner_01 1
#define Corner_10 2
#define Corner_11 3
#define Corner_COUNT 4

struct Rect
{
	vec2 tl;
	vec2 br;
};

struct Vertex2
{
	vec2 pos;
	vec2 uv;
	vec4 fade;
};

struct R_Rect2
{
	Rect src;
	Rect dst;
	vec4 border_color;
	vec4 fade[Corner_COUNT];
	uvec2 tex_id;
	uint pad[2];
	float border_thickness;
	float radius;
	float pad2[2];
};

layout (std430, binding = 0) buffer ssbo {
	vec2 screen_size;
	vec2 screen_offset;
};

layout (std430, binding = 1) buffer ssbo2 {
	R_Rect2 rects[];
};

out vec4 a_border_color;
out vec4 a_fade;
out vec2 a_uv;
flat out uvec2 a_tex_id;
flat out float a_border_thickness;
flat out vec2 a_half_size;
flat out float a_radius;
out vec2 a_norm_uv;

void main()
{
	R_Rect2 obj = rects[gl_InstanceID];
	
	vec2 base_uv[] = 
	{
		{0, 0},
		{1, 0},
		{0, 1},
		
		{0, 1},
		{1, 0},
		{1, 1},
	};
	
	a_norm_uv = base_uv[gl_VertexID];
	
	Vertex2 vertices[] = 
	{
		{{ obj.dst.tl.x, obj.dst.tl.y}, {obj.src.tl.x, obj.src.br.y}, obj.fade[Corner_00]},
		{{ obj.dst.br.x, obj.dst.tl.y}, {obj.src.br.x, obj.src.br.y}, obj.fade[Corner_10]},
		{{ obj.dst.tl.x, obj.dst.br.y}, {obj.src.tl.x, obj.src.tl.y}, obj.fade[Corner_01]},
		
		{{ obj.dst.tl.x, obj.dst.br.y}, {obj.src.tl.x, obj.src.tl.y}, obj.fade[Corner_01]},
		{{ obj.dst.br.x, obj.dst.tl.y}, {obj.src.br.x, obj.src.br.y}, obj.fade[Corner_10]},
		{{ obj.dst.br.x, obj.dst.br.y}, {obj.src.br.x, obj.src.tl.y}, obj.fade[Corner_11]},
	};
	
	a_half_size = vec2((obj.dst.br.x - obj.dst.tl.x) * 0.5, (obj.dst.br.y - obj.dst.tl.y) * 0.5);
	
	Vertex2 vertex = vertices[gl_VertexID];
	
	a_tex_id = obj.tex_id;
	a_border_color = obj.border_color;
	a_fade = vertex.fade;
	a_border_thickness = obj.border_thickness;
	a_radius = obj.radius;
	a_uv = vertex.uv;
	
	vec2 shifted_pos = vertex.pos - screen_offset + screen_size / 2;
	
	vec2 norm_pos = shifted_pos / screen_size.xy * 2.0 - 1.0;
	norm_pos.y = -norm_pos.y;
	gl_Position = vec4(norm_pos, 0, 1);
}