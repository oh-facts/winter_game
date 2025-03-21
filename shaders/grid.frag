#version 450 core
#extension GL_ARB_bindless_texture : enable

layout (location=0) out vec4 FragColor;
uniform uvec2 u_image_id;

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

in vec2 a_uv;
in vec2 a_corrected_uv;

layout (std430, binding = 1) buffer ssbo2 {
	vec2 grid_min;
	vec2 grid_max;
	float col;
	float row;
};

void main() 
{
	vec2 ss = screen_size;
	ss.x /= 4;
	ss.y /= 4;
	
	float col = 60;
	float row = 32;
	float lineThickness = 0.5;
	vec2 top_left = vec2(-lineThickness, -lineThickness);
	vec2 gridSize = (ss.xy - top_left) / vec2(col, row);
	
	vec2 adjustedUV = a_uv * ss;
	
	adjustedUV -= grid_min;
	
	float gridX = mod(adjustedUV.x, gridSize.x);
	float gridY = mod(adjustedUV.y, gridSize.y);
	
	if (gridX < lineThickness || gridY < lineThickness) {
		FragColor = vec4(0, 0, 0, 0.3);
	} else {
		FragColor = vec4(0.0, 0.0, 0.0, 0.0);
	}
}