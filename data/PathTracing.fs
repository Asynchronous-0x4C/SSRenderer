#version 460

#extension GL_ARB_bindless_texture : require
#extension GL_ARB_gpu_shader_int64 : require

#define FLT_MAX 3.402823466e+38

struct Ray{
  vec3 o;
  vec3 d;
  float IOR;
};

struct Triangle{
  vec4 v0;
  vec4 v1;
  vec4 v2;
  vec4 uv12;
};

struct Material{
  vec4 c;
  vec4 s;
  vec4 e;
  vec4 m_r_t_mr;
  vec4 I_ti_a_r;
};

struct Hit{
  bool hit;
  vec3 d;
  vec3 p;
  vec3 n;
  float l;
  float i;
  vec2 uv;
  Triangle t;
};

struct AABB{
  vec4 mn;
  vec4 mx;//If leaf,the index is -1.
};

layout(std430,binding=0)readonly buffer Triangles{
  Triangle[] tri;
};

layout(std430,binding=1)readonly buffer Materials{
  Material[] mat;
};

layout(std430,binding=2)readonly buffer BVH{
  AABB[] bvh;
};

layout(std430,binding=3)buffer Random{
  uint[] rnd;
};

layout(std430,binding=4)buffer Tex{
  uint64_t hnd[];
};

uniform sampler2D hdri;
uniform sampler2D depth;
uniform sampler2D normal;
uniform sampler2D ID;
uniform vec2 resolution;
uniform mat4 mvp;
uniform vec3 origin;

int pixel_idx;


out vec4 fragColor;

const int MAX_DEPTH=128;
const int NUM_REFLECT=3;
const float INV_PI=0.31830988618379;
const float PI=3.141592653589793;
const float TWO_PI=6.283185307179586;

vec3 trace_ray(in Ray r);
Hit hit_triangle(in Triangle t,in Ray r);
bool hit_AABB(in AABB b,in Ray r);
Hit traverse_BVH(in Ray r);
vec3 sample_HDRI(vec3 d);
vec3 BSDF(inout Ray r,Material m,inout Hit h);

uint xorshift32(inout uint x) {
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    return x;
}

float random(){
  return float(xorshift32(rnd[pixel_idx])) * 2.3283064e-10;
}

void main(){
  pixel_idx=int(gl_FragCoord.x)+int(gl_FragCoord.y)*int(resolution.x);
  Ray ray=Ray(origin,normalize((mvp*vec4((gl_FragCoord.xy*2.0-resolution)/resolution,1.0,1.0)).xyz),1.0);

  vec3 result=trace_ray(ray);
  fragColor=vec4(result,1.0);
}

float nz_sign(float x){
  return min(1.0,sign(x)+1.0)*2.0-1.0;
}

mat3 getBasisMat(vec3 n){
  float s=nz_sign(n.y);
  float a=-1.0/(s+n.y);
  float b=n.x*n.z*a;
  vec3 x=vec3(1.0+s*n.x*n.x*a,-s*n.x,s*b);
  vec3 z=vec3(b,-n.z,s+n.z*n.z*a);
  return mat3(x,n,z);
}

vec3 D2P(vec2 tc,float d){
  vec2 uv=tc*2.0-vec2(1.0);
  vec4 pp=vec4(uv,d*2.0-1.0,1.0);
  vec4 p=mvp*pp;
  return p.xyz/p.w;
}

vec3 getComponent(vec4 c,vec2 uv){
  return c.rgb*texture(sampler2D(hnd[int(c.w)]),uv).rgb;
}

vec3 getComponent_sRGB(vec4 c,vec2 uv){
  return c.rgb*pow(texture(sampler2D(hnd[int(c.w)]),uv).rgb,vec3(2.2));
}

