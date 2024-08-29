#version 460

uniform sampler2D shade;
uniform sampler2D source;

out vec4 fragColor;

vec3 toneMap(vec3 src){
  return pow(src/(src+1.0),vec3(0.4545));
}

void main() {
  vec4 shd=texelFetch(shade,ivec2(gl_FragCoord.xy),0);
  vec4 src=texelFetch(source,ivec2(gl_FragCoord.xy),0);
  fragColor=vec4(toneMap(mix(src.rgb,shd.rgb,src.a)),1.0);
}