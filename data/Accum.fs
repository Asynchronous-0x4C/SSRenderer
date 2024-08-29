#version 460

uniform int num_iterations;
uniform sampler2D current;
uniform vec2 resolution;

layout(std430,binding=8)buffer Accumulate{
  vec4 accum[];
};

int pixel_idx;

out vec4 fragColor;

vec3 toneMap(vec3 c){
  return pow(c/(c+1.0),vec3(0.4545));
}

void main(){
  pixel_idx=int(gl_FragCoord.y)+int(gl_FragCoord.x)*int(resolution.y);
  if(num_iterations==1){
    accum[pixel_idx].rgb=texelFetch(current,ivec2(gl_FragCoord.xy),0).rgb;
  }else{
    accum[pixel_idx].rgb+=texelFetch(current,ivec2(gl_FragCoord.xy),0).rgb;
  }
  fragColor=vec4(toneMap(accum[pixel_idx].rgb/float(num_iterations)),1.0);
}