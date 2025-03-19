// TODO(mizu): Make a torch shader
// torch pass draws the screen black
// then draws circles at places

// Do shadows first. Do the rotate and width change thing you thought of.

// If you can draw a perfect rotating shadow, you did it.

// make the light a light pass where you can
// draw lights

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

void main() 
{
	FragColor = texture(sampler2D(u_image_id), a_uv);
}