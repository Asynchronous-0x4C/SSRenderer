import javax.imageio.*;

class RenderBuffer{
  IntBuffer id;
  
  RenderBuffer(){
    id=GLBuffers.newDirectIntBuffer(1);
    gl.glGenRenderbuffers(1,id);
  }
  
  void load(){
    bind();
    gl.glRenderbufferStorage(GL4.GL_RENDERBUFFER, GL4.GL_DEPTH_COMPONENT16, width, height);
  }
  
  void bind(){
    gl.glBindRenderbuffer(GL4.GL_RENDERBUFFER,id.get(0));
  }
}

class FrameBuffer{
  IntBuffer id;
  ArrayList<Integer>colors=new ArrayList<>();
  int[] drawBuffers=new int[1];
  int size=0;
  
  FrameBuffer(){
    id=GLBuffers.newDirectIntBuffer(1);
    gl.glCreateFramebuffers(1,id);
  }
  
  void loadDepth(Texture t){
    bind();
    t.bind();
    gl.glFramebufferTexture2D(GL4.GL_FRAMEBUFFER,GL4.GL_DEPTH_ATTACHMENT,GL4.GL_TEXTURE_2D,t.id.get(0),0);
  }
  
  void load(Texture... textures){
    bind();
    for(int i=colors.size(),f=colors.size();i<f+textures.length;i++){
      textures[i-f].bind();
      gl.glFramebufferTexture2D(GL4.GL_FRAMEBUFFER,GL4.GL_COLOR_ATTACHMENT0+i,GL4.GL_TEXTURE_2D,textures[i-f].id.get(0),0);
      colors.add(GL4.GL_COLOR_ATTACHMENT0+i);
    }
    size=colors.size();
    drawBuffers=new int[size];
    for(int i=0;i<colors.size();i++){
      drawBuffers[i]=colors.get(i);
    }
    unbind();
  }
  
  void reload(Texture... textures){
    bind();
    colors.clear();
    for(int i=colors.size(),f=colors.size();i<f+textures.length;i++){
      textures[i-f].bind();
      gl.glFramebufferTexture2D(GL4.GL_FRAMEBUFFER,GL4.GL_COLOR_ATTACHMENT0+i,GL4.GL_TEXTURE_2D,textures[i-f].id.get(0),0);
      colors.add(GL4.GL_COLOR_ATTACHMENT0+i);
    }
    size=colors.size();
    drawBuffers=new int[size];
    for(int i=0;i<colors.size();i++){
      drawBuffers[i]=colors.get(i);
    }
    unbind();
  }
  
  void load(RenderBuffer b){
    bind();
    gl.glFramebufferRenderbuffer(GL4.GL_FRAMEBUFFER, GL4.GL_DEPTH_ATTACHMENT, GL4.GL_RENDERBUFFER, b.id.get(0));
  }
  
  void bind(){
    gl.glBindFramebuffer(GL4.GL_FRAMEBUFFER,id.get(0));
    gl.glDrawBuffers(colors.size(), drawBuffers, 0);
  }
  
  void unbind(){
    gl.glBindFramebuffer(GL4.GL_FRAMEBUFFER,0);
    gl.glDrawBuffer(GL4.GL_FRONT);
  }
}

class Buffer{
  IntBuffer id;
  int target;
  
  Buffer(int target){
    id=GLBuffers.newDirectIntBuffer(1);
    gl.glGenBuffers(1,id);
    this.target=target;
  }
  
  void set_data(java.nio.Buffer data,int usege){
    bind();
    gl.glBufferData(target,data.limit() * (data instanceof IntBuffer?Integer.BYTES:data instanceof FloatBuffer?Float.BYTES:Long.BYTES),data,usege);
  }
  
  void set_data(int size,int usege){
    bind();
    gl.glBufferData(target,size,null,usege);
  }
  
  void bind(){
    gl.glBindBuffer(target,id.get(0));
  }
  
  void bindBase(int binding){
    gl.glBindBufferBase(target,binding,id.get(0));
  }
  
  void unbind(){
    gl.glBindBuffer(target,0);
  }
  
  void destroyBuffer(){
    id=null;
  }
}

class VertexArray{
  IntBuffer id;
  
