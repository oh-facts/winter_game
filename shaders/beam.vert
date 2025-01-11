#version 450 core
out vec2 fragCoord;

layout (std430, binding = 0) buffer ssbo {
	vec2 screen_size;
	vec2 screen_offset;
};

out vec2 a_screen_size;

void main() {
	vec2 vertices[4] = vec2[](
														vec2(-1.0,  1.0),
														vec2(-1.0, -1.0),
														vec2( 1.0, -1.0),
														vec2( 1.0,  1.0)
														);
	fragCoord = vertices[gl_VertexID];
	fragCoord.x *= screen_size.x / screen_size.y;
	
	gl_Position = vec4(vertices[gl_VertexID], 0.0, 1.0);
}
