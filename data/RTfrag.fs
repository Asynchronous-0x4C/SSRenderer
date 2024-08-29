#version 460

precision highp float;

uniform vec2 resolution;
uniform float time;
uniform vec3 color;
uniform vec3 specular;
uniform vec3 emission;
uniform float roughness;
uniform float metalness;

uniform sampler2D t_color;
uniform sampler2D t_normal;
uniform sampler2D t_specular;
uniform sampler2D t_emission;
uniform sampler2D t_MR;

layout (location = 0) out vec4 out_position;
layout (location = 1) out vec4 out_normal;
layout (location = 2) out vec4 out_color;
layout (location = 3) out vec4 out_specular;
layout (location = 4) out vec4 out_emission;

in vec4 w_position;
in vec3 w_normal;
in vec3 w_tangent;
in vec3 w_bitangent;
in vec2 w_uv;

vec3 GetNormal() {
  mat3 TBN = mat3(w_tangent, w_bitangent, w_normal);
  vec3 normalFromMap = texture(t_normal,w_uv).rgb*2.0-1.0;
  return length(w_tangent)<=1e-5?w_normal:normalize(TBN * normalFromMap);
}

void main(){
  out_position=vec4(w_position.xyz,roughness*texture(t_MR,w_uv).g);
  out_normal=vec4(GetNormal(),metalness*texture(t_MR,w_uv).r);
  out_color=vec4(color,1.0)*texture(t_color,w_uv);
  out_specular=vec4(specular,1.0)*texture(t_specular,w_uv);
  out_emission=vec4(emission,1.0)*texture(t_emission,w_uv);
}