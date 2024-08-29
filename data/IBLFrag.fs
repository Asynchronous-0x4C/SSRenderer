#version 460

uniform mat4 mvp;
uniform sampler2D position;
uniform sampler2D normal;
uniform sampler2D color;
uniform sampler2D depth;
uniform sampler2D specular;
uniform samplerCube sky;
uniform vec2 resolution;
uniform float intensity;
uniform float max_mip_level;

layout(location=0)out vec4 fragColor;
layout(location=1)out vec4 cpyColor;

const float PI=3.1415926525;
const float inv_PI=0.3183098861;

vec3 sampleHDRI(vec3 v,int lod){
  return textureLod(sky,v,lod).rgb;
}

vec3 Lambert(vec3 albedo){
  return albedo*inv_PI;
}

vec3 Flesnel0(vec3 albedo,vec3 specular,float metallic){
  vec3 f0_D=specular*specular*0.16;
  vec3 f0_C=albedo;
  return mix(f0_D,f0_C,metallic);
}

vec3 Shlick(vec3 f0,float NdL){
  float a=1.0-NdL;
  return f0+(vec3(1.0)-f0)*(a*a*a*a*a);
}

// vec3 Shlick_Scalar(float NdL,vec3 specular,float m){
//   vec3 f0=mix(0.16*specular*specular,vec3(1.0),m);
//   float a=1.0-NdL;
//   return f0+(1.0-f0)*(a*a*a*a*a);
// }

// vec3 Specular_GGX(vec3 N,vec3 L,vec3 albedo,vec3 specular,float metallic){
//   float NdL=abs(dot(N,L));
//   vec3 f0=Flesnel0(albedo,specular,metallic);

//   vec3 F=Shlick(f0,NdL);
  
//   return F;
// }

vec3 BRDF_IBL(vec3 N,vec3 L,vec3 V,vec3 albedo,vec3 specular,float metallic,float roughness){
  vec3 f0=Flesnel0(albedo,specular,metallic);
  vec3 flesnel=Shlick(f0,abs(dot(N,V)));

  vec3 ggx_diffuse=Lambert(albedo)*sampleHDRI(N,int(max_mip_level));
  vec3 ggx_specular=sampleHDRI(L,int(log2(roughness*max_mip_level*max_mip_level)));
  
  return mix(ggx_diffuse*(1.0-metallic),ggx_specular,flesnel);
}

void main(){
  vec2 uv=(gl_FragCoord.xy/resolution)*2.0-1.0;
  vec3 ray_dir=normalize((mvp*vec4(uv,1.0,1.0)).xyz);
  
  ivec2 icoord=ivec2(gl_FragCoord.xy);
  vec4 pos_r=texelFetch(position,icoord,0);
  vec4 nor_m=texelFetch(normal,icoord,0);
  vec3 f_albedo=texelFetch(color,icoord,0).rgb;
  vec3 f_specular=texelFetch(specular,icoord,0).rgb;

  vec3 f_position=pos_r.xyz;
  vec3 f_normal=normalize(nor_m.xyz);
  float f_depth=texelFetch(depth,icoord,0).r;
  float roughness=pos_r.a;
  float metalness=nor_m.a;

  if(length(f_depth)!=1.0){
    vec3 reflect_dir=normalize(reflect(ray_dir,f_normal)+f_normal*roughness*roughness);
    fragColor=vec4(BRDF_IBL(f_normal,reflect_dir,-ray_dir,f_albedo,f_specular,metalness,roughness),1.0);
  }else{
    fragColor=vec4(0.0);
  }
  fragColor.rgb*=intensity;
  cpyColor=fragColor;
}