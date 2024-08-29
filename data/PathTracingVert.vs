#version 460

struct Ray{
  vec3 o;
  vec3 d;
  float IOR;
};

layout(location=3)in vec2 position;

uniform mat4 mvp;

out Ray in_ray;

void main(){
  gl_Position=vec4(position,0.,1.);
  in_ray=Ray(mvp[3].xyz,(mvp*vec4(position,1.0,1.0)).xyz,1.0);
}