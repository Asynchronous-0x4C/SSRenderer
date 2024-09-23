import java.util.function.*;

import java.awt.Robot;

class SObject{
  
}

abstract class RObject extends SObject{
  
}

class Level extends RObject{
  HashMap<String,Component>components;
  
  Level(){
    components=new HashMap<>();
  }
  
  Level add(String s,Component c){
    components.put(s,c);
    return this;
  }
  
  void update(){
    components.forEach((k,v)->{
      v.update();
    });
  }
  
  void prepass(Renderer r){
    components.forEach((k,v)->{
      v.prepass(r);
    });
  }
  
  void rt_prepass(RayTracer r){
    components.forEach((k,v)->{
      v.rt_prepass(r);
    });
  }
  
  void transparent(Rasterizer r){
    components.forEach((k,v)->{
      v.transparent(r);
    });
  }
  
  void shadow_map(HashMap<String,LightComponent>lights){
    lights.forEach((k,v)->{
      if(!v.cast_shadow)return;
      v.fb.bind();
      gl.glViewport(0,0,v.x,v.y);
      gl.glClear(GL4.GL_DEPTH_BUFFER_BIT);
      components.forEach((k2,v2)->{
        if(v2 instanceof StaticMesh){
          StaticMesh sm=(StaticMesh)v2;
          sm.shadow(v);
        }
      });
      v.fb.unbind();
    });
  }
  
  void putSSBOData(){
    components.forEach((s,c)->{
      if(c instanceof StaticMesh)((StaticMesh)c).putSSBOData();
    });
  }
}

class Movement extends RObject{
  
}

abstract class Component extends RObject{
  Transform transform;
  
  boolean visible=true;
  
  Component(){
    transform=new Transform();
  }
  
  abstract void update();
  
  abstract void prepass(Renderer r);
  
  void transparent(Rasterizer r){}
  
  abstract void rt_prepass(RayTracer r);
  
  void postProcess(){}
}

abstract class Pawn extends Component{
  Movement movement;
  StaticMesh mesh;
  Camera camera;
}

class DefaultPlayer extends Pawn{
  PlayerCapsule capsule;
  DBody body;
  
  float speed=5;
  
  DefaultPlayer(){
    movement=new Movement();
    transform=new Transform();
    //transform.setTransform(1.69105,2.0,36.1304);
    transform.setTransform(0,1,0);
    camera=new Camera();
    camera.free=false;
    camera.setPerspective(radians(70), 16.0/9.0, 0.1, 1000.0);
    
    capsule=new PlayerCapsule((DxSpace)space,0.3,1);
    body=OdeHelper.createBody(world);
    DMass mass=OdeHelper.createMass();
    mass.setCapsule(1,2,0.3,2);
    body.setMass(mass);
    capsule.setBody(body);
    
    //body.setPosition(1.69105,2.0,36.1304);
    body.setPosition(0,1,0);
    Matrix3d m=new Matrix3d();
    m=m.rotateX(HALF_PI);
    body.setRotation(new DMatrix3(m.m00,m.m01,m.m02,m.m10,m.m11,m.m12,m.m20,m.m21,m.m22));
  }
  
  void update(){
    DVector3 pos=new DVector3(body.getPosition());
    pos.add1(capsule.getLength()*0.5+capsule.getRadius());
    camera.origin.set(pos.toFloatArray());
    camera.update();
    
    Vector3d localTransform=new Vector3d(0,0,0);
    main_input.getKeyBoard().getPressedKeys().forEach((c)->{
      switch(String.valueOf((char)(int)c).toLowerCase()){
        case "w":localTransform.sub(0.0,0.0,speed);break;
        case "s":localTransform.add(0.0,0.0,speed);break;
        case "d":localTransform.add(speed,0.0,0.0);break;
        case "a":localTransform.sub(speed,0.0,0.0);break;
        default:break;
      }
    });
    Vector3d angles=new Vector3d();
    camera.rot.getEulerAnglesXYZ(angles);
    localTransform.rotateY(-radians(camera.mouseMove.x)*camera.sensitivity);
    localTransform.y=0;
    if(body.getLinearVel().get1()<0){
      localTransform.mul(0.01);
    }
    
    body.addLinearVel(localTransform.x,localTransform.y,localTransform.z);
    body.setAngularVel(0,0,0);
    Matrix3d m=new Matrix3d();
    m=m.rotateX(HALF_PI);
    body.setRotation(new DMatrix3(m.m00,m.m01,m.m02,m.m10,m.m11,m.m12,m.m20,m.m21,m.m22));
  }
  
