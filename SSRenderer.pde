import com.jogamp.opengl.GL4;
import com.jogamp.opengl.util.GLBuffers;
import com.jogamp.opengl.*;
import org.joml.*;

import static com.jogamp.newt.event.KeyEvent.*;

import javax.imageio.*;
import javax.imageio.stream.*;

import com.twelvemonkeys.imageio.plugins.hdr.HDRImageReadParam;
import com.twelvemonkeys.imageio.plugins.hdr.tonemap.*;

import org.ode4j.ode.*;
import org.ode4j.math.*;
import org.ode4j.ode.internal.joints.*;

//import com.github.ivelate.JavaHDR.*;

import java.awt.*;
import java.awt.image.*;

import java.nio.*;
import java.io.*;

import java.util.*;
import java.util.stream.*;
import java.util.concurrent.*;

import SSGUI.input.*;

GL4 gl;

Obj object;
Profiler profiler;

Renderer renderer;

Input main_input;

TextureCache main_cache;

java.util.List<Runnable>tasks;

DWorld world;
DSpace space;
DJointGroup contactGroup;

CompletableFuture future;

static {
  PJOGL.profile=4;
}

void setup() {
  size(1280, 720, P2D);
  //fullScreen(P2D);
  System.loadLibrary("renderdoc");
  frameRate(75);
  windowTitle("Signal");
  gl = (GL4)((PJOGL)((PGraphicsOpenGL)g).pgl).gl;
  ((PJOGL)((PGraphicsOpenGL)g).pgl).gl.glEnable(GL4.GL_TEXTURE_CUBE_MAP_SEAMLESS);
  main_input=new Input(this,(PSurfaceJOGL)surface);
  main_input.getKeyBoard().addKeyBind("Jump",(int)VK_SPACE);
  main_input.getKeyBoard().addKeyBind("Change_Move",(int)VK_M);
  main_input.getKeyBoard().addKeyBind("Sub_Reflection",(int)VK_Q);
  main_input.getKeyBoard().addKeyBind("Add_Reflection",(int)VK_E);
  main_input.getKeyBoard().addKeyBind("Screenshot",(int)VK_P);
  main_input.getKeyBoard().addKeyBind("Matrix",(int)VK_Z);
  main_cache=new TextureCache();
  profiler=new Profiler();
  tasks=Collections.synchronizedList(new ArrayList<>());
  println(GLProfile.getDefault());
  //renderer=new Renderer();
  //loadObj();
}

void draw() {
  background(30);
  if(frameCount==1){
    initPhysics();
    renderer=new RayTracer();
    //renderer=new Rasterizer();
    //loadObj("/data/models/mats/","mats.obj");
    //loadGLTF("/data/models/Exit8/","Exit8.glb");
    //loadGLTF("/data/models/suiban/","suiban.glb");
    //loadGLTF("/data/models/demo/","demo.glb");
    //loadGLTF("/data/models/demo2/","demo2_simple.glb");
    //loadGLTF("/data/models/demo2/","demo2.glb");
    //loadGLTF("/data/models/sibenik/","sibenik.glb");
    //loadGLTF("/data/models/sponza-gltf-pbr/","sponza.glb");
    //loadGLTF("/data/models/glass/","glass.glb");
    loadPreset("./data/presets/glass.json");
    return;
  }
  synchronized(tasks){
    for(int i=0;i<3;i++){
      if(!tasks.isEmpty()){
        tasks.get(0).run();
        tasks.remove(0);
      }
    }
  }
  if(future!=null){
    try{
      future.get();
    }catch(Exception e){
      e.printStackTrace();
    }
  }
  profiler.start("update");
  renderer.update();
  profiler.end("update");
  //need to optimize physics
  //future=CompletableFuture.runAsync(()->stepPhysics());
  profiler.start("draw");
  renderer.display();
  profiler.end("draw");
  //noFill();
  //stroke(0,255,0);
  //rectMode(CENTER);
  //rect(width*0.5,height*0.5,50,50);
  //line(width*0.5,height*0.5-10,width*0.5,height*0.5+10);
  //line(width*0.5+10,height*0.5,width*0.5-10,height*0.5);
  //profiler.display();
  if(sample_sequence.size()==0){
    fill(255,0,255);
    text("frameRate: "+nf(frameRate,0,1),105,15);
    if(renderer instanceof RayTracer){
      text("reflection: "+((RayTracer)renderer).num_reflect,105,25);
      text("mrays: "+(frameRate*width*height*((RayTracer)renderer).num_reflect/1_000_000.0),105,35);
    }
  }
  if(main_input.getKeyBoard().getBindedInput("Screenshot")){
    save(year()+""+month()+""+day()+"-"+hour()+"-"+minute()+"-"+second()+"-"+millis()+".png");
  }
  if(main_input.getKeyBoard().getBindedInput("Matrix")){
    println(renderer.player.camera.origin);
    println(renderer.player.camera.rot.get(new AxisAngle4d()));
  }
  main_input.update();
  if(sample_sequence.size()>0){
    String type=sample_sequence.get(0).getString("type");
    switch(type){
      case "temporal":
        if(!((RayTracer)renderer).move){
          ((RayTracer)renderer).move=true;
          sequence_progress=frameCount;
        }
        break;
      case "accum":
        if(((RayTracer)renderer).move){
          ((RayTracer)renderer).move=false;
          ((RayTracer)renderer).num_iterations=0;
          sequence_progress=frameCount+2;
          delay(100);
        }
        break;
    }
    int sample=sample_sequence.get(0).getInt("sample");
    if(frameCount-sequence_progress==sample){
      String host="PC";
      try {
          host=InetAddress.getLocalHost().getHostName();
      }catch (Exception e) {
          e.printStackTrace();
      }
      save("./data/presets/result/"+host+"-"+model_name+"-"+type+sample+".png");
      sequence_progress=frameCount;
      sample_sequence.remove(0);
    }
  }
}

