// Ice mostly figured out the beam

#version 450 core
#extension GL_ARB_bindless_texture : enable

in vec2 fragCoord;
in vec2 screen_size;
flat in float a_delta;
flat in uvec2 a_noise_id;
flat in uvec2 a_displacement_id;
flat in vec2 a_offset;

out vec4 FragColor;

const vec4 bg = vec4(0.2, 0.2, 0.3, 1.0);

void main()
{
	vec4 displacement = texture(sampler2D(a_displacement_id), fragCoord);
	
	vec2 distortedUV = fragCoord + displacement.xy * 0.3;
	
	distortedUV = vec2(distortedUV.x, distortedUV.y / 3.0 - a_delta * 0.1);
	
	vec4 noise = texture(sampler2D(a_noise_id), distortedUV);
	noise = round(noise * 4.0) / 4.0;
	noise.w = 0.1;
	
	vec3 color = vec3(1, 0, 0);
	
	FragColor = mix(noise, vec4(color, 0.4), 0.743);
}