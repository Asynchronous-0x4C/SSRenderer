ArrayList<Float>ssbo_vertices=new ArrayList<>();
ArrayList<Float>ssbo_materials=new ArrayList<>();
ArrayList<Long>ssbo_textures=new ArrayList<>();

HashMap<String,Material>material_set=new HashMap<>();
ArrayList<Material>materials=new ArrayList<>();

ArrayList<BindlessTexture>textures=new ArrayList<>();

class RayTracer extends Renderer{
  FrameBuffer prev_pass;
  FloatTexture prev_depth;
  FloatTexture prev_normal;
  
  FrameBuffer prepass;
  Texture depth;
  FloatTexture ID;
  FloatTexture normal;
  FloatTexture motion;
  
  FrameBuffer main_pass;
  FloatTexture main_texture;
  
  FilterProgram prev;
  
  FilterProgram raytrace;
  FloatTexture hdri;
  FloatTexture albedo;
  Buffer tris;
  Buffer mats;
  Buffer bvh;
  Buffer rnd;
  Buffer tx;
  
  FrameBuffer accum;
  FilterProgram accumulate;
  FloatTexture before;
  FloatTexture after;
  FloatTexture moment;
  
  FrameBuffer SVGF_filter;
  FilterProgram SVGF;
  FloatTexture out_color;
  
  FilterProgram disp;
  
  Matrix4d mvp;
  Matrix4d p_mvp;
  
  int num_iterations=1;
  boolean move=true;
  
  void initFrameBuffer(){
    prev_pass=new FrameBuffer();
    prev_pass.bind();
    
    prev_depth=new FloatTexture();
    prev_depth.load();
    
    prev_normal=new FloatTexture();
    prev_normal.load();
    
    before=new FloatTexture();
    before.load();
    before.set_filtering(GL4.GL_LINEAR);
    
    prev_pass.load(prev_depth,prev_normal);
    prev_pass.unbind();
    
    prepass=new FrameBuffer();
    prepass.bind();
    
    depth=new Texture();
    depth.asDepth();
    prepass.loadDepth(depth);
    
    ID=new FloatTexture();
    ID.load();
    
    normal=new FloatTexture();
    normal.load();
    
    motion=new FloatTexture();
    motion.load();
    
    prepass.load(ID,normal,motion);
    prepass.unbind();
    
    main_pass=new FrameBuffer();
    main_pass.bind();
    
    main_texture=new FloatTexture();
    main_texture.load();
    
    albedo=new FloatTexture();
    albedo.load();
    
    main_pass.load(main_texture,albedo);
    main_pass.unbind();
    
    hdri=new FloatTexture();
    hdri.load(sketchPath()+"/data/bg/8k/8k_2.hdr");
    
    accum=new FrameBuffer();
    accum.bind();
    
    after=new FloatTexture();
    after.load();
    
    moment=new FloatTexture();
    moment.load();
    
    out_color=new FloatTexture();
    out_color.load();
    
    accum.load(after,moment,out_color);
    accum.unbind();
    
    SVGF_filter=new FrameBuffer();
    SVGF_filter.bind();
    
    SVGF_filter.load(before,out_color);
    SVGF_filter.unbind();
    
    tris=new Buffer(GL4.GL_SHADER_STORAGE_BUFFER);
    mats=new Buffer(GL4.GL_SHADER_STORAGE_BUFFER);
    bvh=new Buffer(GL4.GL_SHADER_STORAGE_BUFFER);
    rnd=new Buffer(GL4.GL_SHADER_STORAGE_BUFFER);
    tx=new Buffer(GL4.GL_SHADER_STORAGE_BUFFER);
    int[] r=new int[width*height];
    for(int i=0;i<r.length;i++){
      r[i]=round(random(-Integer.MIN_VALUE,Integer.MAX_VALUE));
    }
    rnd.set_data(IntBuffer.wrap(r),GL4.GL_STATIC_DRAW);
  }
  
  void initProgram(){
    prev=new FilterProgram("./data/PrevPass.fs","./data/FilterVert.vs");
    
    raytrace=new FilterProgram("./data/PathTracing.fs","./data/PathTracingVert.vs");
    
    accumulate=new FilterProgram("./data/Accum.fs","./data/FilterVert.vs");
    
    SVGF=new FilterProgram("./data/SVGF.fs","./data/FilterVert.vs");
    
    disp=new FilterProgram("./data/Display.fs","./data/FilterVert.vs");
  }
  
