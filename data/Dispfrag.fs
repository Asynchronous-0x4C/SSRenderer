#version 460

precision highp float;

uniform sampler2D emission;
uniform sampler2D normal;

out vec4 fragColor;

void main(){
  ivec2 icoord=ivec2(gl_FragCoord.xy);

  vec3 result_color=texelFetch(emission,icoord,0).rgb;

  fragColor=vec4(result_color,1.0);
}