vec3 getNormal(float i,Hit h){
  vec3 nor=texture(sampler2D(hnd[int(i)]),h.uv).rgb*2.0-1.0;

  vec3 e1=normalize(h.t.v1.xyz-h.t.v0.xyz);
  vec3 e2=normalize(h.t.v2.xyz-h.t.v0.xyz);
  vec2 u0=vec2(h.t.v1.w,h.t.v2.w);
  vec2 u1=h.t.uv12.xy-u0;
  vec2 u2=h.t.uv12.zw-u0;

  float _f=u1.x*u2.y-u2.x*u1.y;
  float f=1.0/_f;
  vec3 T=normalize(f*(u2.y*e1-u1.y*e2));
  vec3 B=normalize(f*(-u2.x*e1+u1.x*e2));

  return _f==0?h.n:normalize(mat3(T,B,h.n)*nor);
}

void calcColor(in Hit h,inout Ray r,inout vec3 c,inout vec3 w){
  Material m=mat[int(h.i)];
  m.c.rgb=getComponent_sRGB(m.c,h.uv);
  m.s.rgb=getComponent_sRGB(m.s,h.uv);
  m.e.rgb=getComponent_sRGB(m.e,h.uv);
  m.m_r_t_mr.rg=getComponent(m.m_r_t_mr,h.uv).rg;
  c+=w*m.e.rgb;
  mat3 basis=getBasisMat(getNormal(m.I_ti_a_r.g,h));
  r.d=transpose(basis)*r.d;
  w*=BSDF(r,m,h);
  r.d=basis*r.d;
  r.o=h.p+h.n*6e-4;
}

void FirstHit(inout Ray r,inout vec3 c,inout vec3 w,out bool hit){
  vec2 uv=gl_FragCoord.xy/resolution;
  vec4 id=texture(ID,uv);
  Hit h;
  h.p=D2P(uv,texture(depth,uv).r);
  h.n=texture(normal,uv).xyz;
  h.uv=id.yz;
  hit=id.w<0.5;
  if(hit){
    Material m=mat[int(id.x)];
    m.c.rgb=getComponent_sRGB(m.c,h.uv);
    m.s.rgb=getComponent_sRGB(m.s,h.uv);
    m.e.rgb=getComponent_sRGB(m.e,h.uv);
    m.m_r_t_mr.rg=getComponent(m.m_r_t_mr,h.uv).rg;
    c+=w*m.e.rgb;
    mat3 basis=getBasisMat(h.n);
    r.d=transpose(basis)*r.d;
    w*=BSDF(r,m,h);
    r.d=basis*r.d;
    r.o=h.p+h.n*6e-4;
  }else{
    c+=sample_HDRI(r.d);
  }
}

vec3 trace_ray(in Ray r){
  vec3 c=vec3(0.);
  vec3 w=vec3(1.);
  bool fhit=true;
  FirstHit(r,c,w,fhit);
  if(fhit){
    Hit hit;
    for(int i=0;i<NUM_REFLECT;i++){
      Hit h=traverse_BVH(r);
      if(h.hit){
        calcColor(h,r,c,w);
      }else{
        c+=w*sample_HDRI(r.d);
        break;
      }
    }
  }
  return c;
}

float Luminance(vec3 c){
  return dot(c,vec3(0.299,0.587,0.114));
}

vec3 sample_cos_hemisphere(out float pdf){
  float u=random();
  float v=random()*TWO_PI;
  vec2 d=u*vec2(cos(v),sin(v));
  float y=sqrt(max(0,1.0-u*u));
  pdf=y;
  return vec3(d.x,y,d.y);
}

vec3 Lambert(vec3 a){
  return a;
}

vec3 d_BRDF(inout Ray r,Material m,Hit h,out float pdf){
  vec3 o=sample_cos_hemisphere(pdf);
  r.d=o;
  vec3 c=Lambert(m.c.rgb);
  return c;
}

