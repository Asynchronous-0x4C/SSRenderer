#version 460

uniform sampler2D normal;
uniform sampler2D depth;
uniform sampler2D after;
uniform sampler2D moment;
uniform sampler2D albedo;
uniform vec2 resolution;

ivec2 pix;
ivec2 imageSize;
float luminance;
float localMeanStdDev;
vec3 nor;
float dep;
vec2 dd;

layout(location=0)out vec4 before;
layout(location=1)out vec4 fragColor;

float filter_variance();
void a_trous(int stage,inout vec3 lit,inout float var);

vec3 toneMap(vec3 c){
  return pow(c/(c+1.0),vec3(0.4545));
}

float calcLuminance(vec3 c){
  return dot(c,vec3(0.299,0.587,0.114));
}

void main(){
  pix=ivec2(gl_FragCoord.xy);
  imageSize=ivec2(resolution);
  localMeanStdDev=filter_variance();
  nor=texelFetch(normal,pix,0).rgb;
  dep=texelFetch(depth,pix,0).r;
  vec2 d=sign(vec2(resolution*0.5-gl_FragCoord.xy));
  dd=(vec2(texelFetch(depth,ivec2(gl_FragCoord.xy)+ivec2(d.x,0),0).r,texelFetch(depth,ivec2(gl_FragCoord.xy)+ivec2(0,d.y),0).r)-dep)*d;
  vec4 af=texelFetch(after,pix,0);
  vec4 al=texelFetch(albedo,pix,0);
  vec3 lit=af.rgb/al.rgb;
  float var=texelFetch(moment,pix,0).z;
  luminance=calcLuminance(af.rgb);

  for(int i=0;i<5;++i){
    a_trous(i,lit,var);
    if(i==1)before=vec4((any(isnan(lit))?vec3(0.0):lit)*al.rgb,af.a);
  }

  fragColor=vec4(toneMap(lit*al.rgb),1.0);
}

float filter_variance(){
  const float[3] gaussKernel = float[3](0.25, 0.5, 0.25);
  
  float sumLocalVars = 0.0;
  float sumVarWeights = 0.0;
  for (int i = -1; i <= 1; ++i) {
    const int nbPixY = clamp(pix.y + i, 0, imageSize.y - 1);
    const float hy = gaussKernel[i + 1];
    for (int j = -1; j <= 1; ++j) {
      const int nbPixX = clamp(pix.x + j, 0, imageSize.x - 1);
      const float hx = gaussKernel[j + 1];
      const ivec2 nbPix = ivec2(nbPixX, nbPixY);
      const float weight = hx * hy;
      sumLocalVars += weight * texelFetch(moment,nbPix,0).z;
      sumVarWeights += weight;
    }
  }
  return sqrt(sumLocalVars / sumVarWeights);
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

float calcLuminanceWeight(float nbLuminance,float luminance,float localMeanStdDev) {
    const float sigma_l = 4.0;
    const float eps = 1e-6;
    return exp(-abs(nbLuminance - luminance) / (sigma_l * localMeanStdDev + eps));
}

const int[5] stepWidths=int[5](1,2,4,8,16);
const float[9] Kernel_Weights=float[9](0.0625,0.125,0.0625,0.125,0.25,0.125,0.0625,0.125,0.0625);
const ivec2[9] Kernel_Offsets=ivec2[9](ivec2(-1,-1),ivec2(0,-1),ivec2(1,-1),
ivec2(-1,0),ivec2(0,0),ivec2(1,0),
ivec2(-1,1),ivec2(0,1),ivec2(1,1));

void a_trous(int stage,inout vec3 lit,inout float var){
  const int stepWidth=stepWidths[stage];
  const float centerWeight = Kernel_Weights[4];
  float sumWeights = centerWeight;
  vec3 denoisedLighting = centerWeight * lit;
  float variance = centerWeight*centerWeight * var;

  for (int i = 0; i < 9; ++i) {
    if (i == 4)
      continue;

    const ivec2 offset = ivec2(Kernel_Offsets[i].x * stepWidth, Kernel_Offsets[i].y * stepWidth);
    const ivec2 nbPix = ivec2(pix.x + offset.x, pix.y + offset.y);
    if (nbPix.x < 0 || nbPix.x >= imageSize.x ||
        nbPix.y < 0 || nbPix.y >= imageSize.y)
      continue;

    const float h = Kernel_Weights[i];

    const float nbDepth = texelFetch(depth,nbPix,0).r;
    if (nbDepth == 1.0)
      continue;
    const vec3 nbNormal = texelFetch(normal,nbPix,0).rgb;

    const float wz = calcDepthWeight(nbDepth, dep, dd.x, dd.y, float(offset.x), float(offset.y));
    const float wn = calcNormalWeight(nbNormal, nor);
    //if (h * wz * wn < 1e-6f)
    //    continue;

    vec3 noisyLighting=texelFetch(after,nbPix,0).rgb;
    const float nbLuminance = calcLuminance(noisyLighting);
    const float wl = calcLuminanceWeight(nbLuminance, luminance, localMeanStdDev);

    const float weight = h * wz * wn * wl;
    denoisedLighting += weight * noisyLighting;
    variance += weight*weight * texelFetch(moment,nbPix,0).z;
    sumWeights += weight;
  }
  denoisedLighting /= sumWeights;
  variance /= sumWeights*sumWeights;

  lit=denoisedLighting;
  var=variance;
}