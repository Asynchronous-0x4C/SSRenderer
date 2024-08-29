import de.javagl.obj.*;

import de.javagl.jgltf.model.*;
import de.javagl.jgltf.model.v2.*;
import de.javagl.jgltf.model.io.GltfAsset;
import de.javagl.jgltf.model.io.GltfAssetReader;

import de.javagl.jgltf.impl.v2.*;

import java.net.*;

String convertObjPath(String base,String path){
  return (path.contains(":/")?path.replace("C:/",sketchPath()+base):sketchPath()+base+path).replace("\\","/");
}

void loadObj(String base,String name){
  if(!name.endsWith(".obj"))name+=".obj";
  try {
    InputStream objInputStream=new FileInputStream(sketchPath()+base+name);
    Obj originalObj=ObjReader.read(objInputStream);

    object=ObjUtils.convertToRenderable(originalObj);
  }
  catch(Exception e) {
    e.printStackTrace();
  }
  Map<String, Obj> objectGroups=ObjSplitting.splitByGroups(object);
  objectGroups.forEach((k, v)-> {
    Map<String,Mtl> allMtls = new HashMap<String,Mtl>();
    for (String mtlFileName : v.getMtlFileNames()) {
      try {
        InputStream mtlInputStream=new FileInputStream(sketchPath()+base+mtlFileName);
        java.util.List<Mtl> mtls = MtlReader.read(mtlInputStream);
        mtls.forEach(m->{
          Optional.ofNullable(m.getMapKd()).ifPresent(kd->m.setMapKd(convertObjPath(base,kd)));
          Optional.ofNullable(m.getMapNs()).ifPresent(ns->m.setMapNs(convertObjPath(base,ns)));
          Optional.ofNullable(m.getMapKs()).ifPresent(ks->m.setMapKs(convertObjPath(base,ks)));
          Optional.ofNullable(m.getMapKe()).ifPresent(ke->m.setMapKe(convertObjPath(base,ke)));
          Optional.ofNullable(m.getMapPr()).ifPresent(pr->m.setMapPr(convertObjPath(base,pr)));
          Optional.ofNullable(m.getMapPm()).ifPresent(pm->m.setMapPm(convertObjPath(base,pm)));
          allMtls.put(m.getName(),m);
        });
      }
      catch(Exception e) {
        e.printStackTrace();
      }
    }
    Map<String,Obj>before=ObjSplitting.splitByMaterialGroups(v);
    Map<String,MeshData>after=new HashMap<>();
    Map<String,Material>after_m=new HashMap<>();
    before.forEach((n,o)->{
      after.put(n,new ObjMeshData(o));
    });
    allMtls.forEach((n,m)->{
      after_m.put(n,new ObjMaterial(m,main_cache));
    });
    renderer.level.add(k,new StaticMesh(after,after_m,new Matrix4d()));
  });
}

void loadGLTF(String base,String name){
  if(!name.endsWith(".glb")&&!name.endsWith(".gltf"))name+=".glb";
  GltfAssetReader gltfAssetReader = new GltfAssetReader();
  GltfAsset gltfAsset=null;
  try{
    gltfAsset = gltfAssetReader.read(new URI("file:/"+sketchPath().replace("\\","/")+base+name));
  }catch(Exception e){
    e.printStackTrace();
  }
  if(gltfAsset==null){
    System.out.println("model: "+base+name+" load failed.");
    return;
  }
  GltfModel gltfModel=GltfModels.create(gltfAsset);
  
  for(NodeModel node:gltfModel.getSceneModels().get(0).getNodeModels()){
    traverseNodeGLTF(node,new Matrix4d().set(new float[]{1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}));
  }
  if(renderer instanceof RayTracer){
    ((RayTracer)renderer).reloadVertices();
    ((RayTracer)renderer).reloadMaterials();
  }
}