  void reloadVertices(){
    ssbo_vertices.clear();
    level.putSSBOData();
    float[] v=new float[ssbo_vertices.size()];
    for(int i=0;i<v.length;i++){
      v[i]=ssbo_vertices.get(i);
    }
    tris.set_data(FloatBuffer.wrap(v),GL4.GL_DYNAMIC_DRAW);
    float[] ssbo_bvh=constructBVH(v);
    bvh.set_data(FloatBuffer.wrap(ssbo_bvh),GL4.GL_DYNAMIC_DRAW);
    println("vertices are loaded.");
  }
  
  void reloadMaterials(){
    ssbo_materials.clear();
    ssbo_textures.clear();
    for(int i=0,n=materials.size();i<n;++i){
      Material m=materials.get(i);
      ssbo_materials.add(m.albedo.get().x);
      ssbo_materials.add(m.albedo.get().y);
      ssbo_materials.add(m.albedo.get().z);
      ssbo_materials.add(i*5.0);
      ssbo_materials.add(m.specular.get().x);
      ssbo_materials.add(m.specular.get().y);
      ssbo_materials.add(m.specular.get().z);
      ssbo_materials.add(i*5.0+1);
      ssbo_materials.add(m.emission.get().x);
      ssbo_materials.add(m.emission.get().y);
      ssbo_materials.add(m.emission.get().z);
      ssbo_materials.add(i*5.0+2);
      ssbo_materials.add(m.metalness.get());
      ssbo_materials.add(m.roughness.get());
      ssbo_materials.add(m.transmission.get());
      ssbo_materials.add(i*5.0+3);
      ssbo_materials.add(m.IOR.get());
      ssbo_materials.add(i*5.0+4);
      ssbo_materials.add(m.anisotropy_s.get());
      ssbo_materials.add(m.anisotropy_r.get());
      ssbo_textures.add(((BindlessTexture)m.albedo.texture).handle);
      ssbo_textures.add(((BindlessTexture)m.roughness.texture).handle);
      ssbo_textures.add(((BindlessTexture)m.emission.texture).handle);
      ssbo_textures.add(((BindlessTexture)m.metalness.texture).handle);
      ssbo_textures.add(((BindlessTexture)m.normal.texture).handle);
      ((BindlessTexture)m.albedo.texture).makeResident();
      ((BindlessTexture)m.roughness.texture).makeResident();
      ((BindlessTexture)m.emission.texture).makeResident();
      ((BindlessTexture)m.metalness.texture).makeResident();
      ((BindlessTexture)m.normal.texture).makeResident();
    }
    float[] d=new float[ssbo_materials.size()];
    for(int i=0;i<d.length;++i){
      d[i]=ssbo_materials.get(i);
    }
    mats.set_data(FloatBuffer.wrap(d),GL4.GL_DYNAMIC_DRAW);
    long[] _d=new long[ssbo_textures.size()];
    for(int i=0;i<_d.length;++i){
      _d[i]=ssbo_textures.get(i);
    }
    tx.set_data(LongBuffer.wrap(_d),GL4.GL_DYNAMIC_DRAW);
  }
  
  void display(){
    blendMode(REPLACE);
    prepass();
    main_pass();
    if(main_input.getKeyBoard().getBindedInput("Change_Move")){
      move=!move;
      num_iterations=1;
    }
    if(!mvp.equals(p_mvp,1e-5)){
      num_iterations=1;
    }else{
      num_iterations++;
    }
    accum_pass();
    disp();
    p_mvp=new Matrix4d(mvp);
    blendMode(BLEND);
  }
  
  void prepass(){
    prev_pass.bind();
    gl.glViewport(0,0,width,height);
    gl.glClear(GL4.GL_COLOR_BUFFER_BIT|GL4.GL_DEPTH_BUFFER_BIT);
    gl.glClearColor(0,0,0,1);
    gl.glDisable(GL4.GL_DEPTH_TEST);
    background(0);
    prev.program.set_i32("depth",0);
    prev.program.set_i32("normal",1);
    prev.program.set_i32("moment",2);
    depth.activate(GL4.GL_TEXTURE0);
    normal.activate(GL4.GL_TEXTURE1);
    moment.activate(GL4.GL_TEXTURE2);
    prev.program.apply();
    prev.vertex_array.bind();
    gl.glDrawElements(GL4.GL_TRIANGLES, prev.indices.length, GL4.GL_UNSIGNED_INT, 0);
    prev_pass.unbind();
    
    prepass.bind();
    gl.glViewport(0,0,width,height);
    gl.glClear(GL4.GL_COLOR_BUFFER_BIT|GL4.GL_DEPTH_BUFFER_BIT);
    gl.glClearColor(0,0,0,1);
    gl.glEnable(GL4.GL_DEPTH_TEST);
    background(0);
    level.rt_prepass(this);
    prepass.unbind();
  }
  