  VertexArray(){
    id=GLBuffers.newDirectIntBuffer(1);
    gl.glGenVertexArrays(1,id);
  }
  
  void set_attribute(int attrib_pos,int components,int stride,int offset){
    bind();
    gl.glVertexAttribPointer(attrib_pos,components,GL4.GL_FLOAT,false,stride,offset);
    gl.glEnableVertexAttribArray(attrib_pos);
  }
  
  void bind(){
    gl.glBindVertexArray(id.get(0));
  }
  
  void unbind(){
    gl.glBindVertexArray(1);
  }
  
  void destroyBuffer(){
    id=null;
  }
}

class Shader{
  int id;
  
  Shader(String source_code,int shader_type){
    id=gl.glCreateShader(shader_type);
    String[] lines = {source_code};
    IntBuffer length = GLBuffers.newDirectIntBuffer(new int[]{lines[0].length()});
    gl.glShaderSource(id,1,lines,length);
    gl.glCompileShader(id);
    IntBuffer status = GLBuffers.newDirectIntBuffer(1);
    gl.glGetShaderiv(id, GL4.GL_COMPILE_STATUS, status);
    if (status.get(0) == GL4.GL_FALSE) {

        IntBuffer infoLogLength = GLBuffers.newDirectIntBuffer(1);
        gl.glGetShaderiv(id, GL4.GL_INFO_LOG_LENGTH, infoLogLength);

        ByteBuffer bufferInfoLog = GLBuffers.newDirectByteBuffer(infoLogLength.get(0));
        gl.glGetShaderInfoLog(id, infoLogLength.get(0), null, bufferInfoLog);
        byte[] bytes = new byte[infoLogLength.get(0)];
        bufferInfoLog.get(bytes);
        String strInfoLog = new String(bytes);

        String strShaderType = "";
        switch (shader_type) {
            case GL4.GL_VERTEX_SHADER:
                strShaderType = "vertex";
                break;
            case GL4.GL_GEOMETRY_SHADER:
                strShaderType = "geometry";
                break;
            case GL4.GL_FRAGMENT_SHADER:
                strShaderType = "fragment";
                break;
        }
        System.err.println("Compiler failure in " + strShaderType + " shader: " + strInfoLog);

        infoLogLength=null;
        bufferInfoLog=null;
    }
    length=null;
    status=null;
  }
}

class ShaderProgram{
  int id;
  
  ShaderProgram(Shader... shader){
    id=gl.glCreateProgram();
    for(Shader s:shader){
      gl.glAttachShader(id,s.id);
    }
    gl.glLinkProgram(id);
    IntBuffer status = GLBuffers.newDirectIntBuffer(1);
    gl.glGetProgramiv(id, GL4.GL_LINK_STATUS, status);
    if (status.get(0) == GL4.GL_FALSE) {

        IntBuffer infoLogLength = GLBuffers.newDirectIntBuffer(1);
        gl.glGetProgramiv(id,GL4. GL_INFO_LOG_LENGTH, infoLogLength);

        ByteBuffer bufferInfoLog = GLBuffers.newDirectByteBuffer(infoLogLength.get(0));
        gl.glGetProgramInfoLog(id, infoLogLength.get(0), null, bufferInfoLog);
        byte[] bytes = new byte[infoLogLength.get(0)];
        bufferInfoLog.get(bytes);
        String strInfoLog = new String(bytes);

        System.err.println("Linker failure: " + strInfoLog);

        infoLogLength=null;
        bufferInfoLog=null;
    }

    for(Shader s:shader){
      gl.glDetachShader(id,s.id);
    }
    status=null;
  }

  void apply(){
    gl.glUseProgram(id);
  }
  
  void disable(){
    gl.glUseProgram(0);
  }

  int get_attrib_location(String attrib){
    return gl.glGetAttribLocation(id, attrib);
  }

  int get_uniform_location(String uniform){
    gl.glUseProgram(id);
    return gl.glGetUniformLocation(id, uniform);
  }
  
  void set_f32(String name,float data){
    int loc=get_uniform_location(name);
    gl.glUniform1f(loc, data);
  }
  
  void set_i32(String name,int data){
    int loc=get_uniform_location(name);
    gl.glUniform1i(loc, data);
  }
  
