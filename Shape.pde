import org.ode4j.ode.internal.DxCapsule;
import org.ode4j.ode.internal.DxSpace;

//class Box extends StaticMesh{
  
//  Box(Vector2f size){
//    super();
//  }
//}

class PlayerCapsule extends DxCapsule{
  DVector3 collide=new DVector3();
  
  PlayerCapsule(DxSpace space, double __radius, double __length){
    super(space,__radius,__length);
  }
}