void windowResized(){
}

void exit(){
  OdeHelper.closeODE();
  super.exit();
}

void initPhysics(){
  OdeHelper.initODE();
  
  world=OdeHelper.createWorld();
  world.setGravity(0,-9.81,0);
  world.setQuickStepNumIterations(1);
  
  space=OdeHelper.createSimpleSpace();
  contactGroup=new DxJointGroup();
}

HashMap<PlayerCapsule,DVector3>vel=new HashMap<>();

void stepPhysics(){
  world.quickStep(0.016);
  contactGroup.clear();
  collide();
  vel.forEach((o,v)->{
    o.setPosition(new DVector3(o.getPosition()).add(v));
    o.getBody().setLinearVel(0,0,0);
  });
  vel.clear();
}

void collide(){
  space.collide(null,(data,o1,o2)->{
    DContactBuffer contacts = new DContactBuffer(10);
    int n=OdeHelper.collide(o1, o2, 1, contacts.getGeomBuffer());
    for(int i=0;i<n;i++){
      DContact contact = contacts.get(i);
      
      if(o1 instanceof PlayerCapsule){
        DVector3 penetrationVector=new DVector3();
        penetrationVector.set(contact.geom.normal);
        penetrationVector.scale(contact.geom.depth);
        if(vel.containsKey(o1)){
          vel.replace((PlayerCapsule)o1,vel.get(o1).add(penetrationVector));
        }else{
          vel.put((PlayerCapsule)o1,penetrationVector);
        }
        return;
      }
      
      contact.surface.mode = OdeConstants.dContactBounce;
      contact.surface.mu = OdeConstants.dInfinity;
      contact.surface.bounce = 0.0;
      DJoint c = OdeHelper.createContactJoint(world, contactGroup, contact);
      c.attach(o1.getBody(), o2.getBody());
    }
  });
}

float astep(double d,double ep){
  return java.lang.Math.abs(d)<=ep?0:1;
}

ArrayList<JSONObject>sample_sequence=new ArrayList<>();
int sequence_progress=0;
String model_name;

void loadPreset(String path){
  JSONObject o=loadJSONObject(path);
  String model=o.getString("model");
  int idx=model.lastIndexOf("/");
  model_name=model.substring(idx+1,model.length()).replace(".glb","");
  loadGLTF(model.substring(0,idx+1),model.substring(idx+1,model.length()));
  JSONArray pos=o.getJSONArray("position");
  renderer.player.camera.origin.set(new Vector3d(pos.getFloat(0),pos.getFloat(1),pos.getFloat(2)));
  JSONArray rot=o.getJSONArray("rotation");
  renderer.player.camera.rot.rotateLocalY(radians(rot.getFloat(0)));
  renderer.player.camera.rot.rotateX(radians(rot.getFloat(1)));
  JSONArray screenshot=o.getJSONArray("screenshot");
  for(int i=0;i<screenshot.size();i++){
    sample_sequence.add(screenshot.getJSONObject(i));
  }
  sequence_progress=frameCount;
}
