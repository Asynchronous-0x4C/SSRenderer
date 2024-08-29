#version 460

uniform mat4 mvp;
uniform mat4 model;
uniform mat4 it_model;

layout(location = 3)in vec3 position;
layout(location = 4)in vec3 normal;
layout(location = 5)in vec3 tangent;
layout(location = 6)in vec2 texCoord;

out vec4 w_position;
out vec3 w_normal;
out vec3 w_tangent;
out vec3 w_bitangent;
out vec2 w_uv;

void main() {
    gl_Position = mvp*vec4(position, 1.0);
    w_position=vec4(position,1.0);
    w_normal=mat3(it_model)*normal;
    w_tangent=mat3(it_model)*tangent;
    w_bitangent=cross(w_normal,w_tangent);
    w_uv=texCoord;
}