  void main_pass(){
    main_pass.bind();
    gl.glViewport(0,0,width,height);
    mvp=new Matrix4d().set(player.camera.proj).mul(player.camera.view).invert();
    raytrace.program.set_f32m4("mvp",new Matrix4f(mvp));
    raytrace.program.set_f32v3("origin",player.camera.origin);
    raytrace.program.set_f32v2("resolution",width,height);
    hdri.activate(GL4.GL_TEXTURE0);
    raytrace.program.set_i32("hdri",0);
    depth.activate(GL4.GL_TEXTURE1);
    raytrace.program.set_i32("depth",1);
    normal.activate(GL4.GL_TEXTURE2);
    raytrace.program.set_i32("normal",2);
    ID.activate(GL4.GL_TEXTURE3);
    raytrace.program.set_i32("ID",3);
    raytrace.program.apply();
    raytrace.vertex_array.bind();
    tris.bindBase(0);
    mats.bindBase(1);
    bvh.bindBase(2);
    rnd.bindBase(3);
    tx.bindBase(4);
    gl.glDrawElements(GL4.GL_TRIANGLES, raytrace.indices.length, GL4.GL_UNSIGNED_INT, 0);
    raytrace.vertex_array.unbind();
    main_pass.unbind();
  }
  
  void accum_pass(){
    accum.bind();
    gl.glViewport(0,0,width,height);
    gl.glClear(GL4.GL_COLOR_BUFFER_BIT|GL4.GL_DEPTH_BUFFER_BIT);
    gl.glClearColor(0,0,0,1);
    gl.glDisable(GL4.GL_DEPTH_TEST);
    accumulate.program.set_f32v2("resolution",width,height);
    accumulate.program.set_i32("num_iterations",num_iterations);
    accumulate.program.set_i32("current",0);
    accumulate.program.set_i32("motion",1);
    accumulate.program.set_i32("prev_normal",2);
    accumulate.program.set_i32("normal",3);
    accumulate.program.set_i32("prev_depth",4);
    accumulate.program.set_i32("depth",5);
    accumulate.program.set_i32("before",6);
    accumulate.program.set_b("move",move);
    main_texture.activate(GL4.GL_TEXTURE0);
    motion.activate(GL4.GL_TEXTURE1);
    prev_normal.activate(GL4.GL_TEXTURE2);
    normal.activate(GL4.GL_TEXTURE3);
    prev_depth.activate(GL4.GL_TEXTURE4);
    depth.activate(GL4.GL_TEXTURE5);
    before.activate(GL4.GL_TEXTURE6);
    accumulate.program.apply();
    accumulate.vertex_array.bind();
    gl.glDrawElements(GL4.GL_TRIANGLES, accumulate.indices.length, GL4.GL_UNSIGNED_INT, 0);
    accumulate.vertex_array.unbind();
    accum.unbind();
    
    SVGF_filter.bind();
    gl.glViewport(0,0,width,height);
    gl.glClear(GL4.GL_COLOR_BUFFER_BIT|GL4.GL_DEPTH_BUFFER_BIT);
    gl.glClearColor(0,0,0,1);
    gl.glDisable(GL4.GL_DEPTH_TEST);
    SVGF.program.set_f32v2("resolution",width,height);
    SVGF.program.set_i32("normal",0);
    SVGF.program.set_i32("depth",1);
    SVGF.program.set_i32("after",2);
    SVGF.program.set_i32("moment",3);
    SVGF.program.set_i32("albedo",4);
    normal.activate(GL4.GL_TEXTURE0);
    depth.activate(GL4.GL_TEXTURE1);
    after.activate(GL4.GL_TEXTURE2);
    moment.activate(GL4.GL_TEXTURE3);
    albedo.activate(GL4.GL_TEXTURE4);
    SVGF.program.apply();
    SVGF.vertex_array.bind();
    gl.glDrawElements(GL4.GL_TRIANGLES, SVGF.indices.length, GL4.GL_UNSIGNED_INT, 0);
    SVGF.vertex_array.unbind();
    SVGF_filter.unbind();
  }
  
  void disp(){
    gl.glViewport(0,0,width,height);
    gl.glClear(GL4.GL_COLOR_BUFFER_BIT|GL4.GL_DEPTH_BUFFER_BIT);
    gl.glClearColor(0,0,0,1);
    gl.glDisable(GL4.GL_DEPTH_TEST);
    disp.program.set_i32("texture",0);
    out_color.activate(GL4.GL_TEXTURE0);
    disp.program.apply();
    disp.vertex_array.bind();
    gl.glDrawElements(GL4.GL_TRIANGLES, disp.indices.length, GL4.GL_UNSIGNED_INT, 0);
    disp.vertex_array.unbind();
  }
}

int bvh_index=0;

