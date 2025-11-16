class Triangle{
  float[] v1;
  float[] v2;
  float[] v3;
  float[] center;
  float[] min;
  float[] max;
  int index;
  
  Triangle(float[] data,int index){
    v1=new float[]{data[0],data[1],data[2]};
    v2=new float[]{data[4],data[5],data[6]};
    v3=new float[]{data[8],data[9],data[10]};
    center=new float[]{(v1[0]+v2[0]+v3[0])/3.0,(v1[1]+v2[1]+v3[1])/3.0,(v1[2]+v2[2]+v3[2])/3.0};
    min=new float[]{min(v1[0],v2[0],v3[0]),min(v1[1],v2[1],v3[1]),min(v1[2],v2[2],v3[2])};
    max=new float[]{max(v1[0],v2[0],v3[0]),max(v1[1],v2[1],v3[1]),max(v1[2],v2[2],v3[2])};
    this.index=index;
  }
}

class BoundingBox{
  float[] min=new float[]{Float.MAX_VALUE,Float.MAX_VALUE,Float.MAX_VALUE};
  float[] max=new float[]{-Float.MAX_VALUE,-Float.MAX_VALUE,-Float.MAX_VALUE};
  Triangle[] triangles;
  int offset=0;
  int depth=0;
  int r=0;
  int l=0;
  
  BoundingBox(Triangle[] triangles,int offset,int depth){
    this.triangles=triangles;
    this.offset=offset;
    this.depth=depth;
    for(Triangle t:triangles){
      for(int i=0;i<3;i++){
        min[i]=min(min[i],t.min[i]);
        max[i]=max(max[i],t.max[i]);
      }
    }
  }
  
  BoundingBox[] splitAt(int index){
    if(index<=0||triangles.length<=index)return new BoundingBox[]{this};
    return new BoundingBox[]{new BoundingBox(Arrays.copyOfRange(triangles,0,index),offset,depth+1),new BoundingBox(Arrays.copyOfRange(triangles,index,triangles.length),offset+index,depth+1)};
  }
  
  float getSAH(){
    float x=max[0]-min[0];
    float y=max[1]-min[1];
    float z=max[2]-max[2];
    return 2*(x*y+x*z+y*z)*triangles.length;
  }
  
  int getLargest(){
    float dx=max[0]-min[0];
    float dy=max[1]-min[1];
    float dz=max[2]-min[2];
    float mx=max(dx,dy,dz);
    return dx==mx?0:dy==mx?1:2;
  }
  
  void sort(){
    int l=getLargest();
    Arrays.sort(triangles,new Comparator<Triangle>(){
      int compare(Triangle x,Triangle y){
        return sign(x.center[l]-y.center[l]);
      }
    });
  }
  
  boolean isLeaf(){
    return triangles.length==1;
  }
}

float[] parallelBVH(float[] v){
  Triangle[] triangles=new Triangle[v.length/16];
  for(int i=0;i<triangles.length;i++){
    triangles[i]=new Triangle(Arrays.copyOfRange(v,i*16,(i+1)*16),i);
  }
  BoundingBox[] top=new BoundingBox[triangles.length*2-1];
  top[0]=new BoundingBox(triangles,0,0);
  //int offset=1;
  for(int i=0;i<top.length;i++){
    BoundingBox target=top[i];
    if(target==null){
      break;
    }
    if(target.isLeaf()){
      target.l=-1;
      target.r=target.triangles[0].index;
      continue;
    }
    //sort triangles by axis
    target.sort();
    BoundingBox[] result=splitBySAH(target);
    target.r=i+1;
    top[target.r]=result[0];
    target.l=i+result[0].triangles.length*2;
    top[target.l]=result[1];
    target.triangles=null;
  }
  float[] t=new float[top.length*8];
  for(int i=0;i<top.length;i++){
    BoundingBox b=top[i];
    t[i*8  ]=b.min[0];
    t[i*8+1]=b.min[1];
    t[i*8+2]=b.min[2];
    t[i*8+3]=Float.intBitsToFloat(b.r);
    t[i*8+4]=b.max[0];
    t[i*8+5]=b.max[1];
    t[i*8+6]=b.max[2];
    t[i*8+7]=Float.intBitsToFloat(b.l);
  }
  return t;
}

