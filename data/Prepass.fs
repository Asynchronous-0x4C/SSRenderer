#version 460

precision highp float;

uniform vec3 position;
uniform mat4 p_mvp;
uniform mat4 mvp;
uniform mat4 it_model;
uniform int ID;
uniform sampler2D t_normal;
uniform sampler2D t_albedo;
uniform bool normal_texture;
uniform bool albedo_texture;

layout (location = 0) out vec4 out_ID;
layout (location = 1) out vec4 out_normal;
layout (location = 2) out vec4 out_position;
layout (location = 3) out vec4 out_motion;

in vec4 w_position;
in vec3 w_normal;
in vec3 w_tangent;
in vec3 w_bitangent;
in vec2 w_uv;

vec3 GetNormal() {
  mat3 TBN = mat3(w_tangent, w_bitangent, w_normal);
  vec3 normalFromMap = vec3((texture(t_normal,w_uv).rg-vec2(0.0019607843137))*2.0-1.0,1.0);
  return length(w_tangent)<=1e-5?w_normal:normalize(TBN * normalFromMap);
}

void main(){
  out_ID=vec4(float(ID),w_uv,0.0);
  float s=sign(dot(w_normal,position-w_position.xyz));
  out_normal=vec4((normal_texture?GetNormal():w_normal)*s,(s+1.0)*0.5);
  out_position=vec4(w_position.xyz/w_position.w,1.0);
  vec4 prev=p_mvp*(w_position*it_model);
  vec4 curr=mvp*(w_position*it_model);
  prev/=prev.w;
  curr/=curr.w;
  out_motion=vec4((curr.xy-prev.xy)*0.5,1.0,1.0);
}