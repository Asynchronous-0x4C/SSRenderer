abstract class Renderer extends SObject{
  HashMap<String,LightComponent>lights;
  
  CubemapTexture hdri;
  
  Level level;
  
  DefaultPlayer player;
  
  Renderer(){
    lights=new HashMap<>();
    level=new Level();
    initFrameBuffer();
    initProgram();
    player=new DefaultPlayer();
    //main_camera=new Camera();
    //main_camera.setPerspective(radians(70), 16.0/9.0, 0.1, 1000.0);
    //main_camera.setOrtho(-3.2,3.2,-1.8,1.8,0, 100.0);
    //level.add("camera",main_camera);
    level.add("player",player);
    //DirectionalLight dl=new DirectionalLight(new Vector3d(0.5,5,10),new Vector3d(-1,-2,-1).normalize(),true);
    //dl.setColor(1.0,0.8,0.5);
    //lights.put("sun",dl);
    //level.add("sun",dl);
    //DirectionalLight dl2=new DirectionalLight(new Vector3d(5,2,0.5),new Vector3d(-5,-2,-0.5).normalize(),true);
    //dl2.setColor(1.0,0.3,0.5).setIntensity(2.0);
    //lights.put("sun2",dl2);
    //level.add("sun2",dl2);
  }
  
  abstract void initFrameBuffer();
  
  abstract void initProgram();
  
  void update(){
    level.update();
  }
  
  abstract void display();
}

class Profiler{
  LinkedHashMap<String,Long>profiles;
  
  final float unit=1000000;
  
  Profiler(){
    profiles=new LinkedHashMap<>();
  }
  
  void start(String name){
    profiles.putIfAbsent(name,0l);
    profiles.replace(name,System.nanoTime());
  }
  
  void end(String name){
    profiles.replace(name,System.nanoTime()-profiles.get(name));
  }
  
  float get(String name){
    return profiles.get(name)/unit;
  }
  
  void display(){
    textSize(13);
    float[] w={100};
    profiles.forEach((n,t)->{
      w[0]=max(w[0],textWidth(n+": "+nf(t/unit,0,1)));
    });
    int num=floor(height/15.0);
    noStroke();
    fill(0,128);
    rect(0,0,w[0]*(1+floor(15*profiles.size()/(float)height))+5,profiles.size()*15+5);
    fill(255);
    int[]i={0};
    profiles.forEach((n,t)->{
      float left=5+w[0]*floor(15*(i[0]+1)/(float)height);
      text(n+": "+nf(t/unit,0,1),left,15*((i[0])%num+1));
      i[0]++;
    });
  }
}

class Settings{
  ArrayList<JSONObject>sample_sequence=new ArrayList<>();
  int sequence_progress=0;
  String model_name;
  String model_path="";
  
  boolean physics=false;
  float[] position=new float[]{0,0,0};
  float[] rotation=new float[]{0,0};
  
  String renderer_type="PathTracer";
  int reflection=4;
  int seed=0;
  
  Settings(String path){
    JSONObject o=loadJSONObject(path);
    load(o);
    JSONObject scene=loadJSONObject(o.getString("scene"));
    load(scene);
  }
  
  void load(JSONObject o){
    if(o.hasKey("model")){
      model_path=o.getString("model");
      int idx=model_path.lastIndexOf("/");
      model_name=model_path.substring(idx+1,model_path.length()).replace(".glb","");
    }
    physics=o.getBoolean("physics",physics);
    if(o.hasKey("camera")){
      JSONObject camera=o.getJSONObject("camera");
      if(camera.hasKey("position"))position=camera.getJSONArray("position").toFloatArray();
      if(camera.hasKey("rotation"))rotation=camera.getJSONArray("rotation").toFloatArray();
    }
    reflection=o.getInt("reflection",reflection);
    seed=o.getInt("seed",0);
    if(o.hasKey("screenshot")){
      JSONArray screenshot=o.getJSONArray("screenshot");
      for(int i=0;i<screenshot.size();i++){
        sample_sequence.add(screenshot.getJSONObject(i));
      }
      sequence_progress=frameCount;
    }
  }
  
  void loadScene(){
    initPhysics();
    switch(renderer_type){
      case "PathTracer":renderer=new RayTracer();break;
      //case "Rasterizer":renderer=new Rasterizer();break;
      default:renderer=new RayTracer();
    }
    int idx=model_path.lastIndexOf("/");
    loadGLTF(model_path.substring(0,idx+1),model_path.substring(idx+1,model_path.length()));
  }
  
  void applySettings(){
    if(physics){
      renderer.player.body.setPosition(position[0],position[1],position[2]);
    }else{
      renderer.player.camera.origin.set(position[0],position[1],position[2]);
    }
    renderer.player.camera.free=!physics;
    if(rotation.length==2){
      renderer.player.camera.rot.rotateLocalY(radians(rotation[0]));
      renderer.player.camera.rot.rotateX(radians(rotation[1]));
    }else if(rotation.length==4){
      renderer.player.camera.rot=new Quaterniond(rotation[0],rotation[1],rotation[2],rotation[3]);
    }
    if(renderer instanceof RayTracer){
      ((RayTracer)renderer).num_reflect=reflection;
    }
  }
}