float[] constructBVH(float[] vertices){
  bvh_index=0;
  AABB[] init=new AABB[vertices.length/16];
  for(int i=0;i<init.length;i++){
    init[i]=new AABB(Arrays.copyOfRange(vertices,i*16,i*16+12),i);
  }
  AABB root=new AABB(init);
  AABB[] result=splitBVH(root,init);
  float[] ret=new float[result.length*8];
  for(int i=0;i<result.length;i++){
    ret[i*8  ]=result[i].min[0];
    ret[i*8+1]=result[i].min[1];
    ret[i*8+2]=result[i].min[2];
    ret[i*8+3]=result[i].r;
    ret[i*8+4]=result[i].max[0];
    ret[i*8+5]=result[i].max[1];
    ret[i*8+6]=result[i].max[2];
    ret[i*8+7]=result[i].l;
  }int idx=0;while(result[idx].l!=-1){idx=result[idx].r;}
  return ret;
}

AABB[] splitBVH(AABB root,AABB[] child){//println(child.length,bvh_index);//if(child.length==1)println(d,child[0].l);
  if(child.length<=1){
    return new AABB[]{child[0]};
  }
  ArrayList<AABB>nodes=new ArrayList<>();
  nodes.add(root);
  
  int idx=0;
  float best_cost=Float.MAX_VALUE;
  int a=root.getLargest();
  switch(a){
    case 0:Arrays.sort(child,new Comparator<AABB>(){int compare(AABB x,AABB y){return sign((x.max[0]+x.min[0])*0.5-(y.max[0]+y.min[0])*0.5);}});break;
    case 1:Arrays.sort(child,new Comparator<AABB>(){int compare(AABB x,AABB y){return sign((x.max[1]+x.min[1])*0.5-(y.max[1]+y.min[1])*0.5);}});break;
    case 2:Arrays.sort(child,new Comparator<AABB>(){int compare(AABB x,AABB y){return sign((x.max[2]+x.min[2])*0.5-(y.max[2]+y.min[2])*0.5);}});break;
  }
  for(int i=0,n=child.length-1;i<n;i++){
    float cost=new AABB(Arrays.copyOfRange(child,0,i+1)).getSAH(i+1)+new AABB(Arrays.copyOfRange(child,i+1,child.length)).getSAH(child.length-i-1);
    if(cost<best_cost){
      best_cost=cost;
      idx=i;
    }
  }
  
  bvh_index++;
  root.r=bvh_index;
  AABB[] r_a=Arrays.copyOfRange(child,0,idx+1);
  nodes.addAll(Arrays.asList(splitBVH(new AABB(r_a),r_a)));
  
  bvh_index++;
  root.l=bvh_index;
  AABB[] l_a=Arrays.copyOfRange(child,idx+1,child.length);
  nodes.addAll(Arrays.asList(splitBVH(new AABB(l_a),l_a)));
  
  return nodes.toArray(new AABB[0]);
}

class AABB{
  float[] min;
  float[] max;
  int r;
  int l;
  
  AABB(float[] v,int idx){
    min=new float[]{Float.MAX_VALUE,Float.MAX_VALUE,Float.MAX_VALUE};
    max=new float[]{-Float.MAX_VALUE,-Float.MAX_VALUE,-Float.MAX_VALUE};
    for(int i=0;i<3;i++){
      for(int j=0;j<3;j++){
        min[j]=min(min[j],v[i*4+j]);
        max[j]=max(max[j],v[i*4+j]);
      }
    }
    r=idx;
    l=-1;
  }
  
  AABB(AABB... b){
    min=new float[]{Float.MAX_VALUE,Float.MAX_VALUE,Float.MAX_VALUE};
    max=new float[]{-Float.MAX_VALUE,-Float.MAX_VALUE,-Float.MAX_VALUE};
    for(AABB a:b){
      for(int i=0;i<3;i++){
        min[i]=min(min[i],a.min[i]);
        max[i]=max(max[i],a.max[i]);
      }
    }
  }
  
  float getSAH(float n){
    float x=max[0]-min[0];
    float y=max[1]-min[1];
    float z=max[2]-max[2];
    return 2*(x*y+x*z+y*z)*n;
  }
  
  int getLargest(){
    float dx=max[0]-min[0];
    float dy=max[1]-min[1];
    float dz=max[2]-min[2];
    float mx=max(dx,dy,dz);
    return dx==mx?0:dy==mx?1:2;
  }
  
  String toString(){
    return "("+min[0]+","+min[1]+","+min[2]+") : ("+max[0]+","+max[1]+","+max[2]+") : "+r+","+l;
  }
}

int sign(float x){
  return x<-1e-5?-1:x>1e-5?1:0;
}
