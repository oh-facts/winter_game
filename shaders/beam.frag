// Authored by ice facts

#version 450 core
in vec2 fragCoord;
in vec2 screen_size;
out vec4 FragColor;

const vec2 offset = vec2(0.4, 0.1);
const vec4 bg = vec4(0.2, 0.2, 0.3, 1.0);
const vec4 beam_color = vec4(1.0, 0.0, 0.0, 1.0);

const vec2 moon_pos = vec2(0.3, 0.5);
const float moon_radius = 0.1;
const vec4 moon_color = vec4(1.0, 1.0, 1.0, 1.0);

float random(vec2 p)
{
	return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453);
}

float stars(vec2 p)
{
	float star = random(p);
	return step(0.999, star);
}

float beam(vec2 p, float pew)
{
	// Parameters
	float m = 9.0;  
	float n = -0.2;   
	float z = -3.0;   
	
	// y = (-x^(4n) + m) / z
	float x = (p.x + offset.x) * pew;
	
	float y = (-pow(x, 4.0 * n) + m) / z;
	y += offset.y;
	
	// Distance?
	float dist = abs(p.y - y);
	return dist;
}

float circle(vec2 p, vec2 center, float radius)
{
	float dist = length(p - center);
	return step(dist, radius);
}

void main()
{
	vec2 p = fragCoord;
	
	float dist = beam(p, 1.0);
	float dist2 = beam(p, -1.0);
	
	float lineWidth = 0.85;
	
	float alpha = smoothstep(-1.0, 1.0, -p.y);
	float star = stars(p);
	
	float moon = circle(p, moon_pos, moon_radius);
	
	if ((dist) < lineWidth || (dist2) < lineWidth)
	{
		FragColor = mix(bg, beam_color, alpha);
	}
	else
	{
		FragColor = mix(bg + star, moon_color, moon);
	}
}