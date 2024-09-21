#version 460

#extension GL_ARB_bindless_texture : require
struct Ray{
  vec3 o;
  vec3 d;
  float IOR;
};

layout(location=3)in vec2 position;

void main(){
  gl_Position=vec4(position,0.,1.);
}