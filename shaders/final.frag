#version 450 core
#extension GL_ARB_bindless_texture : enable

layout (location=0) out vec4 FragColor;

in vec2 a_uv;
flat in uvec2 a_noise_id;
flat in uvec2 a_draw_id;
flat in uvec2 a_blur_id;

void main() 
{
	//FragColor = texture(sampler2D(a_noise_id), a_uv);
	FragColor = texture(sampler2D(a_draw_id), a_uv) + texture(sampler2D(a_blur_id), a_uv);
}