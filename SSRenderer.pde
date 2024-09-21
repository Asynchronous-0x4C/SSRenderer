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
  frameRate(75);
  //fullScreen(P2D);
  windowTitle("Signal");
  gl = (GL4)((PJOGL)((PGraphicsOpenGL)g).pgl).gl;
  ((PJOGL)((PGraphicsOpenGL)g).pgl).gl.glEnable(GL4.GL_TEXTURE_CUBE_MAP_SEAMLESS);
  main_input=new Input(this,(PSurfaceJOGL)surface);
  main_input.getKeyBoard().addKeyBind("Jump",(int)VK_SPACE);
  main_cache=new TextureCache();
  profiler=new Profiler();
  tasks=Collections.synchronizedList(new ArrayList<>());
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
    loadGLTF("/data/models/Exit8/","Exit8.glb");
    //loadGLTF("/data/models/demo/","demo.glb");
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
  future=CompletableFuture.runAsync(()->stepPhysics());
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
  fill(255,0,255);
  text("frameRate: "+nf(frameRate,0,1),105,15);
  main_input.update();
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