void traverseNodeGLTF(NodeModel node,Matrix4d mat){
  Matrix4d mat_c=new Matrix4d(mat);
  float[] node_mat=node.getMatrix();
  if(node_mat!=null){
    mat_c=mat_c.mul(new Matrix4d().set(node_mat));
  }else{
    mat_c.translation(node.getTranslation()!=null?new Vector3d(node.getTranslation()):new Vector3d(0, 0, 0));
    mat_c.rotate(node.getRotation()!=null?new Quaterniond(node.getRotation()[0],node.getRotation()[1],node.getRotation()[2],node.getRotation()[3]):new Quaterniond(0,0,0,1));
    mat_c.scale(node.getScale()!=null?new Vector3d(node.getScale()):new Vector3d(1, 1, 1));
  }
  
  for(MeshModel mesh:node.getMeshModels()){
    String name=mesh.getName();
  
    HashMap<String,MeshData>mesh_data=new HashMap<>();
    HashMap<String,Material>material_data=new HashMap<>();
    
    for(MeshPrimitiveModel mesh_primitive:mesh.getMeshPrimitiveModels()){
      GLTFMeshData data=new GLTFMeshData(mesh_primitive);
      MaterialModelV2 material=(MaterialModelV2)mesh_primitive.getMaterialModel();
      String mtl_name=material.getName();
      mesh_data.put(mtl_name,data);
      if(!material_set.containsKey(mtl_name)){
        material_set.put(mtl_name,new GLTFMaterial(material,main_cache));
        material_data.put(mtl_name,material_set.get(mtl_name));
        materials.add(material_set.get(mtl_name));
      }else{
        material_data.put(mtl_name,material_set.get(mtl_name));
      }
    }
    StaticMesh m=new StaticMesh(mesh_data,material_data,mat_c);
    renderer.level.add(name,m);
  }
  
  if(node.getChildren()==null)return;
  for(NodeModel child:node.getChildren()){
    if(child!=null)traverseNodeGLTF(child,mat_c);
  }
}

abstract class MeshData{
  int vertices_count;
  float[] vertices;
  float[] normal;
  float[] tangent;
  float[] uv;
  final int components=11;
  
  float[] getVertices(int idx){
    int s=idx*3;
    return new float[]{vertices[s],vertices[s+1],vertices[s+2]};
  }
  
  float[] getNormal(int idx){
    int s=idx*3;
    return new float[]{normal[s],normal[s+1],normal[s+2]};
  }
  
  float[] getTangent(int idx){
    int s=idx*3;
    return new float[]{tangent[s],tangent[s+1],tangent[s+2]};
  }
  
  float[] getUV(int idx){
    int s=idx*2;
    return new float[]{uv[s],uv[s+1]};
  }
  
  float[] getAttribute(){
    float[] res=new float[vertices_count*components];
    for(int i=0,n=0;i<res.length;i+=components,n++){
      res[i   ]=vertices[n*3  ];
      res[i+1 ]=vertices[n*3+1];
      res[i+2 ]=vertices[n*3+2];
      
      res[i+3 ]=normal[n*3  ];
      res[i+4 ]=normal[n*3+1];
      res[i+5 ]=normal[n*3+2];
      
      res[i+6 ]=tangent[n*3  ];
      res[i+7 ]=tangent[n*3+1];
      res[i+8 ]=tangent[n*3+2];
      
      res[i+9 ]=uv[n*2  ];
      res[i+10]=uv[n*2+1];
    }
    return res;
  }
  
  Vector3f t2v(FloatTuple t){
    return new Vector3f(t.getX(),t.getY(),t.getDimensions()==2?0:t.getZ());
  }
}

class ObjMeshData extends MeshData{
  
