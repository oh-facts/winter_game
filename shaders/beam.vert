#version 450 core
out vec2 fragCoord;

layout (std430, binding = 0) buffer ssbo {
	vec2 screen_size;
	vec2 screen_offset;
	uvec2 noise_id;
	uvec2 displacement_id;
	float pad[3];
	float delta;
};

out vec2 a_screen_size;

flat out uvec2 a_noise_id;
flat out uvec2 a_displacement_id;
flat out float a_delta;

void main() {
	vec2 vertices[4] = vec2[](
														vec2(-1.0,  1.0),
														vec2(-1.0, -1.0),
														vec2( 1.0, -1.0),
														vec2( 1.0,  1.0)
														);
	
	a_noise_id = noise_id;
	a_displacement_id = displacement_id;
	a_delta = delta;
	fragCoord = vertices[gl_VertexID];
	fragCoord.x *= screen_size.x / screen_size.y;
	gl_Position = vec4(vertices[gl_VertexID], 0.0, 1.0);
}