  void set_f32v2(String name,float x,float y){
    int loc=get_uniform_location(name);
    gl.glUniform2f(loc,x,y);
  }
  
  void set_f32v3(String name,float x,float y,float z){
    int loc=get_uniform_location(name);
    gl.glUniform3f(loc,x,y,z);
  }
  
  void set_f32v3(String name,Vector3f v){
    int loc=get_uniform_location(name);
    gl.glUniform3f(loc,v.x,v.y,v.z);
  }
  
  void set_f32v3(String name,Vector3d v){
    int loc=get_uniform_location(name);
    gl.glUniform3f(loc,(float)v.x,(float)v.y,(float)v.z);
  }
  
  void set_f32m4(String name,PMatrix3D mat){
    int loc=get_uniform_location(name);
    gl.glUniformMatrix4fv(loc,1,false,FloatBuffer.wrap(mat.get(null)));
  }
  
  void set_f32m4(String name,Matrix4f mat){
    int loc=get_uniform_location(name);
    gl.glUniformMatrix4fv(loc,1,false,mat.get(new float[16]),0);
  }
  
  void set_d32m4(String name,Matrix4d mat){
    int loc=get_uniform_location(name);
    gl.glUniformMatrix4dv(loc,1,false,mat.get(new double[16]),0);
  }
  
  void set_b(String name,boolean b){
    int loc=get_uniform_location(name);
    gl.glUniform1i(loc,b?0b1:0b0);
  }
}

class Texture{
  IntBuffer id;
  int mip_count=1;
  
  Texture(){
    id=GLBuffers.newDirectIntBuffer(1);
    gl.glGenTextures(1,id);
  }
  
  Texture load(String path){
    bind();
    UImage i=loadUImage(path);
    gl.glTexImage2D(GL4.GL_TEXTURE_2D,0,GL4.GL_COMPRESSED_RGBA,i.w,i.h,0,GL4.GL_RGBA,GL4.GL_UNSIGNED_BYTE,ByteBuffer.wrap(i.src));
    gl.glGenerateMipmap(GL4.GL_TEXTURE_2D);
    set_wrapping(GL4.GL_REPEAT);
    set_filtering(GL4.GL_LINEAR);
    return this;
  }
  
  void load(){
    bind();
    gl.glTexImage2D(GL4.GL_TEXTURE_2D,0,GL4.GL_RGBA8,width,height,0,GL4.GL_RGBA,GL4.GL_UNSIGNED_BYTE,null);
  }
  
  void load(int format,int component,int type){
    bind();
    gl.glTexImage2D(GL4.GL_TEXTURE_2D,0,format,width,height,0,component,type,null);
  }
  
  Texture load(int w,int h,byte[] data){
    bind();
    gl.glTexImage2D(GL4.GL_TEXTURE_2D,0,GL4.GL_RGBA8,w,h,0,GL4.GL_RGBA,GL4.GL_UNSIGNED_BYTE,ByteBuffer.wrap(data));
    set_wrapping(GL4.GL_REPEAT);
    set_filtering(GL4.GL_LINEAR);
    return this;
  }
  
  Texture load(int w,int h,ByteBuffer data){
    //Buffer pbo=new Buffer(GL4.GL_PIXEL_UNPACK_BUFFER);
    //pbo.set_data(w*h*4,GL4.GL_STATIC_DRAW);
    //pbo.bind();
    //ByteBuffer mappedBuffer = gl.glMapBuffer(GL4.GL_PIXEL_UNPACK_BUFFER, GL4.GL_WRITE_ONLY);
    //if(mappedBuffer!=null){
    //  mappedBuffer.put(data);
    //  gl.glUnmapBuffer(GL4.GL_PIXEL_UNPACK_BUFFER);
    //}
    //pbo.unbind();
    bind();
    set_wrapping(GL4.GL_REPEAT);
    set_filtering(GL4.GL_LINEAR);
    gl.glTexImage2D(GL4.GL_TEXTURE_2D,0,GL4.GL_COMPRESSED_RGBA,w,h,0,GL4.GL_RGBA,GL4.GL_UNSIGNED_BYTE, data);
    //pbo.bind();
    //gl.glTexSubImage2D(GL4.GL_TEXTURE_2D,0,0,0,w,h,GL4.GL_RGBA,GL4.GL_UNSIGNED_BYTE,0);
    //pbo.unbind();
    unbind();
    return this;
  }
  