  void prepass(Renderer r){}
  
  void rt_prepass(RayTracer r){}
}

class Camera extends Component{
  Matrix4d view;
  Matrix4d proj;
  Vector3d origin;
  Quaterniond rot;
  
  float fov;
  float aspect;
  float near;
  float far;
  
  float speed=0.2;
  float sensitivity=0.1;
  float smoothness=0.5;
  
  Vector2f mouseMove=new Vector2f();
  Vector2f mouseTarget=new Vector2f();

  Robot robot;
  
  boolean cursor=true;
  boolean free=true;
  
  Camera(){
    super();
    view=new Matrix4d();
    proj=new Matrix4d();
    origin=new Vector3d();
    rot=new Quaterniond();
    try{
      robot=new Robot();
    }catch(Exception e){}
  }
  
  void lookAt(Vector3d eye,Vector3d center,Vector3d up){
    view.identity();
    view.lookAt(eye,center,up);
    transform.setTransform(eye);
  }
  
  void setPerspective(float fov,float aspect,float near,float far){
    proj.identity();
    proj.perspective(fov,aspect,near,far);//aspect:x/y
    this.fov=fov;
    this.aspect=aspect;
    this.near=near;
    this.far=far;
  }
  
  void setOrtho(float l,float r,float b,float t,float near,float far){
    proj.identity();
    proj.ortho(l,r,b,t,near,far);
  }
  
  void update(){
    if(main_input.isWindowFocused()){
      if(cursor){
        cursor=false;
        noCursor();
      }
      mouseTarget.add(mouseX-floor(width*0.5),mouseY-floor(height*0.5));
      if(!free){
        mouseMove.y=constrain(mouseMove.y,-90/sensitivity,90/sensitivity);
        mouseTarget.y=constrain(mouseTarget.y,-90/sensitivity,90/sensitivity);
      }
      rot.rotateLocalY(-radians((mouseTarget.x-mouseMove.x)*smoothness*sensitivity));
      rot.rotateX(-radians((mouseTarget.y-mouseMove.y)*smoothness*sensitivity));
      mouseMove.add(new Vector2f(mouseTarget).sub(mouseMove).mul(smoothness));
      robot.mouseMove(((com.jogamp.newt.opengl.GLWindow)surface.getNative()).getX()+width/2,((com.jogamp.newt.opengl.GLWindow)surface.getNative()).getY()+height/2);
    }else{
      if(!cursor){
        cursor=true;
        cursor();
      }
    }
    if(free){
      Vector3d localTransform=new Vector3d(0,0,0);
      main_input.getKeyBoard().getPressedKeys().forEach((c)->{
        switch(String.valueOf((char)(int)c).toLowerCase()){
          case "w":localTransform.sub(0.0,0.0,speed);break;
          case "s":localTransform.add(0.0,0.0,speed);break;
          case "e":localTransform.add(0.0,speed,0.0);break;
          case "q":localTransform.sub(0.0,speed,0.0);break;
          case "d":localTransform.add(speed,0.0,0.0);break;
          case "a":localTransform.sub(speed,0.0,0.0);break;
          default:break;
        }
      });
      localTransform.rotate(rot);
      origin.add(localTransform);
    }
    lookAt(origin,new Vector3d(origin).add(new Vector3d(0,0,-1).rotate(rot)),new Vector3d(0,1,0).rotate(rot).normalize());
  }
  
  void prepass(Renderer r){}
  
  void rt_prepass(RayTracer r){}
}

class StaticMesh extends Component{
  Matrix4d model;
  ArrayList<Segment> segments;
  
  Matrix4d p_mvp;
  
  int mesh_vertex_count=0;
  
  StaticMesh(float[] vertices){
    
  }
  
