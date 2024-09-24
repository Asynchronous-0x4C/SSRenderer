#version 460

uniform sampler2D texture;

out vec4 fragColor;

void main(){
  fragColor=texelFetch(texture,ivec2(gl_FragCoord.xy),0);
}