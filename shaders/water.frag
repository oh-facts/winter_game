#version 450 core
#extension GL_ARB_bindless_texture : enable

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

in vec2 a_n_uv;
in vec2 a_uv;

layout (location=0) out vec4 FragColor;

const vec4 water_color = vec4(0.0, 0.4, 0.8, 0.8);

void main()
{
	vec4 displacement = texture(sampler2D(displacement_id), a_n_uv);
	
	vec2 distortedUV = a_n_uv + displacement.xy * 0.3;
	
	distortedUV = vec2(distortedUV.x, distortedUV.y / 3.0 - delta * 0.02);
	
	vec4 noise = texture(sampler2D(noise_id), distortedUV);
	noise = round(noise * 4.0) / 6.0;
	//noise.w = 0.1;
	
	distortedUV = a_uv;
	
	distortedUV.x += sin(delta * 2.0 + a_uv.y * 10.0) * 0.002;
	vec4 screen_color = texture(sampler2D(water_id), distortedUV);
	
	FragColor = mix(noise, screen_color, 0.35);
	FragColor = mix(FragColor, water_color, 0.1);
}