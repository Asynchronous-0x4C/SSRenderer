#version 460

uniform int num_iterations;
uniform sampler2D current;
uniform sampler2D motion;
uniform sampler2D prev_normal;
uniform sampler2D normal;
uniform sampler2D prev_depth;
uniform sampler2D depth;
uniform sampler2D before;
uniform vec2 resolution;
uniform bool move;

const float alpha=0.2;

vec4 accum;

layout(location=0)out vec4 after;
layout(location=1)out vec4 cur_moment;
layout(location=2)out vec4 fragColor;

vec4 SVGF();

void main(){
  accum=texelFetch(before,ivec2(gl_FragCoord.xy),0);
  if(move){
    fragColor=SVGF();
  }else{
    if(num_iterations==1){
      after.rgb=texelFetch(current,ivec2(gl_FragCoord.xy),0).rgb;
    }else{
      after.rgb=accum.rgb+texelFetch(current,ivec2(gl_FragCoord.xy),0).rgb;
    }
    fragColor=vec4(after.rgb/float(num_iterations),1.0);
  }
  // fragColor=vec4(pow(texelFetch(depth,ivec2(gl_FragCoord.xy),0).rrr,vec3(40.0)),1.0);
}

#define THRESHOLD 5.0

vec4 moment(vec4 prev,vec4 cur){
  float w=1.0/THRESHOLD;
  w=prev.a<THRESHOLD?1.0/prev.a:w;
  return vec4(mix(prev.rgb,cur.rgb,w),++prev.a);
}

float moment_f(float prev,float cur,float num){
  float w=1.0/THRESHOLD;
  w=num<THRESHOLD?1.0/num:w;
  return mix(prev,cur,w);
}

bool canAccum(vec2 cur,vec2 prev){
  vec3 nor=texture(normal,cur,0).rgb;
  vec3 pnor=texture(prev_normal,prev,0).rgb;
  float dep=texture(depth,cur,0).r;
  float pdep=texture(prev_depth,prev,0).r;
  float ndot=dot(nor,pnor);
  float dd=abs(dep-pdep);
  //bool acc=dd<0.99;
  return dd<0.05&&ndot>0.9&&min(prev.x,prev.y)>0.0&&max(prev.x,prev.y)<1.0;
}

float calcDepthWeight(float nbDepth, float depth,float dzdx, float dzdy, float dx, float dy){
  const float sigma_z = 1.0;
  const float eps = 1e-6;
  return exp(-abs(nbDepth - depth) / (sigma_z * abs(dzdx * dx + dzdy * dy) + eps));
}

float calcNormalWeight(vec3 nbNor,vec3 nor) {
    const float sigma_n = 128;
    return pow(max(0.0, dot(nbNor, nor)), sigma_n);
}

vec2 variance_estimation(float firstMoment,float secondMoment){
  const float[7] filterKernel = float[](
      0.00598, 0.060626, 0.241843, 0.383103, 0.241843, 0.060626, 0.00598
  );
  const float centerWeight = filterKernel[3] * filterKernel[3];
  float sumFirstMoments = centerWeight * firstMoment;
  float sumSecondMoments = centerWeight * secondMoment;

  float dep = texelFetch(depth,ivec2(gl_FragCoord.xy),0).r;
  vec2 d=sign(vec2(resolution*0.5-gl_FragCoord.xy));
  vec2 dd=(vec2(texelFetch(depth,ivec2(gl_FragCoord.xy)+ivec2(d.x,0),0).r,texelFetch(depth,ivec2(gl_FragCoord.xy)+ivec2(0,d.y),0).r)-dep)*d;
  vec3 nor = texelFetch(normal,ivec2(gl_FragCoord.xy),0).rgb;

  float sumWeights = 0.0;
  for (int i=-3;i<=3;++i) {
      float hy=filterKernel[i];
      for (int j = -3; j <= 3; ++j) {
          if (i == 0 && j == 0)
              continue;

          float hx = filterKernel[j];
          
          ivec2 nbPix = ivec2(gl_FragCoord.xy)+ivec2(j,i);
          float nbDepth = texelFetch(depth,nbPix,0).r;
          vec3 nbNormal = texelFetch(normal,nbPix,0).rgb;

          float wz = calcDepthWeight(nbDepth,dep,dd.x,dd.y,d.x,d.y);
          float wn = calcNormalWeight(nbNormal,nor);
          float weight = hx * hy * wz * wn;

          sumFirstMoments+=weight * firstMoment;
          sumSecondMoments+=weight * secondMoment;
          sumWeights += weight;
      }
  }
  return vec2(sumFirstMoments,sumSecondMoments)/sumWeights;
}

vec4 SVGF(){
  vec2 offset=texelFetch(motion,ivec2(gl_FragCoord.xy),0).rg*resolution;
  vec2 p_coord=(gl_FragCoord.xy-offset)/resolution;
  vec4 current=texture(current,gl_FragCoord.xy/resolution,0);
  vec4 before=texture(before,p_coord);
  if(canAccum(gl_FragCoord.xy/resolution,p_coord)){
    after=moment(before,vec4(current.rgb,1.0));
    vec2 m=texture(prev_depth,p_coord,0).gb;
    cur_moment.x=moment_f(current.a,m.x,after.a);
    cur_moment.y=moment_f(current.a*current.a,m.y,after.a);
  }else{
    after=vec4(current.rgb,1.0);
    cur_moment.x=current.a;
    cur_moment.y=current.a*current.a;
  }
  float variance;
  if(after.a<4.0){
    vec2 m=variance_estimation(cur_moment.x,cur_moment.y);
    variance=max(0.1,m.y-m.x*m.x);
  }else{
    variance=cur_moment.y-cur_moment.x*cur_moment.x;
  }
  cur_moment.z=variance;
  return after;
}