vec3 samplem(vec3 i,float alpha){
  float u=random();
  float v=random();
  vec3 V=normalize(vec3(alpha*i.x,i.y,alpha*i.z));
  vec3 n=V.y>0.99?vec3(1.0,0.0,0.0):vec3(0.0,1.0,0.0);
  vec3 t1=normalize(cross(V,n));
  vec3 t2=normalize(cross(t1,V));
  float r=sqrt(u);
  float a=1.0/(1.0+V.y);
  float phi=a>v?(PI*v/a):(PI*(v-a)/(1.0-a)+PI);
  float p1=r*cos(phi);
  float p2=r*sin(phi)*(a<v?V.y:1.0);
  vec3 N=p1*t1+p2*t2+sqrt(max(1.0-p1*p1-p2*p2,0.0))*V;
  return normalize(vec3(alpha*N.x,N.y,alpha*N.z));
}

vec3 F0(vec3 c,vec3 s,float m){
  vec3 f0_D=s*s*0.16;
  vec3 f0_C=c;
  return mix(f0_D,f0_C,m);
}

vec3 Fresnel(float cos_theta,vec3 f0){
  float a=1.0-cos_theta;
  return f0+(1.0-f0)*a*a*a*a*a;
}

float D_GGX(vec3 h,float alpha){
  if(alpha==0)return INV_PI;
  float t=sqrt(1.0/(h.y*h.y)-1.0);
  float t2=t*t;
  if(isinf(t2))return 0.0;
  float a2=alpha*alpha;
  float c4=h.y*h.y*h.y*h.y;
  float term=1.0+t2/a2;
  return INV_PI/(a2*c4*term*term);
}

float G1(vec3 v,float alpha){
  float d=alpha*sqrt(1.0/(v.y*v.y)-1.0);
  return 2.0/(1.0+sqrt(1.0+d*d));
}

float G_Lambda(vec3 v,float alpha){
  float d=max(alpha*sqrt(1.0/(v.y*v.y)-1.0),0.0);
  return max((-1.0+sqrt(1.0+d*d))/2.0,0.0);
}

float G_Smith(vec3 i,vec3 o,float alpha){
  //return 1.0/(1.0+G_Lambda(i,alpha)+G_Lambda(o,alpha));
  return G1(i,alpha)*G1(o,alpha);
}

vec3 s_BRDF(inout Ray r,Material m,Hit h,out float pdf){
  float rough=m.m_r_t_mr.g;
  float alpha=rough*rough;
  vec3 o=r.d;
  vec3 hv=samplem(-o,alpha);
  vec3 i=reflect(o,hv);
  vec3 F=Fresnel(abs(dot(o,hv)),F0(m.c.rgb,m.s.rgb,m.m_r_t_mr.r));
  float D=D_GGX(hv,alpha);
  // float G=G_Smith(i,o,alpha);
  // pdf=abs(dot(hv,i))/abs(hv.y);
  // pdf=(4.0*abs(dot(hv,i)))/G1(o,alpha);
  pdf=1.0;
  i.y=i.y<0.0?-i.y:i.y;
  r.d=i;
  // return F*G*D/(4.0*abs(i.y)*abs(o.y));
  return F;
}

vec3 s_BTDF(inout Ray r,Material m,inout Hit h,out float pdf){
  float rough=m.m_r_t_mr.g;
  float alpha=rough*rough;
  vec3 o=r.d;
  vec3 hv=samplem(-o,alpha);
  float i_IOR=dot(h.n,o)>0.0?m.I_ti_a_r.r:1.0;
  vec3 i=refract(o,hv,r.IOR/i_IOR);
  r.IOR=dot(i,o)<0.0?i_IOR:r.IOR;
  vec3 F=Fresnel(abs(dot(o,hv)),F0(m.c.rgb,m.s.rgb,m.m_r_t_mr.r));
  // float D=D_GGX(hv,alpha);
  // float G=G_Smith(i,o,alpha);
  // pdf=D*G1(o,alpha)/(4.0*abs(dot(hv,i)));
  // pdf=(4.0*abs(dot(hv,i)))/G1(o,alpha);
  h.n=-h.n;
  pdf=1.0;
  r.d=i;
  // return F*G*D/(4.0*abs(i.y)*abs(o.y));
  return m.c.rgb/(i_IOR*i_IOR);
}

