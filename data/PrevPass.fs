#version 460

uniform sampler2D depth;
uniform sampler2D normal;

layout (location = 0)out vec4 out_depth;
layout (location = 1)out vec4 out_normal;

void main(){
  out_depth=vec4(texelFetch(depth,ivec2(gl_FragCoord.xy),0).r,0.0,0.0,1.0);
  out_normal=vec4(texelFetch(normal,ivec2(gl_FragCoord.xy),0).rgb,1.0);
}