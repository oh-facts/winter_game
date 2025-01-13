#version 450 core
#extension GL_ARB_bindless_texture : enable

in vec2 a_n_uv;
in vec2 a_uv;
in vec2 screen_size;
flat in float a_delta;
flat in uvec2 a_noise_id;
flat in uvec2 a_displacement_id;
flat in vec2 a_offset;
flat in uvec2 a_water_id;

out vec4 FragColor;

const vec4 bg = vec4(0.2, 0.2, 0.3, 1.0);

void main()
{
	vec4 displacement = texture(sampler2D(a_displacement_id), a_n_uv);
	
	vec2 distortedUV = a_n_uv + displacement.xy * 0.3;
	
	distortedUV = vec2(distortedUV.x, distortedUV.y / 3.0 - a_delta * 0.02);
	
	vec4 noise = texture(sampler2D(a_noise_id), distortedUV);
	noise = round(noise * 4.0) / 4.0;
	//noise.w = 0.1;
	
	distortedUV = a_uv;
	
	distortedUV.x += sin(a_delta * 2.0 + a_uv.y * 10.0) * 0.002;
	vec4 screen_color = texture(sampler2D(a_water_id), distortedUV);
	
	FragColor = mix(noise , screen_color, 0.5);
}