vec3 BSDF(inout Ray r,Material m,inout Hit h){
  float pdf;
  vec3 c;
  float rnd=random();
  float ks=Luminance(Fresnel(abs(r.d.y),F0(vec3(1.0),m.s.rgb,m.m_r_t_mr.g)));
  float inv_ks=1.0-ks;
  float kt=inv_ks*m.m_r_t_mr.b*(1.0-m.m_r_t_mr.g);
  float kd=(inv_ks-kt)*(1.0-m.m_r_t_mr.g);
  ks=1.0-kt-kd;
  if(rnd<kt){
    c=s_BTDF(r,m,h,pdf)/kt;
  }else if(rnd<(kd+kt)){
    c=d_BRDF(r,m,h,pdf)/kd;
  }else{
    c=s_BRDF(r,m,h,pdf)/ks;
  }
  return c*pdf;
}

Hit traverse_BVH(in Ray r){
  Hit h;
  h.hit=false;
  h.l=FLT_MAX;

  int stack[MAX_DEPTH];
  int idx=0;

  stack[idx++]=0;

  while(idx>0){
    int c=stack[--idx];
    int R=int(bvh[c].mn.w);
    int L=int(bvh[c].mx.w);
    if(L==-1){
      Hit ht=hit_triangle(tri[R],r);
      h=h.l>ht.l?ht:h;
    }else{
      if(hit_AABB(bvh[c],r)){
        stack[idx++]=R;
        stack[idx++]=L;
      }
    }
  }
  return h;
}

Hit hit_triangle(in Triangle t,in Ray r){
  Hit hit;
  hit.hit=false;
  hit.l=FLT_MAX;
  vec3 e1 = t.v1.xyz-t.v0.xyz;
  vec3 e2 = t.v2.xyz-t.v0.xyz;
  
  vec3 alpha = cross(r.d, e2);
  float det = dot(e1, alpha);
  
  float invDet = 1.0f / det;
  vec3 r_ = r.o - t.v0.xyz;
  
  float u = dot(alpha, r_) * invDet;
  if (u < 0.0f || u > 1.0f) {
    return hit;
  }
  
  vec3 beta = cross(r_, e1);
  
  float v = dot(r.d, beta) * invDet;
  if (v < 0.0f || u + v > 1.0f) {
    return hit;
  }
  
  float t_ = dot(e2, beta) * invDet;
  if (t_ < 0.0) {
    return hit;
  }
  hit.hit=true;
  hit.d=r.d;
  hit.p=r.o+r.d*t_;
  hit.n=normalize(cross(e1,e2))*nz_sign(det);
  hit.l=t_;
  hit.i=t.v0.w;
  vec2 b_uv=vec2(t.v1.w,t.v2.w);
  hit.uv=(1.0-u-v)*b_uv+u*t.uv12.xy+v*t.uv12.zw;
  hit.t=t;
  
  return hit;
}

bool hit_AABB(in AABB b,in Ray r){
  vec3 t1v=(b.mn.xyz-r.o)/r.d;
  vec3 t2v=(b.mx.xyz-r.o)/r.d;
  vec3 nv=min(t1v,t2v);
  vec3 fv=max(t1v,t2v);
  return max(0.0,max(nv.x,max(nv.y,nv.z)))<=min(fv.x,min(fv.y,fv.z));
}

float atan2(in float y, in float x){
  return x == 0.0 ? sign(y)*PI/2.0 : atan(y, x);
}

vec2 calcUVSphere(in vec3 dir){
  vec2 uv;
  float theta = acos(clamp(dir.y, -1.0, 1.0));
  float p = atan2(dir.z, dir.x);
  float phi = (p < 0.0) ? (p + PI*2.0) : p;

  uv.y = clamp(theta / PI, 0.0, 1.0);
  uv.x = clamp(phi / (PI*2.0), 0.0, 1.0);
  return uv;
}

vec3 sample_HDRI(vec3 d){
  return texture(hdri,calcUVSphere(d)).rgb;
}