  StaticMesh(Map<String,MeshData> obj,Map<String,Material>allMtl,Matrix4d model){
    super();
    this.model=model;
    segments=new ArrayList<>();
    main_cache.register.put(this,new HashSet<>());
    obj.forEach((k,v)->{
      segments.add(new Segment(v,allMtl.get(k)));
      main_cache.register.get(this).add(allMtl.get(k).getName());
    });
  }
  
  void putSSBOData(){
    segments.forEach(s->s.putSSBOData());
  }
  
  void applyTransforms(){
    model.identity();
    model.translation(transform.transform).rotation(transform.rotate).scale(transform.scale);
  }
  
  void update(){
    
  }
  
  void rt_prepass(RayTracer r){
    Matrix4d mvp=new Matrix4d();
    mvp.set(r.player.camera.proj).mul(r.player.camera.view).mul(model);
    if(p_mvp==null)p_mvp=new Matrix4d(mvp);
    segments.forEach(s->{
      s.prepass(mvp,model);
    });
    p_mvp=new Matrix4d(mvp);
  }
  
  void prepass(Renderer r){profiler.start(toString());
    Matrix4d mvp=new Matrix4d();
    mvp.set(r.player.camera.proj).mul(r.player.camera.view).mul(model);
    segments.forEach(s->{
      s.display(mvp,model);
    });profiler.end(toString());
  }
  
  void transparent(Rasterizer r){
    Matrix4d mvp=new Matrix4d();
    mvp.set(r.player.camera.proj).mul(r.player.camera.view).mul(model);
    segments.forEach(s->{
      s.transparent(mvp,model,r);
    });
  }
  
  void shadow(LightComponent light){
    Matrix4d mvp=new Matrix4d();
    mvp.set(light.projection).mul(light.view).mul(model);
    segments.forEach(s->{
      s.shadow(mvp);
    });
  }
  
  void destroy(){
    
  }
  
  class Segment{
    VertexArray vertex_array;
    Buffer vertex_buffer;
    ShaderProgram program;//const.?
    Material material;
    int material_index;
    
    float[] vertices;
    float[] uvs;
    
    VertexArray s_vertex_array;
    Buffer s_vertex_buffer;
    ShaderProgram shadow_program;//const.?
    
    ShaderProgram transparent_program;//const.?
    
    ShaderProgram prepass_program;
    
    int vertex_count;
    DTriMesh triMesh;
    
    RenderModel renderModel=RenderModel.Opaque;
    
