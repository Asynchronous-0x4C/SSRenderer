#version 460

precision highp float;

uniform mat4 p_mvp;
uniform mat4 mvp;
uniform float ID;
uniform sampler2D t_normal;

layout (location = 0) out vec4 out_ID;
layout (location = 1) out vec4 out_normal;
layout (location = 2) out vec4 out_motion;

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
  out_ID=vec4(ID);
  out_normal=vec4(GetNormal(),1.0);
  vec4 prev=p_mvp*w_position;
  vec4 curr=mvp*w_position;
  prev/=prev.w;
  curr/=curr.w;
  out_motion=vec4((curr.xy-prev.xy)*0.5,1.0,1.0);
}