  void asDepth(){
    bind();
    gl.glTexImage2D(GL4.GL_TEXTURE_2D,0,GL4.GL_DEPTH_COMPONENT32F,width,height,0,GL4.GL_DEPTH_COMPONENT,GL4.GL_FLOAT,null);
    set_filtering(GL4.GL_NEAREST);
    set_wrapping(GL4.GL_CLAMP_TO_EDGE);
  }
  
  void asDepth(int w,int h){
    bind();
    gl.glTexImage2D(GL4.GL_TEXTURE_2D,0,GL4.GL_DEPTH_COMPONENT,w,h,0,GL4.GL_DEPTH_COMPONENT,GL4.GL_FLOAT,null);
  }
  
  void setMipCount(int width,int height){
    mip_count=1+floor(log(max(width,height))/log(2));
  }

  void set_wrapping(int mode) {
    bind();
    gl.glTexParameteri(GL4.GL_TEXTURE_2D, GL4.GL_TEXTURE_WRAP_S, mode);
    gl.glTexParameteri(GL4.GL_TEXTURE_2D, GL4.GL_TEXTURE_WRAP_T, mode);
  }

  void set_filtering(int mode) {
    bind();
    gl.glTexParameteri(GL4.GL_TEXTURE_2D, GL4.GL_TEXTURE_MIN_FILTER, mode);
    gl.glTexParameteri(GL4.GL_TEXTURE_2D, GL4.GL_TEXTURE_MAG_FILTER, mode);
  }
  
  void depth_setting(){
    gl.glTexParameteri(GL4.GL_TEXTURE_2D, GL4.GL_TEXTURE_COMPARE_MODE,GL4.GL_COMPARE_REF_TO_TEXTURE);
    gl.glTexParameteri(GL4.GL_TEXTURE_2D, GL4.GL_TEXTURE_COMPARE_FUNC, GL4.GL_LEQUAL);
  }
  
  void bind(){
    gl.glBindTexture(GL4.GL_TEXTURE_2D,id.get(0));
  }
  
  void unbind(){
    gl.glBindTexture(GL4.GL_TEXTURE_2D,0);
  }
  
  void activate(int unit){
    gl.glActiveTexture(unit);
    bind();
  }
  
  void destroyBuffer(){
    id=null;
  }
}

class FloatTexture extends Texture{
  
  Texture load(String path){
    bind();
    try{
      BufferedImage image=readHDR(new File(path));
      float[] data=((DataBufferFloat) image.getRaster().getDataBuffer()).getData();
      gl.glTexImage2D(GL4.GL_TEXTURE_2D,0,GL4.GL_RGB32F,image.getWidth(),image.getHeight(),0,GL4.GL_RGB,GL4.GL_FLOAT,FloatBuffer.wrap(data));
      set_filtering(GL4.GL_NEAREST);
    }catch(Exception e){
      e.printStackTrace();
    }
    return this;
  }
  
  void load(FloatBuffer fb,int width,int height){
    bind();
    gl.glTexImage2D(GL4.GL_TEXTURE_2D,0,GL4.GL_RGBA32F,width,height,0,GL4.GL_RGBA,GL4.GL_FLOAT,fb);
    set_filtering(GL4.GL_NEAREST);
  }
  
  void load_r(FloatBuffer fb,int width,int height){
    bind();
    gl.glTexImage2D(GL4.GL_TEXTURE_2D,0,GL4.GL_R32F,width,height,0,GL4.GL_RED,GL4.GL_FLOAT,fb);
    set_filtering(GL4.GL_NEAREST);
  }
  
  void load(){
    bind();
    gl.glTexImage2D(GL4.GL_TEXTURE_2D,0,GL4.GL_RGBA32F,width,height,0,GL4.GL_RGBA,GL4.GL_FLOAT,null);
    set_wrapping(GL4.GL_CLAMP_TO_EDGE);
    set_filtering(GL4.GL_NEAREST);
  }
}

