// Get all our imports out of the way
import heronarts.lx.*;
import heronarts.lx.audio.*;
import heronarts.lx.color.*;
import heronarts.lx.model.*;
import heronarts.lx.modulator.*;
import heronarts.lx.parameter.*;
import heronarts.lx.pattern.*;
import heronarts.lx.transition.*;
import heronarts.p2lx.*;
import heronarts.p2lx.ui.*;
import heronarts.p2lx.ui.control.*;
import ddf.minim.*;
import processing.opengl.*;
import java.awt.Dimension;
import java.awt.Toolkit;


//Pixelpusher imports
import com.heroicrobot.dropbit.registry.*;
import com.heroicrobot.dropbit.devices.pixelpusher.Pixel;
import com.heroicrobot.dropbit.devices.pixelpusher.Strip;
import com.heroicrobot.dropbit.devices.pixelpusher.PixelPusher;
import com.heroicrobot.dropbit.devices.pixelpusher.PusherCommand;

//Declare pixelpusher registry
DeviceRegistry registry;

//Pixelpusher helper class
class PixelPusherObserver implements Observer {
  public boolean hasStrips = false;
  public void update(Observable registry, Object updatedDevice) {
    println("Registry changed!");
    if (updatedDevice != null) {
      println("Device change: " + updatedDevice);
    }
    this.hasStrips = true;
  }
}



//PixelPusher observer
PixelPusherObserver ppObserver;

//set screen size
Dimension screenSize = Toolkit.getDefaultToolkit().getScreenSize();
final int VIEWPORT_WIDTH = 800; // for fullscreen, replace with (int)screenSize.getWidth();
final int VIEWPORT_HEIGHT = 600; //for fullscreen, replace with (int)screenSize.getHeight();

// Let's work in inches
final static int INCHES = 1;
final static int FEET = 12*INCHES;
float[] hsb = new float[3];

// Top-level, we have a model and a P2LX instance
Model model;
P2LX lx;

// Target frame rate
int FPS_TARGET = 60;  

// define Muse global
MuseConnect muse;
int MUSE_OSCPORT = 5000;

  // Always draw FPS meter
