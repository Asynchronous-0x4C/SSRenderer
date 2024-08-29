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
