#version 450 core
#extension GL_ARB_bindless_texture : enable

layout (location=0) out vec4 FragColor;

in vec2 a_uv;
flat in uvec2 a_draw_id;

void main() 
{
	FragColor = texture(sampler2D(a_draw_id), a_uv);
}