    Segment(MeshData obj,Material mtl){
      if(mtl.transmission.param>0){
        renderModel=RenderModel.Transparent;
      }
      
      mesh_vertex_count+=obj.vertices_count;
      vertex_count=obj.vertices_count;
      float[] attr=obj.getAttribute();
      
      Shader vertex_shader=new Shader(getProgram("RTvert.vs"), GL4.GL_VERTEX_SHADER);
      Shader fragment_shader=new Shader(getProgram("RTfrag.fs"), GL4.GL_FRAGMENT_SHADER);
      program=new ShaderProgram(vertex_shader, fragment_shader);
      material=mtl;
      material_index=materials.indexOf(material);
      
      vertex_buffer=new Buffer(GL4.GL_ARRAY_BUFFER);
      vertex_buffer.set_data(FloatBuffer.wrap(attr), GL4.GL_STATIC_DRAW);
      vertex_array=new VertexArray();
      vertex_array.bind();
      vertex_array.set_attribute(program.get_attrib_location("position"), 3, obj.components*Float.BYTES, 0);
      vertex_array.set_attribute(program.get_attrib_location("normal"), 3, obj.components*Float.BYTES, 3*Float.BYTES);
      vertex_array.set_attribute(program.get_attrib_location("tangent"), 3, obj.components*Float.BYTES, 6*Float.BYTES);
      vertex_array.set_attribute(program.get_attrib_location("texCoord"), 2, obj.components*Float.BYTES, 9*Float.BYTES);
      
      vertex_shader=new Shader(getProgram("S_DirectionalLightVert.vs"), GL4.GL_VERTEX_SHADER);
      fragment_shader=new Shader(getProgram("S_DirectionalLightFrag.fs"), GL4.GL_FRAGMENT_SHADER);
      shadow_program=new ShaderProgram(vertex_shader, fragment_shader);
      s_vertex_buffer=new Buffer(GL4.GL_ARRAY_BUFFER);
      s_vertex_buffer.set_data(FloatBuffer.wrap(attr), GL4.GL_STATIC_DRAW);
      s_vertex_array=new VertexArray();
      s_vertex_array.bind();
      s_vertex_array.set_attribute(shadow_program.get_attrib_location("position"), 3, obj.components*Float.BYTES, 0);
      
      vertex_shader=new Shader(getProgram("TransparentVert.vs"), GL4.GL_VERTEX_SHADER);
      fragment_shader=new Shader(getProgram("Transparent.fs"), GL4.GL_FRAGMENT_SHADER);
      transparent_program=new ShaderProgram(vertex_shader, fragment_shader);
      
      vertex_shader=new Shader(getProgram("PrepassVert.vs"), GL4.GL_VERTEX_SHADER);
      fragment_shader=new Shader(getProgram("Prepass.fs"), GL4.GL_FRAGMENT_SHADER);
      prepass_program=new ShaderProgram(vertex_shader, fragment_shader);
      
      DTriMeshData triMeshData=OdeHelper.createTriMeshData();
      triMeshData.build(obj.vertices,IntStream.rangeClosed(0,obj.vertices.length/3-1).toArray());
      
      triMesh=OdeHelper.createTriMesh(space,triMeshData);
      Matrix3d _model=new Matrix3d();
      model.get3x3(_model);
      double[] d=new double[9];
      _model.get(d);
      triMesh.setRotation(new DMatrix3(d[0],d[1],d[2],d[3],d[4],d[5],d[6],d[7],d[8]));
      triMesh.setPosition(model.m30(),model.m31(),model.m32());
      vertices=new float[obj.vertices.length];
      for(int i=0;i<vertices.length;i+=3){
        Vector4f v=new Vector4f(obj.vertices[i],obj.vertices[i+1],obj.vertices[i+2],1.0);
        v=v.mul(new Matrix4f(model));
        vertices[i  ]=v.x;
        vertices[i+1]=v.y;
        vertices[i+2]=v.z;
      }
      uvs=obj.uv;
      //vertices=obj.vertices;
    }
    
    Segment(float[]vertices){
      
    }
    
    void putSSBOData(){
      for(int i=0,n=vertices.length/9;i<n;++i){
        ssbo_vertices.add(vertices[i*9  ]);
        ssbo_vertices.add(vertices[i*9+1]);
        ssbo_vertices.add(vertices[i*9+2]);
        ssbo_vertices.add((float)material_index);
        ssbo_vertices.add(vertices[i*9+3]);
        ssbo_vertices.add(vertices[i*9+4]);
        ssbo_vertices.add(vertices[i*9+5]);
        ssbo_vertices.add(uvs[i*6  ]);
        ssbo_vertices.add(vertices[i*9+6]);
        ssbo_vertices.add(vertices[i*9+7]);
        ssbo_vertices.add(vertices[i*9+8]);
        ssbo_vertices.add(uvs[i*6+1]);
        ssbo_vertices.add(uvs[i*6+2]);
        ssbo_vertices.add(uvs[i*6+3]);
        ssbo_vertices.add(uvs[i*6+4]);
        ssbo_vertices.add(uvs[i*6+5]);
      }
    }
    
    void display(Matrix4d mvp,Matrix4d model){
      if(renderModel!=RenderModel.Opaque)return;
      program.set_f32m4("mvp", new Matrix4f(mvp));
      program.set_f32m4("model", new Matrix4f(model));
      program.set_f32m4("it_model", new Matrix4f(model).invert().transpose());
      program.set_f32v2("resolution", (float)width, (float)height);
      program.set_f32v3("color", material.albedo.get());
      program.set_f32v3("specular", material.specular.get());
      program.set_f32v3("emission", material.emission.get());
      program.set_f32("roughness", material.roughness.get());
      program.set_f32("metalness", material.metalness.get());
      material.albedo.getTexture().ifPresent(t->t.activate(GL4.GL_TEXTURE0));
      material.normal.getTexture().ifPresent(t->t.activate(GL4.GL_TEXTURE1));
      material.specular.getTexture().ifPresent(t->t.activate(GL4.GL_TEXTURE2));
      material.emission.getTexture().ifPresent(t->t.activate(GL4.GL_TEXTURE3));
      material.metalness.getTexture().ifPresent(t->t.activate(GL4.GL_TEXTURE4));
      program.set_i32("t_color",0);
      program.set_i32("t_normal",1);
      program.set_i32("t_specular",2);
      program.set_i32("t_emission",3);
      program.set_i32("t_MR",4);
      program.apply();
      vertex_array.bind();
      gl.glDrawArrays(GL4.GL_TRIANGLES, 0, vertex_count);
      //gl.glDrawElements(GL4.GL_TRIANGLES, index.length, GL4.GL_UNSIGNED_INT, 0);//Don't use now.(for high poly model?)(If I create original format,I'll use it.)
    }
    