BoundingBox[] splitBySAH(BoundingBox b){
  int n=b.triangles.length;
  float best_score=Float.MAX_VALUE;
  //BoundingBox[] best_AABB=null;
  int best_index=1;
  float[] a_min=new float[]{Float.MAX_VALUE,Float.MAX_VALUE,Float.MAX_VALUE};
  float[] a_max=new float[]{-Float.MAX_VALUE,-Float.MAX_VALUE,-Float.MAX_VALUE};
  float[] d_min=new float[]{Float.MAX_VALUE,Float.MAX_VALUE,Float.MAX_VALUE};
  float[] d_max=new float[]{-Float.MAX_VALUE,-Float.MAX_VALUE,-Float.MAX_VALUE};
  float[] SAH=new float[n-1];
  for(int i=1;i<n;i++){
    for(int j=0;j<3;j++){
      a_min[j]=min(a_min[j],b.triangles[i-1].min[j]);
      a_max[j]=max(a_max[j],b.triangles[i-1].max[j]);
    }
    float x=a_max[0]-a_min[0];
    float y=a_max[1]-a_min[1];
    float z=a_max[2]-a_min[2];
    if(SAH[i-1]==0){
      SAH[i-1]=(y*(x+z)+z*x)*i;
    }else{
      SAH[i-1]+=(y*(x+z)+z*x)*i;
      if(SAH[i-1]<best_score){
        best_score=SAH[i-1];
        best_index=i;
      }
    }
    
    for(int j=0;j<3;j++){
      d_min[j]=min(d_min[j],b.triangles[n-i].min[j]);
      d_max[j]=max(d_max[j],b.triangles[n-i].max[j]);
    }
    x=d_max[0]-d_min[0];
    y=d_max[1]-d_min[1];
    z=d_max[2]-d_min[2];
    if(SAH[n-i-1]==0){
      SAH[n-i-1]=(y*(x+z)+z*x)*i;
    }else{
      SAH[n-i-1]+=(y*(x+z)+z*x)*i;
      if(SAH[n-i-1]<best_score){
        best_score=SAH[n-i-1];
        best_index=n-i;
      }
    }
  }//println(Arrays.toString(SAH));
  return b.splitAt(best_index);
}

class BVHConstructor implements Supplier<float[]>{
  ArrayList<BoundingBox>tree=new ArrayList<>();
  int index=0;
  
  BVHConstructor(BoundingBox root){
    //offset: offset of AABB array.
    tree.add(root);
  }
  
  float[] get(){
    int offset=1;
    for(int i=0;i<tree.size();i++){
      BoundingBox target=tree.get(i);
      if(target==null)continue;
      if(target.isLeaf()){
        target.l=-1;
        target.r=target.triangles[0].index;
        continue;
      }
      //sort triangles by axis
      target.sort();
      BoundingBox[] result=splitBySAH(target);
      target.r=offset++;
      tree.add(result[0]);
      target.l=offset++;
      tree.add(result[1]);
      target.triangles=null;
    }
    float[] result=new float[tree.size()*8];
    for(int i=0;i<tree.size();i++){
      BoundingBox b=tree.get(i);
      result[i*8  ]=b.min[0];
      result[i*8+1]=b.min[1];
      result[i*8+2]=b.min[2];
      result[i*8+3]=b.r;
      result[i*8+4]=b.max[0];
      result[i*8+5]=b.max[1];
      result[i*8+6]=b.max[2];
      result[i*8+7]=b.l;
    }
    //split bvh without depth limit.
    return result;
  }
}
