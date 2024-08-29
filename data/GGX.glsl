const float PI=3.1415926525;

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