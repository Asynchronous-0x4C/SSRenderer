#version 460

uniform sampler2D depth;
uniform sampler2D normal;
uniform sampler2D moment;

layout (location = 0)out vec4 out_depth;
layout (location = 1)out vec4 out_normal;

void main(){
  ivec2 uv=ivec2(gl_FragCoord.xy);
  vec2 m=texelFetch(moment,uv,0).rg;
  out_depth=vec4(texelFetch(depth,uv,0).r,m.x,m.y,1.0);
  out_normal=vec4(texelFetch(normal,uv,0).rgb,1.0);
}