    void transparent(Matrix4d mvp,Matrix4d model,Rasterizer r){
      if(renderModel==RenderModel.Opaque)return;
      transparent_program.set_f32m4("mvp", new Matrix4f(mvp));
      transparent_program.set_f32m4("ibl_mvp", new Matrix4f(new Matrix4d(r.player.camera.view).setTranslation(0,0,0).invert().mul(new Matrix4d(r.player.camera.proj).invert())));
      transparent_program.set_f32m4("model", new Matrix4f(model));
      transparent_program.set_f32m4("it_model", new Matrix4f(model).invert().transpose());
      transparent_program.set_f32v2("resolution", (float)width, (float)height);
      transparent_program.set_f32v3("color", material.albedo.get());
      transparent_program.set_f32v3("specular", material.specular.get());
      transparent_program.set_f32v3("emission", material.emission.get());
      transparent_program.set_f32("roughness", material.roughness.get());
      transparent_program.set_f32("metalness", material.metalness.get());
      transparent_program.set_f32("transmission", material.transmission.get());
      transparent_program.set_i32("sky", 6);
      transparent_program.set_f32("max_mip_level",r.hdri.mip_count);
      material.albedo.getTexture().ifPresent(t->t.activate(GL4.GL_TEXTURE0));
      material.normal.getTexture().ifPresent(t->t.activate(GL4.GL_TEXTURE1));
      material.specular.getTexture().ifPresent(t->t.activate(GL4.GL_TEXTURE2));
      r.shade_texture.activate(GL4.GL_TEXTURE3);
      material.metalness.getTexture().ifPresent(t->t.activate(GL4.GL_TEXTURE4));
      r.t_depth.activate(GL4.GL_TEXTURE5);
      r.hdri.activate(GL4.GL_TEXTURE6);
      transparent_program.set_i32("t_color",0);
      transparent_program.set_i32("t_normal",1);
      transparent_program.set_i32("t_specular",2);
      transparent_program.set_i32("t_albedo",3);
      transparent_program.set_i32("t_MR",4);
      transparent_program.set_i32("t_depth",5);
      transparent_program.apply();
      vertex_array.bind();
      gl.glDrawArrays(GL4.GL_TRIANGLES, 0, vertex_count);
    }
    
    void shadow(Matrix4d mvp){
      if(renderModel!=RenderModel.Opaque)return;
      shadow_program.set_f32m4("mvp",new Matrix4f(mvp));
      shadow_program.apply();
      s_vertex_array.bind();
      gl.glDrawArrays(GL4.GL_TRIANGLES, 0, vertex_count);
    }
    
    void prepass(Matrix4d mvp,Matrix4d model){
      prepass_program.set_f32m4("mvp", new Matrix4f(mvp));
      prepass_program.set_f32m4("p_mvp", new Matrix4f(p_mvp));
      prepass_program.set_f32m4("model", new Matrix4f(model));
      prepass_program.set_f32m4("it_model", new Matrix4f(model).invert().transpose());
      material.normal.getTexture().ifPresent(t->t.activate(GL4.GL_TEXTURE0));
      prepass_program.set_i32("t_normal",0);
      prepass_program.set_f32("ID",material_index);
      prepass_program.apply();
      vertex_array.bind();
      gl.glDrawArrays(GL4.GL_TRIANGLES, 0, vertex_count);
    }
    
