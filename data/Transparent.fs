#version 460

uniform mat4 ibl_mvp;
uniform vec2 resolution;
uniform float time;
uniform vec3 color;
uniform vec3 specular;
uniform vec3 emission;
uniform float roughness;
uniform float metalness;
uniform float transmission;
uniform float max_mip_level;

uniform sampler2D t_color;
uniform sampler2D t_normal;
uniform sampler2D t_specular;
uniform sampler2D t_albedo;
uniform sampler2D t_MR;
uniform sampler2D t_depth;
uniform samplerCube sky;

out vec4 fragColor;

in vec4 w_position;
in vec3 w_normal;
in vec3 w_tangent;
in vec3 w_bitangent;
in vec2 w_uv;

const float inv_PI=0.3183098861;

vec3 Lambert(vec3 albedo){
  return albedo*inv_PI;
}

vec3 sampleHDRI(vec3 v,int lod){
  return textureLod(sky,v,lod).rgb;
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

vec3 BRDF_IBL(vec3 N,vec3 L,vec3 V,vec3 albedo,vec3 specular,float metallic,float roughness){
  vec3 f0=Flesnel0(albedo,specular,metallic);
  vec3 flesnel=Shlick(f0,abs(dot(N,V)));

  vec3 ggx_specular=sampleHDRI(L,int(log2(roughness*max_mip_level*max_mip_level)));
  
  return ggx_specular*flesnel;
}

vec3 GetNormal() {
  mat3 TBN = mat3(w_tangent, w_bitangent, w_normal);
  vec3 normalFromMap = texture(t_normal,w_uv).rgb*2.0-1.0;
  return normalize(TBN * normalFromMap);
}

void main(){
  vec2 uv=(gl_FragCoord.xy/resolution)*2.0-1.0;
  vec3 rayDirection=normalize((ibl_mvp*vec4(uv,1.0,1.0)).xyz);

  vec4 out_position=vec4(w_position.xyz,1.0);
  float out_roughness=roughness*texture(t_MR,w_uv).g;
  vec4 out_normal=vec4(GetNormal(),1.0);
  float out_metalness=metalness*texture(t_MR,w_uv).r;
  vec4 out_color=vec4(color,1.0)*texture(t_color,w_uv);
  vec4 out_specular=vec4(specular,1.0)*texture(t_specular,w_uv);
  vec4 background=vec4(texelFetch(t_albedo,ivec2(gl_FragCoord.xy),0).rgb,1.0);

  if(texelFetch(t_depth,ivec2(gl_FragCoord.xy),0).r<gl_FragCoord.z){
    fragColor=vec4(0.);
    return;
  }

  vec3 reflectDir=normalize(reflect(rayDirection,out_normal.xyz));
  fragColor=vec4(0.,0.,0.,1.);

  fragColor=vec4(BRDF_IBL(out_normal.xyz,reflectDir,-rayDirection,out_color.rgb,out_specular.rgb,out_metalness,out_roughness),1.0);

  fragColor+=vec4(mix(Lambert(out_color.rgb),out_color.rgb*background.rgb,transmission),0.0);
}