class BindlessTexture extends Texture{
  long handle;
  
  BindlessTexture load(String path){
    bind();
    UImage i=loadUImage(path);
    gl.glTexImage2D(GL4.GL_TEXTURE_2D,0,GL4.GL_COMPRESSED_RGBA,i.w,i.h,0,GL4.GL_RGBA,GL4.GL_UNSIGNED_BYTE,ByteBuffer.wrap(i.src));
    gl.glGenerateMipmap(GL4.GL_TEXTURE_2D);
    set_wrapping(GL4.GL_REPEAT);
    set_filtering(GL4.GL_LINEAR);
    handle=gl.glGetTextureHandleARB(id.get(0));
    return this;
  }
  
  BindlessTexture load(int w,int h,ByteBuffer data){
    bind();
    set_wrapping(GL4.GL_REPEAT);
    set_filtering(GL4.GL_LINEAR);
    gl.glTexImage2D(GL4.GL_TEXTURE_2D,0,GL4.GL_COMPRESSED_RGBA,w,h,0,GL4.GL_RGBA,GL4.GL_UNSIGNED_BYTE, data);
    handle=gl.glGetTextureHandleARB(id.get(0));
    return this;
  }
  
  BindlessTexture load(int w,int h,byte[] data){
    bind();
    set_wrapping(GL4.GL_REPEAT);
    set_filtering(GL4.GL_LINEAR);
    gl.glTexImage2D(GL4.GL_TEXTURE_2D,0,GL4.GL_COMPRESSED_RGBA,w,h,0,GL4.GL_RGBA,GL4.GL_UNSIGNED_BYTE, ByteBuffer.wrap(data));
    handle=gl.glGetTextureHandleARB(id.get(0));
    return this;
  }
  
  void makeResident(){
    gl.glMakeTextureHandleResidentARB(handle);
  }
  
  void makeNonResident(){
    gl.glMakeTextureHandleNonResidentARB(handle);
  }
}

//class HDRTexture extends Texture{
//  float[] data;
//  int width;
//  int height;
  
//  void load(String path){
//    try{
//      BufferedImage bufferedImage=readHDR(new File(path));
//      data=((DataBufferFloat)bufferedImage.getRaster().getDataBuffer()).getData();
//      width=bufferedImage.getWidth();
//      height=bufferedImage.getHeight();
//      tasks.add(()->{
//        bind();
//        gl.glTexImage2D(GL4.GL_TEXTURE_2D,0,GL4.GL_RGB32F,bufferedImage.getWidth(),bufferedImage.getHeight(),0,GL4.GL_RGB,GL4.GL_FLOAT,FloatBuffer.wrap(data));
//        set_filtering(GL4.GL_NEAREST);
//        renderer.set_i32("background",0);
//      });
//    }catch(Exception e){
//      e.printStackTrace();
//    }
//  }
//}

class CubemapTexture extends Texture{
  
  Texture load(String path){
    bind();
    String[] name={"px.hdr","nx.hdr","py.hdr","ny.hdr","pz.hdr","nz.hdr"};
    for(int i=0;i<name.length;i++){
      try{
        BufferedImage image=readHDR(new File(path+name[i]));
        float[] data=((DataBufferFloat) image.getRaster().getDataBuffer()).getData();println(data.length,image.getWidth(),image.getHeight());
        setMipCount(image.getWidth(),image.getHeight());
        //tasks.add(()->{
        bind();
        gl.glTexImage2D(GL4.GL_TEXTURE_CUBE_MAP_POSITIVE_X+i,0,GL4.GL_RGB16F,image.getWidth(),image.getHeight(),0,GL4.GL_RGB,GL4.GL_FLOAT,FloatBuffer.wrap(data));
        //set_filtering(GL4.GL_NEAREST);
        //});
      }catch(Exception e){
        e.printStackTrace();
      }
    }
    gl.glGenerateTextureMipmap(id.get());
    set_filtering(GL4.GL_LINEAR_MIPMAP_LINEAR);
    set_wrapping(GL4.GL_CLAMP_TO_EDGE);
    return this;
  }
  
