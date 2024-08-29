#version 460

#define FLT_MAX 3.402823466e+38

struct Ray{
  vec3 o;
  vec3 d;
  float IOR;
};

struct Hit{
  bool hit;
  vec3 d;
  vec3 p;
  vec3 n;
  float l;
  float i;
};

struct Triangle{
  vec4 v0;
  vec4 v1;
  vec4 v2;
};

struct Material{
  vec4 c_r;
  vec4 s_m;
  vec4 e_t;
  vec4 I_ti_a_r;
};

struct AABB{
  vec4 mn;
  vec4 mx;//If leaf,the index is -1.
};

layout(std430,binding=0)buffer Triangles{
  Triangle[] tri;
};

layout(std430,binding=1)buffer Materials{
  Material[] mat;
};

layout(std430,binding=2)buffer BVH{
  AABB[] bvh;
};

layout(std430,binding=3)buffer Random{
  uint[] rnd;
};

uniform sampler2D hdri;
uniform vec2 resolution;

int pixel_idx;

in Ray in_ray;

out vec4 fragColor;

const int MAX_DEPTH=128;
const int NUM_REFLECT=4;
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
  Ray ray=Ray(in_ray.o,normalize(in_ray.d),1.0);

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

vec3 trace_ray(in Ray r){
  vec3 c=vec3(0.);
  vec3 w=vec3(1.);
  Hit hit;
  for(int i=0;i<NUM_REFLECT;i++){
    Hit h=traverse_BVH(r);
    if(h.hit){
      Material m=mat[int(h.i)];
      c+=w*m.e_t.rgb;
      mat3 basis=getBasisMat(h.n);
      r.d=transpose(basis)*r.d;
      w*=BSDF(r,m,h);
      r.d=basis*r.d;
      r.o=h.p+h.n*6e-4;
    }else{
      c+=w*sample_HDRI(r.d);
      break;
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
  pdf=u*INV_PI;
  return vec3(d.x,y,d.y);
}

vec3 Lambert(vec3 a){
  return a;
}

vec3 d_BRDF(inout Ray r,Material m,Hit h,out float pdf){
  vec3 o=sample_cos_hemisphere(pdf);
  r.d=o;
  vec3 c=Lambert(m.c_r.rgb);
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
  float alpha=m.c_r.a*m.c_r.a;
  vec3 o=r.d;
  vec3 hv=samplem(-o,alpha);
  vec3 i=reflect(o,hv);
  vec3 F=Fresnel(abs(dot(o,hv)),F0(m.c_r.rgb,m.s_m.rgb,m.s_m.a));
  // float D=D_GGX(hv,alpha);
  // float G=G_Smith(i,o,alpha);
  // pdf=D*G1(o,alpha)/(4.0*abs(dot(hv,i)));
  // pdf=(4.0*abs(dot(hv,i)))/G1(o,alpha);
  pdf=1.0;
  i.y=i.y<0.0?-i.y:i.y;
  r.d=i;
  // return F*G*D/(4.0*abs(i.y)*abs(o.y));
  return F;
}

vec3 s_BTDF(inout Ray r,Material m,inout Hit h,out float pdf){
  float alpha=m.c_r.a*m.c_r.a;
  vec3 o=r.d;
  vec3 hv=samplem(-o,alpha);
  float i_IOR=dot(h.n,o)>0.0?m.I_ti_a_r.r:1.0;
  vec3 i=refract(o,hv,r.IOR/i_IOR);
  r.IOR=dot(i,o)<0.0?i_IOR:r.IOR;
  vec3 F=Fresnel(abs(dot(o,hv)),F0(m.c_r.rgb,m.s_m.rgb,m.s_m.a));
  // float D=D_GGX(hv,alpha);
  // float G=G_Smith(i,o,alpha);
  // pdf=D*G1(o,alpha)/(4.0*abs(dot(hv,i)));
  // pdf=(4.0*abs(dot(hv,i)))/G1(o,alpha);
  h.n=-h.n;
  pdf=1.0;
  r.d=i;
  // return F*G*D/(4.0*abs(i.y)*abs(o.y));
  return m.c_r.rgb/(i_IOR*i_IOR);
}

vec3 BSDF(inout Ray r,Material m,inout Hit h){
  float pdf;
  vec3 c;
  float rnd=random();
  float ks=Luminance(Fresnel(abs(r.d.y),F0(vec3(1.0),m.s_m.rgb,m.s_m.a)));
  float inv_ks=1.0-ks;
  float kt=inv_ks*m.e_t.a*(1.0-m.s_m.a);
  float kd=(inv_ks-kt)*(1.0-m.s_m.a);
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