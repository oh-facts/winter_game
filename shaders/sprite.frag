#version 450
#extension GL_ARB_bindless_texture : enable
out vec4 out_color;

in vec4 a_border_color;
in vec4 a_fade;
in vec2 a_uv;
flat in uvec2 a_tex_id;
flat in float a_border_thickness;
flat in vec2 a_half_size;
flat in float a_radius;
flat in vec2 a_submerged;
in vec2 a_norm_uv;

float RectSDF(vec2 p, vec2 b, float r)
{
	vec2 d = abs(p) - b + vec2(r);
	return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - r;   
}

void main() 
{
	vec4 tex_col = texture(sampler2D(a_tex_id), a_uv);
	
	if(tex_col.a < 0.01) {
		discard;
	}
	
	if ((a_submerged.x * a_norm_uv.y) > (a_submerged.x * (1.0 - a_submerged.y))) {
		discard;
	}
	
	vec2 pos = a_half_size * 2 * a_norm_uv;
	
	float fDist = RectSDF(pos - a_half_size, a_half_size - a_border_thickness/2.0, a_radius);
	float fBlendAmount = smoothstep(-1.0, 0.0, abs(fDist) - a_border_thickness / 2.0);
  
	vec4 v4FromColor = a_border_color;
	vec4 v4ToColor = (fDist < 0.0) ? a_fade * tex_col : vec4(0);
	out_color = mix(v4FromColor, v4ToColor, fBlendAmount);
}