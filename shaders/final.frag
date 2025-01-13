#version 450 core
#extension GL_ARB_bindless_texture : enable

in vec2 a_uv;
out vec4 FragColor;
flat in uvec2 a_noise_id;
uniform sampler2D screen_tex;

void main() 
{
	//FragColor = texture(sampler2D(a_noise_id), a_uv);
	FragColor = texture(screen_tex, a_uv);
}