  ObjMeshData(Obj o){
    int[] vert_idx=ObjData.getFaceVertexIndicesArray(o);
    int[] norm_idx=ObjData.getFaceNormalIndicesArray(o);
    int[] uv_idx=ObjData.getFaceTexCoordIndicesArray(o);
    vertices_count=vert_idx.length;
    
    vertices=new float[vertices_count*3];
    normal=new float[vertices_count*3];
    tangent=new float[vertices_count*3];
    uv=new float[vertices_count*2];
    
    Vector3f tangent=new Vector3f(1,0,0);
    for(int i=0;i<vertices_count;i++){
      FloatTuple v=o.getVertex(vert_idx[i]);
      FloatTuple n=o.getNormal(norm_idx[i]);
      FloatTuple uv=o.getTexCoord(uv_idx[i]);
      
      if(i%3==0){
        tangent=calcTangent(o,vert_idx,uv_idx,i);
      }
      
      vertices[i*3  ]=v.getX();
      vertices[i*3+1]=v.getY();
      vertices[i*3+2]=v.getZ();
      if(n==null){
        Vector3f nv=calcNormal(o,vert_idx,i);
        normal[i*3  ]=nv.x;
        normal[i*3+1]=nv.y;
        normal[i*3+2]=nv.z;
      }else{
        normal[i*3  ]=n.getX();
        normal[i*3+1]=n.getY();
        normal[i*3+2]=n.getZ();
      }
      this.tangent[i*3  ]=tangent.x;
      this.tangent[i*3+1]=tangent.y;
      this.tangent[i*3+2]=tangent.z;
      if(uv==null){
        this.uv[i*2  ]=0;
        this.uv[i*2+1]=0;
      }else{
        this.uv[i*2  ]=uv.getX();
        this.uv[i*2+1]=uv.getY();
      }
    }
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

class GLTFMeshData extends MeshData{
  
  GLTFMeshData(MeshPrimitiveModel m){
    Map<String,AccessorModel>attr=m.getAttributes();
    AccessorModel indices=m.getIndices();
    vertices_count=indices.getCount();
    
    attr.forEach((k,v)->{
      int count=v.getCount();
      ElementType t=v.getElementType();
      float[] component=new float[count*t.getNumComponents()];
      
      BufferViewModel bv=v.getBufferViewModel();
      int offset=bv.getByteOffset();
      int bytes=getBytes(v.getComponentDataType());
      byte[] arr=bv.getBufferViewData().array();
      int dataOffset=offset+(arr.length-bv.getBufferModel().getByteLength());
      int stride=v.getByteStride()-bytes*t.getNumComponents();
      for(int i=0;i<component.length;i++){
        int intValue =(arr[dataOffset  ]&0xFF);
            intValue|=(arr[dataOffset+1]&0xFF)<<8;
            intValue|=(arr[dataOffset+2]&0xFF)<<16;
            intValue|=(arr[dataOffset+3]&0xFF)<<24;
        component[i]=Float.intBitsToFloat(intValue);
        dataOffset+=bytes+stride;
      }
      
      switch(k){
        case "POSITION":vertices=component;break;//set min/max
        case "NORMAL":normal=component;break;
        case "TEXCOORD_0":uv=component;break;
      }
    });
    
    int[] idx_array=new int[vertices_count];
    BufferViewModel bv=indices.getBufferViewModel();
    int offset=bv.getByteOffset();
    int bytes=getBytes(indices.getComponentDataType());
    byte[] arr=bv.getBufferViewData().array();
    int dataOffset=offset+(arr.length-bv.getBufferModel().getByteLength());
    for(int i=0;i<idx_array.length;i++){
      int intValue =(arr[dataOffset  ]&0xFF);
          intValue|=(arr[dataOffset+1]&0xFF)<<8;
      idx_array[i]=(int)intValue;
      dataOffset+=bytes;
    }
    
    float[] t_vert=new float[idx_array.length*3];
    float[] t_norm=new float[idx_array.length*3];
    float[] t_uv=new float[idx_array.length*2];
    tangent=new float[idx_array.length*3];
    
    for(int i=0;i<idx_array.length;i++){
      t_vert[i*3  ]=vertices[idx_array[i]*3  ];
      t_vert[i*3+1]=vertices[idx_array[i]*3+1];
      t_vert[i*3+2]=vertices[idx_array[i]*3+2];
      
      t_norm[i*3  ]=normal[idx_array[i]*3  ];
      t_norm[i*3+1]=normal[idx_array[i]*3+1];
      t_norm[i*3+2]=normal[idx_array[i]*3+2];
      
      t_uv[i*2  ]=uv[idx_array[i]*2  ];
      t_uv[i*2+1]=uv[idx_array[i]*2+1];
    }
    vertices=t_vert;
    normal=t_norm;
    uv=t_uv;
    
    calcTangent();
  }
  
  private void calcTangent(){
    int num=vertices.length/9;
    for(int i=0;i<num;i++){
      Vector3f tan=new Vector3f();
      Vector3f[] tv=new Vector3f[3];
      Vector3f[] tuv=new Vector3f[3];
      for(int j=0;j<3;j++){
        tv[j]=new Vector3f(vertices[i*9+j*3],vertices[i*9+j*3+1],vertices[i*9+j*3+2]);
        tuv[j]=new Vector3f(uv[i*6+j*2],uv[i*6+j*2+1],0);
      }
      
      Vector3f delta_pos1=tv[1].sub(tv[0]);
      Vector3f delta_pos2=tv[2].sub(tv[0]);
      
      Vector3f delta_uv1=tuv[1].sub(tuv[0]);
      Vector3f delta_uv2=tuv[2].sub(tuv[0]);
      
      float r=1.0/(delta_uv1.x*delta_uv2.y-delta_uv1.y*delta_uv2.x);
      if(Float.isNaN(r)||Float.isInfinite(r)){
        tan=new Vector3f(delta_pos1).normalize();
      }else{
        tan=new Vector3f(delta_pos1).mul(delta_uv2.y).sub(delta_pos2.mul(delta_uv1.y)).mul(r).normalize();
      }
      
      for(int j=0;j<3;j++){
        tangent[i*9+j*3  ]=tan.x;
        tangent[i*9+j*3+1]=tan.y;
        tangent[i*9+j*3+2]=tan.z;
      }
    }
  }
  
  int getBytes(Class<?> c){
    int res=0;
    switch(c.getName()){
      case "float":res=4;break;
      case "int":res=4;break;
      case "short":res=2;break;
      case "byte":res=1;break;
      case "boolean":res=4;break;
    }
    return res;
  }
}

abstract class Material{
  String name;
  TextureCache cache;
  MaterialParam<Vector3f> albedo;
  MaterialParam<Vector3f> normal;
  MaterialParam<Vector3f> specular;
  MaterialParam<Vector3f> emission;
  MaterialParam<Float> metalness;
  MaterialParam<Float> roughness;
  MaterialParam<Float> transmission;
  MaterialParam<Float> IOR;
  MaterialParam<Float> anisotropy_s;
  MaterialParam<Float> anisotropy_r;
  
  Material(){
    this(new Vector3f(1.0),new Texture().load(1,1,new byte[]{-128,-128,-1,-1}),new Vector3f(0.5),new Vector3f(0),0,0,0,1,0,0);
  }
  
  Material(Vector3f albedo,Texture normal,Vector3f specular,Vector3f emission,float metalness,float roughness,float transmission,float IOR,float anisotropy_s,float anisotropy_r){
    this.albedo=new MaterialParam<>(new Texture().load(1,1,new byte[]{-1,-1,-1,-1}),albedo);
    this.normal=new MaterialParam<>(normal,new Vector3f());
    this.specular=new MaterialParam<>(new Texture().load(1,1,new byte[]{-1,-1,-1,-1}),specular);
    this.emission=new MaterialParam<>(new Texture().load(1,1,new byte[]{-1,-1,-1,-1}),emission);
    this.metalness=new MaterialParam<>(new Texture().load(1,1,new byte[]{-1,-1,-1,-1}),metalness);
    this.roughness=new MaterialParam<>(new Texture().load(1,1,new byte[]{-1,-1,-1,-1}),roughness);
    this.transmission=new MaterialParam<>(transmission);
    this.IOR=new MaterialParam<>(IOR);
    this.anisotropy_s=new MaterialParam<>(anisotropy_s);
    this.anisotropy_r=new MaterialParam<>(anisotropy_r);
  }
  
  String getName(){
    return name;
  }
}

class ObjMaterial extends Material{
  
  ObjMaterial(Mtl mat,TextureCache cache){
    super();
    this.cache=cache;
    albedo=new MaterialParam<>(new Texture().load(1,1,new byte[]{-1,-1,-1,-1}),new Vector3f(1.0,1.0,1.0));
    if(mat.getKd()!=null)albedo.setParam(TupleToVector3(mat.getKd()));
    if(mat.getMapKd()!=null)albedo.setTexture(cache.get(mat.getMapKd()));
    
    normal=new MaterialParam<>(new Vector3f());
    normal.setTexture(new Texture().load(1,1,new byte[]{-128,-128,-1,-1}));
    Optional.ofNullable(mat.getMapNs()).ifPresent(s->normal.setTexture(cache.get(s)));
    
    specular=new MaterialParam<>(new Texture().load(1,1,new byte[]{-1,-1,-1,-1}),new Vector3f(0.5,0.5,0.5));
    if(mat.getKs()!=null)specular.setParam(TupleToVector3(mat.getKs()));
    if(mat.getMapKs()!=null)specular.setTexture(cache.get(mat.getMapKs()));
    
    emission=new MaterialParam<>(new Texture().load(1,1,new byte[]{-1,-1,-1,-1}),new Vector3f(0.0,0.0,0.0));
    if(mat.getKe()!=null)emission.setParam(TupleToVector3(mat.getKe()));
    if(mat.getMapKe()!=null)emission.setTexture(cache.get(mat.getMapKe()));
    
    metalness=new MaterialParam<>(new Texture().load(1,1,new byte[]{-1,-1,-1,-1}),1.0);
    Optional.ofNullable(mat.getPm()).ifPresent(pm->metalness.setParam(pm));
    Optional.ofNullable(mat.getMapPm()).ifPresent(pm->metalness.setTexture(cache.get(pm)));
    
    roughness=new MaterialParam<>(new Texture().load(1,1,new byte[]{-1,-1,-1,-1}),1.0);
    Optional.ofNullable(mat.getPr()).ifPresent(pr->roughness.setParam(pr));
    Optional.ofNullable(mat.getMapPr()).ifPresent(pr->roughness.setTexture(cache.get(pr)));
    
    transmission=new MaterialParam<>(1.0-mat.getD());
    IOR=new MaterialParam<>(1.45);
    
    name=mat.getName();
  }
}

class GLTFMaterial extends Material{
  
  GLTFMaterial(MaterialModelV2 mat,TextureCache cache){
    super();
    this.cache=cache;
    name=mat.getName();
    
    albedo=new MaterialParam<>(new Texture().load(1,1,new byte[]{-1,-1,-1,-1}),new Vector3f(mat.getBaseColorFactor()));
    Optional.ofNullable(mat.getBaseColorTexture()).ifPresent(t->cache.getAsync(t.getImageModel(),albedo));
    
    normal=new MaterialParam<>(new Vector3f());
    normal.setTexture(new Texture().load(1,1,new byte[]{-128,-128,-1,-1}));
    Optional.ofNullable(mat.getNormalTexture()).ifPresent(s->cache.getAsync(s.getImageModel(),normal));
    
    Vector3f spec=mat.getExtensions()!=null?
                    mat.getExtensions().containsKey("KHR_materials_specular")?
                      ListToVector3f(((LinkedHashMap<String,ArrayList<Double>>)mat.getExtensions().get("KHR_materials_specular")).get("specularColorFactor"),new Vector3f(0.5)):
                    new Vector3f(0.5):
                  new Vector3f(0.5);
    specular=new MaterialParam<>(new Texture().load(1,1,new byte[]{-1,-1,-1,-1}),spec);
    Optional.ofNullable(mat.getBaseColorTexture()).ifPresent(t->cache.getAsync(t.getImageModel(),specular));
    
    emission=new MaterialParam<>(new Texture().load(1,1,new byte[]{-1,-1,-1,-1}),new Vector3f(mat.getEmissiveFactor()));
    Optional.ofNullable(mat.getEmissiveTexture()).ifPresent(t->cache.getAsync(t.getImageModel(),emission));
    
    metalness=new MaterialParam<>(new Texture().load(1,1,new byte[]{-1,-1,-1,-1}),mat.getMetallicFactor());
    Optional.ofNullable(mat.getMetallicRoughnessTexture()).ifPresent(t->cache.getAsync(t.getImageModel(),metalness));
    
    roughness=new MaterialParam<>(new Texture().load(1,1,new byte[]{-1,-1,-1,-1}),mat.getRoughnessFactor());
    
    IOR=new MaterialParam<>(new Texture().load(1,1,new byte[]{-1,-1,-1,-1}),getExtensionFactor(mat,"KHR_materials_ior","ior",1));
    transmission=new MaterialParam<>(new Texture().load(1,1,new byte[]{-1,-1,-1,-1}),getExtensionFactor(mat,"KHR_materials_transmission","transmissionFactor",0));
    
    anisotropy_s=new MaterialParam<>(new Texture().load(1,1,new byte[]{-1,-1,-1,-1}),getExtensionFactor(mat,"KHR_materials_anisotropy","anisotropyStrength",0));
    anisotropy_r=new MaterialParam<>(new Texture().load(1,1,new byte[]{-1,-1,-1,-1}),getExtensionFactor(mat,"KHR_materials_anisotropy","anisotropyRotation",0));
  }
  
  float getExtensionFactor(MaterialModel m,String name,String value,float init){
    return m.getExtensions()!=null?m.getExtensions().containsKey(name)?((LinkedHashMap<String,Number>)m.getExtensions().get(name)).get(value).floatValue():init:init;
  }
}

class MaterialParam<T>{
  Texture texture;
  T param;
  
  MaterialParam(T param){
    this.param=param;
  }
  
  MaterialParam(Texture d,T p){
    texture=d;
    param=p;
  }
  
  MaterialParam<T> setTexture(Texture t){
    texture=t;
    return this;
  }
  
  void setParam(T param){
    this.param=param;
  }
  
  T get(){
    return param;
  }
  
  Optional<Texture> getTexture(){
    return Optional.ofNullable(texture);
  }
}
