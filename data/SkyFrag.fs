#version 460

precision highp float;

uniform mat4 mvp;
uniform vec2 resolution;
uniform samplerCube sky;

layout (location = 4) out vec4 out_emission;

vec3 sampleHDRI(vec3 v){
  return texture(sky,v).rgb;
}

void main(){
  vec2 uv=(gl_FragCoord.xy/resolution)*2.0-1.0;
  vec3 rayDirection=normalize((mvp*vec4(uv,1.0,1.0)).xyz);
  out_emission=vec4(sampleHDRI(rayDirection),1.0);
}