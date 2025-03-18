// TODO(mizu): Make a torch shader
// torch pass draws the screen black
// then draws circles at places

// Do shadows first. Do the rotate and width change thing you thought of.

// If you can draw a perfect rotating shadow, you did it.

#version 450 core
#extension GL_ARB_bindless_texture : enable

layout (location=0) out vec4 FragColor;

in vec2 a_uv;
in vec2 a_corrected_uv;
flat in uvec2 a_draw_id;

void main() 
{
	vec2 center = vec2(0.5, 0.5);
	float distanceFromCenter = length(a_corrected_uv - center);
	float threshold = 0.25;
	float brightness = smoothstep(threshold - 0.35, threshold + 0.05, distanceFromCenter);
	FragColor = texture(sampler2D(a_draw_id), a_uv);// * (1.0 - brightness) * 2;
}