    Vector3f calcNormal(Obj obj,int[] vi,int idx){
      Vector3f[] v=new Vector3f[3];
      idx=idx-(idx%3);
      for(int i=0;i<3;i++){
        v[i]=t2v(obj.getVertex(vi[idx+i]));
      }
      
      Vector3f delta_pos1=v[1].sub(v[0]);
      Vector3f delta_pos2=v[2].sub(v[0]);
      
      return delta_pos1.cross(delta_pos2);
    }
    
    Vector3f calcTangent(Obj obj,int[] vi,int[] ui,int idx){
      Vector3f[] v=new Vector3f[3];
      Vector3f[] uv=new Vector3f[3];
      for(int i=0;i<3;i++){
        v[i]=t2v(obj.getVertex(vi[idx+i]));
        uv[i]=Optional.ofNullable(obj.getTexCoord(ui[idx+i])).map(t->t2v(t)).orElse(new Vector3f(0,0,0));
      }
      
      Vector3f delta_pos1=v[1].sub(v[0]);
      Vector3f delta_pos2=v[2].sub(v[0]);
      
      Vector3f delta_uv1=uv[1].sub(uv[0]);
      Vector3f delta_uv2=uv[2].sub(uv[0]);
      
      float r=1.0/(delta_uv1.x*delta_uv2.y-delta_uv1.y*delta_uv2.x);
      if(((Float)r).isNaN()||((Float)r).isInfinite()){
        return delta_pos1.normalize();
      }
      return delta_pos1.mul(delta_uv2.y).sub(delta_pos2.mul(delta_uv1.y)).mul(r).normalize();
    }
    
    Vector3f t2v(FloatTuple t){
      return new Vector3f(t.getX(),t.getY(),t.getDimensions()==2?0:t.getZ());
    }
  }
}

class TextureCache{
  HashMap<String,Texture>cache=new HashMap<>();
  HashMap<StaticMesh,HashSet<String>>register=new HashMap<>();
  
  HashMap<String,HashSet<MaterialParam>>async_register=new HashMap<>();
  
  boolean has(String name){
    boolean[] r={false};
    cache.forEach((k,v)->{
      if(k.equals(name))r[0]=true;
    });
    return r[0];
  }
  
  Texture get(String name){
    if(has(name)){
      return getCache(name);
    }else{
      return put(name,new Texture().load(name));
    }
  }
  
  Texture get(ImageModel im){
    String name=im.getName();
    if(has(name)){
      return getCache(name);
    }else{
      try{
        ByteBuffer imageData=im.getImageData();
        byte[] data=new byte[imageData.remaining()];
        imageData.get(data);
        BufferedImage bi=ImageIO.read(new ByteArrayInputStream(data));
        int w=bi.getWidth();
        int h=bi.getHeight();
        return put(name,new BindlessTexture().load(w,h,getRGB(bi)));
      }catch(Exception e){
        return null;
      }
    }
  }
  
  void getAsync(ImageModel im,MaterialParam p){
    String name=im.getName();
    if(has(name)){
      p.setTexture(getCache(name));
    }else{
      if(!async_register.containsKey(name)){
        async_register.put(name,new HashSet<>());
        async_register.get(name).add(p);
        CompletableFuture.supplyAsync(()->{
          try{
            ByteBuffer imageData=im.getImageData();
            byte[] data=new byte[imageData.remaining()];
            imageData.get(data);
            BufferedImage bi=ImageIO.read(new ByteArrayInputStream(data));
            int w=bi.getWidth();
            int h=bi.getHeight();
            return Optional.ofNullable(new TexData(w,h,getRGB(bi)));
          }catch(Exception e){
            e.printStackTrace();
          }
          return Optional.ofNullable(null);
        }).thenAccept(t->{
          t.ifPresent(tx->{
            TexData tex_data=(TexData)tx;
            tasks.add(()->{
              Texture texture=new BindlessTexture().load(tex_data.w,tex_data.h,tex_data.b);
              put(name,texture);
              async_register.get(name).forEach(mp->{
                mp.setTexture(texture);
              });
            });
          });
        });
      }else{
        async_register.get(name).add(p);
      }
    }
  }
  
  Texture put(String name,Texture t){
    cache.put(name,t);
    return t;
  }
  
  Texture getCache(String name){
    return cache.get(name);
  }
  
