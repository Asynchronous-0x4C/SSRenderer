#version 460

precision highp float;

uniform mat4 mvp;
uniform mat4 shadow_mvp;
uniform sampler2D position;
uniform sampler2D normal;
uniform sampler2D color;
uniform sampler2D specular;
uniform sampler2DShadow shadow;
uniform vec2 resolution;
uniform bool use_shadow;

struct Light{
  vec3 position;
  vec3 color;
};

uniform Light light;

layout(location=0)out vec4 fragColor;
layout(location=1)out vec4 cpyColor;

const float PI=3.1415926525;
const float shadowBias = 0.0001;

vec3 Lambert(vec3 albedo){
  return albedo/PI;
}

float G2_Smith(float NdV,float NdL,float a){
  NdV=abs(NdV)+1e-5;
  NdL=abs(NdL);
  float a2=a*a;
  float GGXV = NdL*sqrt(NdV*NdV*(1.0-a2)+a2);
  float GGXL = NdV*sqrt(NdL*NdL*(1.0-a2)+a2);
  return 0.5/(GGXV+GGXL);
}

float D_GGX(float a,float NdH){
  NdH=abs(NdH);
  float a2=a*a;
  float b=1.0+(NdH*NdH)*(a2-1.0);
  return a2/(b*b*PI);
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

vec3 Shlick_Scalar(float NdL,vec3 specular,float m){
  vec3 f0=mix(0.16*specular*specular,vec3(1.0),m);
  float a=1.0-NdL;
  return f0+(1.0-f0)*(a*a*a*a*a);
}

vec3 Specular_GGX(vec3 N,vec3 L,vec3 V,vec3 albedo,vec3 specular,float metallic,float roughness){
  vec3 H=normalize(L+V);
  float NdV=abs(dot(N,V));
  float NdL=abs(dot(N,L));
  float NdH=abs(dot(N,H));

  float a=roughness*roughness;
  vec3 f0=Flesnel0(albedo,specular,metallic);

  vec3 F=Shlick(f0,NdL);
  float D=D_GGX(a,NdH);
  float G=G2_Smith(NdV,NdL,a);
  
  return F*G*D;
}

vec3 BRDF(vec3 N,vec3 L,vec3 V,vec3 albedo,vec3 specular,float metallic,float roughness){
  vec3 ratio=Shlick_Scalar(abs(dot(N,L)),specular,metallic);

  vec3 ggx_diffuse=Lambert(albedo);
  vec3 ggx_specular=Specular_GGX(N,L,V,albedo,specular,metallic,roughness);
  
  return mix(ggx_diffuse,max(vec3(0.0),ggx_specular),ratio)*abs(dot(N,L));
}

float calculateShadow(vec4 lightSpacePos) {
  vec3 projCoords = lightSpacePos.xyz / lightSpacePos.w;
  projCoords = projCoords * 0.5 + 0.5;

  return texture(shadow, vec3(projCoords.xy, projCoords.z - shadowBias));
}

void main(){
  vec2 uv=(gl_FragCoord.xy/resolution)*2.0-1.0;
  vec3 rayDirection=normalize((inverse(mvp)*vec4(uv,1.0,1.0)).xyz);

  ivec2 icoord=ivec2(gl_FragCoord.xy);
  vec4 pos_r=texelFetch(position,icoord,0);
  vec4 nor_m=texelFetch(normal,icoord,0);
  vec3 f_albedo=texelFetch(color,icoord,0).rgb;
  vec3 f_specular=texelFetch(specular,icoord,0).rgb;
  vec3 f_position=pos_r.xyz;
  vec3 f_normal=normalize(nor_m.xyz);
  float roughness=pos_r.a;
  float metalness=nor_m.a;

  vec3 light_dir=normalize(light.position-f_position);

  vec3 result_color=vec3(0.0);

  if(!use_shadow){
    fragColor=vec4(BRDF(f_normal,light_dir,-rayDirection,f_albedo,f_specular,metalness,roughness)*light.color,1.0);
    cpyColor=fragColor;
    return;
  }
  if(length(f_normal)>0.01&&sign(dot(f_normal,light_dir))==sign(dot(f_normal,-rayDirection))){
    vec4 shadowCoord=shadow_mvp*vec4(f_position,1.0);
    float light_strength=calculateShadow(shadowCoord);
    // if(<0.75){
    //   fragColor=vec4(result_color,1.0);
    //   return;
    // }
    result_color+=BRDF(f_normal,light_dir,-rayDirection,f_albedo,f_specular,metalness,roughness)*light.color*light_strength;
  }

  fragColor=vec4(result_color,1.0);
  cpyColor=fragColor;
}