  CubemapTexture load(float r,float g,float b){
    String[] name={"px.hdr","nx.hdr","py.hdr","ny.hdr","pz.hdr","nz.hdr"};
    for(int i=0;i<name.length;i++){
      try{
        float[] data={r,g,b};
        setMipCount(1,1);
        //tasks.add(()->{
        bind();
        gl.glTexImage2D(GL4.GL_TEXTURE_CUBE_MAP_POSITIVE_X+i,0,GL4.GL_RGB16F,1,1,0,GL4.GL_RGB,GL4.GL_FLOAT,FloatBuffer.wrap(data));
        //set_filtering(GL4.GL_NEAREST);
        //});
      }catch(Exception e){
        e.printStackTrace();
      }
    }
    gl.glGenerateTextureMipmap(id.get());
    set_filtering(GL4.GL_LINEAR_MIPMAP_LINEAR);
    set_wrapping(GL4.GL_CLAMP_TO_EDGE);
    return this;
  }

  void set_wrapping(int mode) {
    bind();
    gl.glTexParameteri(GL4.GL_TEXTURE_CUBE_MAP, GL4.GL_TEXTURE_WRAP_S, mode);
    gl.glTexParameteri(GL4.GL_TEXTURE_CUBE_MAP, GL4.GL_TEXTURE_WRAP_T, mode);
    gl.glTexParameteri(GL4.GL_TEXTURE_CUBE_MAP, GL4.GL_TEXTURE_WRAP_R, mode);
  }

  void set_filtering(int mode) {
    bind();
    gl.glTexParameteri(GL4.GL_TEXTURE_CUBE_MAP, GL4.GL_TEXTURE_MIN_FILTER, mode);
    gl.glTexParameteri(GL4.GL_TEXTURE_CUBE_MAP, GL4.GL_TEXTURE_MAG_FILTER, mode);
  }
  
  void bind(){
    gl.glBindTexture(GL4.GL_TEXTURE_CUBE_MAP,id.get(0));
  }
}

class Transform{
  Vector3d transform;
  Vector3d scale;
  Quaterniond rotate;
  
  Transform(){
    transform=new Vector3d();
    scale=new Vector3d();
    rotate=new Quaterniond();
  }
  
  void setTransform(Vector3d d){
    transform.set(d);
  }
  
  void setTransform(double x,double y,double z){
    transform.set(x,y,z);
  }
  
  void transform(Vector3d d){
    transform.add(d);
  }
  
  void transform(double x,double y,double z){
    transform.add(x,y,z);
  }
  
  void setScale(Vector3d s){
    scale.set(s);
  }
  
  void setScale(double x,double y,double z){
    scale.set(x,y,z);
  }
  
  void scale(Vector3d s){
    scale.add(s);
  }
  
  void scale(double x,double y,double z){
    scale.add(x,y,z);
  }
  
  void setRotate(double angle,Vector3d axis){
    rotate.setAngleAxis(angle,axis);
  }
  
  void setRotate(double angle,double x,double y,double z){
    rotate.setAngleAxis(angle,x,y,z);
  }
  
  void rotate(double angle,Vector3d axis){
    rotate.rotateAxis(angle,axis);
  }
  
  void rotate(double angle,double ax,double ay,double az){
    rotate.rotateAxis(angle,ax,ay,az);
  }
}

class FilterProgram{
  ShaderProgram program;
  Buffer vertex_buffer;
  Buffer index_buffer;
  VertexArray vertex_array;
  
  float[] vertices={-1, -1,
                     1, -1,
                    -1,  1,
                     1,  1};
  int[] indices={0, 1, 3, 0, 3, 2};
  
  FilterProgram(String frag,String vert){
    Shader vertex_disp=new Shader(getProgram(vert), GL4.GL_VERTEX_SHADER);
    Shader fragment_disp=new Shader(getProgram(frag), GL4.GL_FRAGMENT_SHADER);
    program=new ShaderProgram(vertex_disp, fragment_disp);
    vertex_buffer=new Buffer(GL4.GL_ARRAY_BUFFER);
    vertex_buffer.set_data(FloatBuffer.wrap(vertices), GL4.GL_STATIC_DRAW);
    vertex_array=new VertexArray();
    vertex_array.bind();
    index_buffer=new Buffer(GL4.GL_ELEMENT_ARRAY_BUFFER);
    index_buffer.set_data(IntBuffer.wrap(indices), GL4.GL_STATIC_DRAW);
    vertex_array.set_attribute(program.get_attrib_location("position"), 2, 0, 0);
    vertex_array.unbind();
  }
}

