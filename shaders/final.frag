#version 450 core
#extension GL_ARB_bindless_texture : enable

in vec2 a_uv;
out vec4 FragColor;
flat in uvec2 a_noise_id;
flat in uvec2 a_draw_id;

void main() 
{
	//FragColor = texture(sampler2D(a_noise_id), a_uv);
	FragColor = texture(sampler2D(a_draw_id), a_uv);
}