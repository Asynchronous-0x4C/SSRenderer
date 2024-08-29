class Rasterizer extends Renderer{
  
  FilterProgram sky;
  FilterProgram display;
  FilterProgram shadow_dir;
  FilterProgram transparent;
  FilterProgram IBL;
  FilterProgram toneMapper;
  FilterProgram FXAA;
  
  FrameBuffer geometry_buffer;
  Texture t_depth;
  Texture t_position;
  Texture t_normal;
  Texture t_color;
  Texture t_specular;
  Texture t_emission;
  
  FrameBuffer float_color_buffer;
  FloatTexture scene_texture;
  FrameBuffer shade_buffer;
  FloatTexture shade_texture;
  FrameBuffer tone_map_buffer;
  Texture tone_mapped_texture;
  
  void initFrameBuffer(){
    hdri=new CubemapTexture();
    hdri.load(sketchPath()+"/data/bg/2k/");
    
    geometry_buffer=new FrameBuffer();
    geometry_buffer.bind();
    
    t_depth=new Texture();
    t_depth.asDepth();
    t_depth.set_filtering(GL4.GL_NEAREST);
    t_depth.set_wrapping(GL4.GL_CLAMP_TO_EDGE);
    geometry_buffer.loadDepth(t_depth);
    
    t_position=new FloatTexture();
    t_position.load();
    t_position.set_filtering(GL4.GL_NEAREST);
    t_position.set_wrapping(GL4.GL_CLAMP_TO_EDGE);
    
    t_normal=new FloatTexture();
    t_normal.load();
    t_normal.set_filtering(GL4.GL_NEAREST);
    t_normal.set_wrapping(GL4.GL_CLAMP_TO_EDGE);
    
    t_color=new Texture();
    t_color.load();
    t_color.set_filtering(GL4.GL_NEAREST);
    t_color.set_wrapping(GL4.GL_CLAMP_TO_EDGE);
    
    t_specular=new Texture();
    t_specular.load();
    t_specular.set_filtering(GL4.GL_NEAREST);
    t_specular.set_wrapping(GL4.GL_CLAMP_TO_EDGE);
    
    t_emission=new FloatTexture();
    t_emission.load();
    t_emission.set_filtering(GL4.GL_NEAREST);
    t_emission.set_wrapping(GL4.GL_CLAMP_TO_EDGE);
    
    geometry_buffer.load(t_position, t_normal, t_color, t_specular, t_emission);
    
    int status = gl.glCheckFramebufferStatus(GL4.GL_FRAMEBUFFER);
    if (status != GL4.GL_FRAMEBUFFER_COMPLETE) {
      System.err.println("Framebuffer not complete: " + status);
    }
    gl.glEnable(GL4.GL_BLEND);
    gl.glBlendFunc(GL4.GL_ONE,GL4.GL_ZERO);
    gl.glEnable(GL4.GL_CULL_FACE);
    
    geometry_buffer.unbind();
    
    float_color_buffer=new FrameBuffer();
    float_color_buffer.bind();
    
    scene_texture=new FloatTexture();
    scene_texture.load();
    scene_texture.set_filtering(GL4.GL_NEAREST);
    scene_texture.set_wrapping(GL4.GL_CLAMP_TO_EDGE);
    
    float_color_buffer.load(scene_texture);
    
    float_color_buffer.unbind();
    
    shade_buffer=new FrameBuffer();
    shade_buffer.bind();
    
    shade_texture=new FloatTexture();
    shade_texture.load();
    shade_texture.set_filtering(GL4.GL_NEAREST);
    shade_texture.set_wrapping(GL4.GL_CLAMP_TO_EDGE);
    
    shade_buffer.load(shade_texture,scene_texture);
    
    shade_buffer.unbind();
    
    tone_map_buffer=new FrameBuffer();
    tone_map_buffer.bind();
    
    tone_mapped_texture=new Texture();
    tone_mapped_texture.load();
    tone_mapped_texture.set_filtering(GL4.GL_NEAREST);
    tone_mapped_texture.set_wrapping(GL4.GL_CLAMP_TO_EDGE);
    
    tone_map_buffer.load(tone_mapped_texture);
    
    tone_map_buffer.unbind();
  }
  
  void initProgram(){
    display=new FilterProgram("Dispfrag.fs","FilterVert.vs");
    sky=new FilterProgram("SkyFrag.fs","FilterVert.vs");
    toneMapper=new FilterProgram("AgX.fs","FilterVert.vs");
    IBL=new FilterProgram("IBLFrag.fs","FilterVert.vs");
    shadow_dir=new FilterProgram("DirectionalLightFrag.fs","FilterVert.vs");
    FXAA=new FilterProgram("FXAAFrag.fs","FilterVert.vs");
    transparent=new FilterProgram("Transparent.fs","TransparentVert.vs");
  }
  
  void update(){
    level.update();
  }
  
  void display(){
    blendMode(REPLACE);profiler.start("geometry");
    sky_pass();
    geometry_pass();
    shadow_map_pass();profiler.end("geometry");
    blendMode(ADD);profiler.start("shade");
    directional_light_pass();
    shade();
    IBL_pass();profiler.end("shade");
    blendMode(BLEND);profiler.start("post");
    transparent_pass();
    postProcess();
    toneMap();
    anti_Aliasing();profiler.end("post");
  }
  
  void sky_pass(){
    geometry_buffer.bind();
    gl.glViewport(0, 0, width, height);
    gl.glClear(GL4.GL_COLOR_BUFFER_BIT | GL4.GL_DEPTH_BUFFER_BIT);
    gl.glClearColor(0, 0, 0, 1);
    gl.glDisable(GL4.GL_DEPTH_TEST);
    Matrix4d mvp=new Matrix4d(player.camera.view).setTranslation(0,0,0).invert().mul(new Matrix4d(player.camera.proj).invert());
    sky.program.set_f32m4("mvp", new Matrix4f(mvp));
    sky.program.set_f32v2("resolution",width,height);
    hdri.activate(GL4.GL_TEXTURE0);
    sky.program.set_i32("hdri", 0);
    sky.program.apply();
    sky.vertex_array.bind();
    gl.glDrawElements(GL4.GL_TRIANGLES, sky.indices.length, GL4.GL_UNSIGNED_INT, 0);
    gl.glEnable(GL4.GL_DEPTH_TEST);
    geometry_buffer.unbind();
  }
  
  void geometry_pass(){
    geometry_buffer.bind();
    level.prepass(this);
    geometry_buffer.unbind();
  }
  
  void shadow_map_pass(){
    level.shadow_map(lights);
    //lights.forEach((k,v)->{
    //  level.components.forEach((k2,v2)->{
    //    if(v2 instanceof StaticMesh){
    //      StaticMesh sm=(StaticMesh)v2;
    //      sm.segments.forEach(s->{
    //        v.display_shadow_depth(s.vertex_buffer,s.vertex_array,sm.model,s.vertex_count);
    //      });
    //    }
    //  });
    //});
  }
  
  void directional_light_pass(){
    shade_buffer.bind();
    gl.glViewport(0, 0, width, height);
    gl.glClear(GL4.GL_COLOR_BUFFER_BIT | GL4.GL_DEPTH_BUFFER_BIT);
    gl.glClearColor(0, 0, 0, 1);
    Matrix4d mvp=new Matrix4d().set(player.camera.proj).mul(player.camera.view);
    shadow_dir.program.set_f32m4("mvp", new Matrix4f(mvp));
    t_position.activate(GL4.GL_TEXTURE0);
    shadow_dir.program.set_i32("position", 0);
    t_normal.activate(GL4.GL_TEXTURE1);
    shadow_dir.program.set_i32("normal", 1);
    t_color.activate(GL4.GL_TEXTURE2);
    shadow_dir.program.set_i32("color", 2);
    t_specular.activate(GL4.GL_TEXTURE3);
    shadow_dir.program.set_i32("specular", 3);
    t_emission.activate(GL4.GL_TEXTURE4);
    shadow_dir.program.set_i32("emission", 4);
    shadow_dir.program.set_f32v2("resolution", (float)width, (float)height);
    lights.forEach((k,v)->{
      shadow_dir.program.set_b("use_shadow",v.cast_shadow);
      shadow_dir.program.set_f32v3("light.color",new Vector3f(v.light_color).mul(v.light_intensity));
      shadow_dir.program.set_f32v3("light.position",v.transform.transform);
      if(v.cast_shadow){
        Matrix4d shadow_mvp=new Matrix4d();
        shadow_mvp.set(v.view_projection);
        shadow_dir.program.set_f32m4("shadow_mvp", new Matrix4f(shadow_mvp));
        v.depth.activate(GL4.GL_TEXTURE5);
        shadow_dir.program.set_i32("shadow", 5);
      }
      shadow_dir.program.apply();
      shadow_dir.vertex_array.bind();
      gl.glDrawElements(GL4.GL_TRIANGLES, shadow_dir.indices.length, GL4.GL_UNSIGNED_INT, 0);
    });
    shade_buffer.unbind();
  }
  
  void shade(){
    shade_buffer.bind();
    gl.glViewport(0, 0, width, height);
    t_emission.activate(GL4.GL_TEXTURE0);
    display.program.set_i32("emission", 0);
    //t_normal.activate(GL4.GL_TEXTURE1);
    //display.program.set_i32("normal", 1);
    display.program.apply();
    display.vertex_array.bind();
    gl.glDrawElements(GL4.GL_TRIANGLES, display.indices.length, GL4.GL_UNSIGNED_INT, 0);
    shade_buffer.unbind();
  }
  
  void IBL_pass(){
    shade_buffer.bind();
    gl.glViewport(0, 0, width, height);
    Matrix4d mvp=new Matrix4d(player.camera.view).setTranslation(0,0,0).invert().mul(new Matrix4d(player.camera.proj).invert());
    IBL.program.set_f32m4("mvp", new Matrix4f(mvp));
    t_position.activate(GL4.GL_TEXTURE0);
    IBL.program.set_i32("position", 0);
    t_normal.activate(GL4.GL_TEXTURE1);
    IBL.program.set_i32("normal", 1);
    t_color.activate(GL4.GL_TEXTURE2);
    IBL.program.set_i32("color", 2);
    t_depth.activate(GL4.GL_TEXTURE3);
    IBL.program.set_i32("depth", 3);
    t_specular.activate(GL4.GL_TEXTURE4);
    IBL.program.set_i32("specular", 4);
    hdri.activate(GL4.GL_TEXTURE5);
    IBL.program.set_i32("sky", 5);
    IBL.program.set_f32("intensity",1);
    IBL.program.set_f32("max_mip_level",hdri.mip_count);
    IBL.program.set_f32v2("resolution", (float)width, (float)height);
    IBL.program.apply();
    IBL.vertex_array.bind();
    gl.glDrawElements(GL4.GL_TRIANGLES, IBL.indices.length, GL4.GL_UNSIGNED_INT, 0);
    shade_buffer.unbind();
  }
  
  void transparent_pass(){
    float_color_buffer.bind();
    gl.glViewport(0, 0, width, height);
    gl.glDisable(GL4.GL_DEPTH_TEST);
    //gl.glDepthMask(false);
    level.transparent(this);
    //gl.glDepthMask(true);
    //gl.glDisable(GL4.GL_DEPTH_TEST);
    float_color_buffer.unbind();
  }
  
  void postProcess(){
    
  }
  
  void toneMap(){
    tone_map_buffer.bind();
    gl.glViewport(0, 0, width, height);
    gl.glClear(GL4.GL_COLOR_BUFFER_BIT | GL4.GL_DEPTH_BUFFER_BIT);
    gl.glClearColor(0, 0, 0, 1);
    scene_texture.activate(GL4.GL_TEXTURE1);
    toneMapper.program.set_i32("source", 1);
    toneMapper.program.apply();
    toneMapper.vertex_array.bind();
    gl.glDrawElements(GL4.GL_TRIANGLES, toneMapper.indices.length, GL4.GL_UNSIGNED_INT, 0);
    tone_map_buffer.unbind();
  }
  
  void anti_Aliasing(){
    gl.glViewport(0, 0, width, height);
    gl.glClear(GL4.GL_COLOR_BUFFER_BIT | GL4.GL_DEPTH_BUFFER_BIT);
    gl.glClearColor(0, 0, 0, 1);
    tone_mapped_texture.activate(GL4.GL_TEXTURE0);
    FXAA.program.set_i32("textureUnit",0);
    FXAA.program.set_f32v2("invResolution",1.0/width,1.0/height);
    FXAA.program.apply();
    FXAA.vertex_array.bind();
    gl.glDrawElements(GL4.GL_TRIANGLES, FXAA.indices.length, GL4.GL_UNSIGNED_INT, 0);
    FXAA.vertex_array.unbind();
  }
}