ByteBuffer getRGB(BufferedImage img){
  int[] pixels = new int[img.getWidth() * img.getHeight()];
  img.getRGB(0, 0, img.getWidth(), img.getHeight(), pixels, 0, img.getWidth());

  ByteBuffer buffer = ByteBuffer.allocateDirect(img.getWidth() * img.getHeight() * 4);

  for(int y = 0; y < img.getHeight(); y++){
    for(int x = 0; x < img.getWidth(); x++){
      int pixel = pixels[y * img.getWidth() + x];
      buffer.put((byte) ((pixel >> 16) & 0xFF));
      buffer.put((byte) ((pixel >> 8) & 0xFF));
      buffer.put((byte) (pixel & 0xFF));
      buffer.put((byte) ((pixel >> 24) & 0xFF));
    }
  }

  buffer.flip();
  return buffer;
}

ByteBuffer toByteBuffer(BufferedImage image,String type) {
  type=type.replace("image/","");
  try{
    ByteArrayOutputStream bos = new ByteArrayOutputStream();
    BufferedOutputStream os = new BufferedOutputStream( bos );
    image.flush();
    ImageIO.write( image, type, os );
    return ByteBuffer.wrap(bos.toByteArray());
  }catch( Exception e ){
    e.printStackTrace();
  }
  return null;
}

UImage loadUImage(String path){
  PImage i=loadImage(path);
  byte[] out=new byte[i.pixels.length*4];
  for(int n=0;n<i.pixels.length;n++){
    int c=i.pixels[n]>>16&0xFF;
    out[n*4]=(byte)(c>127?c-256:c);
    c=i.pixels[n]>>8&0xFF;
    out[n*4+1]=(byte)(c>127?c-256:c);
    c=i.pixels[n]&0xFF;
    out[n*4+2]=(byte)(c>127?c-256:c);
    c=i.pixels[n]>>24&0xFF;
    out[n*4+3]=(byte)(c>127?c-256:c);
  }
  return new UImage(out,i.width,i.height);
}

BufferedImage readHDR(File hdr){
  //try{
  //  return HDREncoder.readHDR(hdr,true);
  //}catch(Exception e){
  //  e.printStackTrace();
  //}
  //return null;
  try{
    ImageInputStream input = ImageIO.createImageInputStream(new FileInputStream(hdr));
    
    try{
      // Get the reader
      Iterator<ImageReader> readers = ImageIO.getImageReaders(input);
  
      if(!readers.hasNext()) {
          throw new IllegalArgumentException("No reader for: " + hdr);
      }
  
      ImageReader reader = readers.next();
  
      try{
        reader.setInput(input);
  
        // Disable default tone mapping
        HDRImageReadParam param = (HDRImageReadParam) reader.getDefaultReadParam();
        param.setToneMapper(new NullToneMapper());
  
        // Read the image, using settings from param
        return reader.read(0, param);
      }catch(Exception e){
        e.printStackTrace();
      }finally {
        // Dispose reader in finally block to avoid memory leaks
        reader.dispose();
      }
    }
    finally {
      input.close();
    }
  }catch(IOException e){
    e.printStackTrace();
  }
  return null;
}



String getProgram(String path){
  String[]src=loadStrings(path);
  String out="";
  for(String s:src){
    out+=s+"\n";
  }
  return out;
}

Vector3f TupleToVector3(FloatTuple t){
  return new Vector3f(t.getX(),t.getY(),t.getZ());
}

Vector3f ListToVector3f(java.util.List<Double> l,Vector3f def){
  if(l==null){
    return def;
  }else{
    return new Vector3f((float)(double)l.get(0),(float)(double)l.get(1),(float)(double)l.get(2));
  }
}

class UImage{
  byte[] src;
  int w;
  int h;
  
  UImage(byte[] src,int w,int h){
    this.src=src;
    this.w=w;
    this.h=h;
  }
}
