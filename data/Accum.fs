#version 460

uniform int num_iterations;
uniform sampler2D current;
uniform sampler2D motion;
uniform sampler2D prev_normal;
uniform sampler2D normal;
uniform sampler2D prev_depth;
uniform sampler2D depth;
uniform vec2 resolution;
uniform bool move;

const float alpha=0.2;

layout(std430,binding=8)buffer Accumulate{
  vec4 accum[];
};

int p_pixel_idx;
int pixel_idx;

out vec4 fragColor;

vec4 accumulate(vec2 offset);

vec3 toneMap(vec3 c){
  return pow(c/(c+1.0),vec3(0.4545));
}

void main(){
  if(move){
    vec2 offset=texelFetch(motion,ivec2(gl_FragCoord.xy),0).rg*resolution;
    pixel_idx=int(gl_FragCoord.y)+int(gl_FragCoord.x)*int(resolution.y);
    p_pixel_idx=int(gl_FragCoord.y-offset.y)+int(gl_FragCoord.x-offset.x)*int(resolution.y);
    accum[pixel_idx]=accumulate(offset);
    fragColor=vec4(toneMap(accum[pixel_idx].rgb),1.0);
  }else{
    pixel_idx=int(gl_FragCoord.y)+int(gl_FragCoord.x)*int(resolution.y);
    if(num_iterations==1){
      accum[pixel_idx].rgb=texelFetch(current,ivec2(gl_FragCoord.xy),0).rgb;
    }else{
      accum[pixel_idx].rgb+=texelFetch(current,ivec2(gl_FragCoord.xy),0).rgb;
    }
    fragColor=vec4(toneMap(accum[pixel_idx].rgb/float(num_iterations)),1.0);
  }
  // fragColor=vec4(pow(texelFetch(depth,ivec2(gl_FragCoord.xy),0).rrr,vec3(40.0)),1.0);
}

vec4 accumulate(vec2 offset){
  vec2 p_coord=(gl_FragCoord.xy-offset)/resolution;
  vec3 nor=texture(normal,gl_FragCoord.xy/resolution,0).rgb;
  vec3 pnor=texture(prev_normal,p_coord,0).rgb;
  float dep=texture(depth,gl_FragCoord.xy/resolution,0).r;
  float pdep=texture(prev_depth,p_coord,0).r;
  float ndot=dot(nor,pnor);
  float dd=abs(dep-pdep);
  //bool acc=dd<0.99;
  bool acc=dd<0.05&&ndot>0.9&&min(p_coord.x,p_coord.y)>0.0&&max(p_coord.x,p_coord.y)<1.0;
  vec3 current=texture(current,gl_FragCoord.xy/resolution,0).rgb;
  return acc?vec4(mix(accum[p_pixel_idx].rgb,current,alpha),accum[p_pixel_idx].a++):vec4(current,1.0);
}