  class TexData{
    int w;
    int h;
    ByteBuffer b;
    
    TexData(int w,int h,ByteBuffer b){
      this.w=w;
      this.h=h;
      this.b=b;
    }
  }
}

abstract class LightComponent extends Component{
  FrameBuffer fb;
  Texture depth;
  
  Vector3f light_color;
  float light_intensity;
  
  boolean cast_shadow=true;
  
  Matrix4d projection;
  Matrix4d view;
  
  Matrix4d view_projection;
  
  int x=4096;
  int y=4096;
  
  LightComponent(){
    super();
    light_color=new Vector3f(1.0,1.0,1.0);
    light_intensity=1.0;
  }
  
  LightComponent setColor(float r,float g,float b){
    light_color.set(r,g,b);
    return this;
  }
  
  LightComponent setIntensity(float i){
    light_intensity=i;
    return this;
  }
  
  LightComponent setShadowMapSize(int x,int y){
    this.x=x;
    this.y=y;
    initFrameBuffer();
    return this;
  }
  
  void initFrameBuffer(){
    fb=new FrameBuffer();
    fb.bind();
    
    depth=new Texture();
    depth.asDepth(x,y);
    depth.set_filtering(GL4.GL_LINEAR);
    depth.set_wrapping(GL4.GL_CLAMP_TO_EDGE);
    depth.depth_setting();
    fb.loadDepth(depth);
    gl.glDrawBuffer(GL4.GL_NONE);
    
    fb.unbind();
  }
  
  //abstract void display_shadow_depth(Buffer vertex_buffer,VertexArray vertex_array,Matrix4d model,int vertex_count);
}

class PointLight extends LightComponent{
  
  PointLight(){
    super();
  }
  
  void update(){}
  
  void rt_prepass(RayTracer r){}
  
  void prepass(Renderer r){}
  
  void display(){}
  
  //void display_shadow_depth(Buffer vertex_buffer,VertexArray vertex_array,Matrix4d model,int vertex_count){
  //  
  //}
}

class SpotLight extends LightComponent{
  
  SpotLight(Vector3d origin,Vector3d dir,float angle,boolean cast_shadow){
    super();
    transform.setTransform(origin);
    projection=new Matrix4d().perspective(radians(70), 16.0/9.0, 1, 100.0);
    Vector3d up=dir.x==0&&dir.z==0?new Vector3d(0,0,dir.y).normalize():new Vector3d(dir).cross(new Vector3d(-dir.z,-dir.y,0).normalize());
    view=new Matrix4d().identity().lookAt(origin,new Vector3d(origin).add(dir),up);
    view_projection=new Matrix4d(projection).mul(view);
    this.cast_shadow=cast_shadow;
    if(cast_shadow){
      initFrameBuffer();
    }
  }
  
  void update(){}
  
  void rt_prepass(RayTracer r){}
  
  void prepass(Renderer r){}
  
  void display(){}
  
  //void display_shadow_depth(Buffer vertex_buffer,VertexArray vertex_array,Matrix4d model,int vertex_count){
  //  
  //}
}

class DirectionalLight extends LightComponent{
  final int num_cascade=4;
  float[] cascade_split;
  Matrix4d[] cascade_proj=new Matrix4d[num_cascade];
  Matrix4d[] cascade_view=new Matrix4d[num_cascade];
  
  Vector4d[] vs;
  
  Vector3d dir;
  
  DirectionalLight(Vector3d origin,Vector3d dir,boolean cast_shadow){
    super();
    //projection=new Matrix4d().perspective(radians(70), 16.0/9.0, 1, 100.0);
    this.dir=dir;
    transform.setTransform(origin);
    projection=new Matrix4d().ortho(-50,50,-50,50,0,150);
    Vector3d up=getUp();
    view=new Matrix4d().identity().lookAt(origin,new Vector3d(origin).add(dir),up);
    view_projection=new Matrix4d(projection).mul(view);
    this.cast_shadow=cast_shadow;
    if(cast_shadow){
      initFrameBuffer();
    }
  }
  
