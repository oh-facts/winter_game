#version 450 core

out vec4 FragColor;
uniform sampler2D screen;
in vec2 a_uv;
void main()
{
	FragColor = texture(screen, a_uv);
}