void drawFPS() {  
  fill(#999999);
  textSize(9);
  textAlign(LEFT, BASELINE);
  text("FPS: " + ((int) (frameRate*10)) / 10. + " / " + "60" + " (-/+)", 4, height-4);
}

/**
 * Set up models etc for whole package (Processing thing).
*/
void setup() {

  //set screen size
  size(VIEWPORT_WIDTH, VIEWPORT_HEIGHT, OPENGL);
  frame.setResizable(true);

  //not necessary, uncomment and play with it if the frame has issues
  //frame.setSize(VIEWPORT_WIDTH, VIEWPORT_HEIGHT);
  
  //framerates
  frameRate(FPS_TARGET);
  noSmooth();
  
  //Make a pixelpusher registry and observer
  registry = new DeviceRegistry();
  ppObserver = new PixelPusherObserver();
  registry.addObserver(ppObserver);
  
  //Muse headset
  muse = new MuseConnect(this, MUSE_OSCPORT);
  
  // Which version? This determines which subset of the bars to use
  // "Partial_Brain" = reduced version
  // "Full_Brain" = full brain version
  // "Module_14" = module 14
  // "Outer_Plus_algorithmic_inner" = current 400ish-bar selection
  String bar_selection = "Outer_Plus_algorithmic_inner";

  //Actually builds the model (per mappings.pde)
  model = buildTheBrain(bar_selection);
  println("Total # pixels in model: " + model.points.size());
  
  // Create the P2LX engine
  lx = new P2LX(this, model);
  lx.enableKeyboardTempo(); 
  LXEngine engine = lx.engine;
  
  lx.engine.framesPerSecond.setValue(FPS_TARGET);
  lx.engine.setThreaded(false);
  // Set the patterns
  engine.setPatterns(new LXPattern[] {
    new RandomBarFades(lx),
    new ShittyLightningStrikes(lx),
    new RainbowBarrelRoll(lx),
    new EQTesting(lx),
    new LayerDemoPattern(lx),
    new CircleBounce(lx),
    new CirclesBounce(lx),
    new SampleNodeTraversalWithFade(lx),
    new SampleNodeTraversal(lx),
    new TestHuePattern(lx),
    new TestXPattern(lx),
    new IteratorTestPattern(lx),
    new TestBarPattern(lx),
  });
  println("Initialized patterns");
  

  //adjust this if you want to play with the initial camera setting.
  /*
  lx.ui.addLayer(
    // Camera layer
    new UI3dContext(lx.ui)
      .setCenter(model.cx, model.cy, model.cz)
      .setRadius(290).addComponent(new UIBrainComponent())
  );
  */
  
  // Add UI elements
  lx.ui.addLayer(
    // A camera layer makes an OpenGL layer that we can easily 
    // pivot around with the mouse
    new UI3dContext(lx.ui) {
      protected void beforeDraw(UI ui, PGraphics pg) {
        // Let's add lighting and depth-testing to our 3-D simulation
        pointLight(0, 0, 40, model.cx, model.cy, -20*FEET);
        pointLight(0, 0, 50, model.cx, model.yMax + 10*FEET, model.cz);
        pointLight(0, 0, 20, model.cx, model.yMin - 10*FEET, model.cz);
        //hint(ENABLE_DEPTH_TEST);
      }
      protected void afterDraw(UI ui, PGraphics pg) {
        // Turn off the lights and kill depth testing before the 2D layers
        noLights();
        hint(DISABLE_DEPTH_TEST);
      } 
    }
  
    // Let's look at the center of our model
  //  .setCenter(5,5,5)
  
    // Let's position our eye some distance away
    .setRadius(40*FEET)
    
  //  // And look at it from a bit of an angle
   // .setTheta(PI/24)
  //  .setPhi(PI/24)
    
  //  .setRotateVelocity(12*PI)
    //.setRotateAcceleration(3*PI)
    
    // Let's add a point cloud of our animation points
    .addComponent(new UIBrainComponent())
    
    // And a custom UI object of our own
   // .addComponent(new UIWalls())
  );
  
  // A basic built-in 2-D control for a channel
  lx.ui.addLayer(new UIChannelControl(lx.ui, lx.engine.getChannel(0), 4, 4));
  lx.ui.addLayer(new UIEngineControl(lx.ui, 4, 326));
  lx.ui.addLayer(new UIComponentsDemo(lx.ui, width-144, 4));

  // output to controllers
 // buildOutputs();

  lx.engine.framesPerSecond.setValue(FPS_TARGET);
  lx.engine.setThreaded(false);
}


/**
 * Processing's draw loop.
*/
void draw() {
  // Wipe the frame...
  background(40);
  color[] sendColors = lx.getColors();  
  long gammaStart = System.nanoTime();
  // Gamma correction here. Apply a cubic to the brightness
  // for better representation of dynamic range
  
  drawFPS();
  
  if (ppObserver.hasStrips) {   
    registry.startPushing();
    registry.setExtraDelay(0);
    registry.setAutoThrottle(true);
    registry.setAntiLog(true);    
    int stripy = 0;
    List<Strip> strips = registry.getStrips();

    for (int i = 0; i < sendColors.length; ++i) {
      LXColor.RGBtoHSB(sendColors[i], hsb);
      float b = hsb[2];
      sendColors[i] = lx.hsb(360.*hsb[0], 100.*hsb[1], 100.*(b*b*b));
    }

  
    //pixelpusher code
    //Goes through the points in strips registered on the pixelpusher
    //and sends the colors from sendColors to the appropriate strip/LED index
    //We're going to have to make this much more robust if we use pixelPushers for the whole brain
    //But for now it works well, don't mess with it unless there's a good reason to.
    int numStrips = strips.size();
    if (numStrips == 0)
      return;
    int stripcounter=0;
    int striplength=0;
    int pixlcounter=0;
    color c;
    for (Strip strip : strips) {
      try{
        striplength=model.strip_lengths.get(stripcounter);
      }
      catch(Exception e){
         striplength=0;
      }
      stripcounter++;
      for (int stripx = 0; stripx < strip.getLength(); stripx++) { 
        
          if (stripx < striplength){
            c = sendColors[int(pixlcounter)];
          }
          else {
            //This else shouldn't have to be invoked, but it's here in case something in the hardware goes awry (we had to amputate a pixel etc). 
            //Better to have a pixel off than crash the whole thing.
            c = sendColors[0]; 
          }
            strip.setPixel(c, int(stripx));
           if (stripx < striplength){
            pixlcounter+=1;
           }
          }
    }
  }
  
  
  // ...and everything else is handled by P2LX!
}



/**
 * Creates a custom pattern class for writing patterns onto the brain model 
 * Don't modify unless you know what you're doing.
*/
public static abstract class BrainPattern extends LXPattern {
  protected Model model;
  
  protected BrainPattern(LX lx) {
    super(lx);
    this.model = (Model) lx.model;
  }
}