  void initCascade(){
    cascade_split=new float[num_cascade];
    Camera c=renderer.player.camera;
    for(int i=0;i<num_cascade;i++){
      cascade_split[i]=c.near+(c.far-c.near)*pow((i+1)/num_cascade,2);
    }
    Vector3d up=getUp();
    Matrix4d l_mat=new Matrix4d().rotationTowards(new Vector3d(-dir.x,-dir.y,dir.z),up);
    Matrix4d mat=new Matrix4d(c.view).invert().mul(l_mat);
    for(int i=0;i<num_cascade;i++){
      //float n=i==0?c.near:cascade_split[i-1];
      //float f=cascade_split[i];
      float n=c.near;
      float f=c.far;
      Vector4d[] v=new Vector4d[8];
      float tan=tan(radians(c.fov)*0.5);
      float x1=n*tan;
      float x2=f*tan;
      float y1=x1/c.aspect;
      float y2=x2/c.aspect;
      v[0]=new Vector4d( x1, y1,n,1);
      v[1]=new Vector4d( x1,-y1,n,1);
      v[2]=new Vector4d(-x1, y1,n,1);
      v[3]=new Vector4d(-x1,-y1,n,1);
      v[4]=new Vector4d( x2, y2,f,1);
      v[5]=new Vector4d( x2,-y2,f,1);
      v[6]=new Vector4d(-x2, y2,f,1);
      v[7]=new Vector4d(-x2,-y2,f,1);
      for(int j=0;j<8;j++)v[j]=v[j].mul(mat);vs=v;
      cascade_proj[i]=new Matrix4d();
      cascade_view[i]=new Matrix4d();
      calcCascadeMat(v,cascade_proj[i],cascade_view[i]);
      cascade_view[i]=cascade_view[i].mul(new Matrix4d(l_mat));//println(cascade_view[i]);
    }
  }
  
  void calcCascadeMat(Vector4d[] v,Matrix4d proj,Matrix4d view){
    double minX = Double.POSITIVE_INFINITY;
    double maxX = Double.NEGATIVE_INFINITY;
    double minY = Double.POSITIVE_INFINITY;
    double maxY = Double.NEGATIVE_INFINITY;
    double minZ = Double.POSITIVE_INFINITY;
    double maxZ = Double.NEGATIVE_INFINITY;
    
    for(int i=0;i<8;i++){
      Vector4d p=v[i];
      if(p.x<minX)minX=p.x;
      if(p.x>maxX)maxX=p.x;
      if(p.y<minY)minY=p.y;
      if(p.y>maxY)maxY=p.y;
      if(p.z<minZ)minZ=p.z;
      if(p.z>maxZ)maxZ=p.z;
    }
    
    proj.set(new Matrix4d().identity().ortho(minX,maxX,minY,maxY,minZ,maxZ));
    Vector3d c=new Vector3d(minX,(minY+maxY)*0.5,(minZ+maxZ)*0.5);
    Vector3d up=getUp();
    view.set(new Matrix4d().identity().lookAt(c,new Vector3d(c).add(dir),up));
  }
  
  Vector3d getUp(){
    return dir.x==0&&dir.z==0?new Vector3d(0,0,dir.y).normalize():new Vector3d(dir).cross(new Vector3d(-dir.z,-dir.y,0).normalize());
  }
  
  void update(){
    initCascade();
    //view_projection=new Matrix4d(cascade_proj[0]).mul(cascade_view[0]);
  }
  
  void rt_prepass(RayTracer r){}
  
  void prepass(Renderer r){}
  
  void display(){}
  
  //void display_shadow_depth(Buffer vertex_buffer,VertexArray vertex_array,Matrix4d model,int vertex_count){
  //  vertex_buffer.bind();
  //  this.vertex_array.bind();
  //  this.vertex_array.set_attribute(program.get_attrib_location("position"), 3, 8*Float.BYTES, 0);
  //  Matrix4f mvp=new Matrix4f(view_projection).mul(new Matrix4f(model));
  //  program.set_f32m4("mvp",mvp);
  //  gl.glViewport(0,0,4096,4096);
  //  program.apply();
  //  this.vertex_array.bind();
  //  gl.glDrawArrays(GL4.GL_TRIANGLES, 0, vertex_count);
  //}
}

enum RenderModel{
  Opaque,
  Masked,
  Transparent;
}
