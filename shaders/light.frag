#version 450 core
#extension GL_ARB_bindless_texture : enable

layout (location=0) out vec4 FragColor;

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

layout (std430, binding = 1) buffer ssbo2 {
	vec2 light;
};

in vec2 a_uv;

void main() 
{
	{
		vec2 center = light;
		
		center -= (screen_offset - screen_size / 2);
		center /= screen_size;
		
		vec2 uv = a_uv;
		
		uv.x *= screen_size.x / screen_size.y;
		center.x *= screen_size.x / screen_size.y;
		center.y = 1 - center.y;
		
		float threshold = 0.25;
		vec4 lightColor = vec4(1.0, 1.0, 1.0, 1.0);
		
		float edgeSoftness = 0.55;
		float edgeBlur = 0.05;
		
		float distanceFromCenter = length(uv - center);
		float ambient = 0.1;
		float brightness = smoothstep(threshold - edgeSoftness, threshold + edgeBlur, distanceFromCenter);
		
		FragColor = texture(sampler2D(draw_id), a_uv) * (1 + ambient - brightness) * 1.5 * lightColor;
	}
	{
		vec2 center = vec2(1100, 500);
		
		center -= (screen_offset - screen_size / 2);
		center /= screen_size;
		
		vec2 uv = a_uv;
		
		uv.x *= screen_size.x / screen_size.y;
		center.x *= screen_size.x / screen_size.y;
		center.y = 1 - center.y;
		
		float threshold = 0.25;
		vec4 lightColor = vec4(1.0, 1.0, 1.0, 1.0);
		
		float edgeSoftness = 0.55;
		float edgeBlur = 0.05;
		
		float distanceFromCenter = length(uv - center);
		float ambient = 0.3;
		float brightness = smoothstep(threshold - edgeSoftness, threshold + edgeBlur, distanceFromCenter);
		
		FragColor += texture(sampler2D(draw_id), a_uv) * (1 + ambient - brightness) * 1.5 * lightColor;
	}
	//float amb = 0.05;
	//FragColor += vec4(amb, amb, amb, 1);
}