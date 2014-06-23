import SimpleOpenNI.*;
import de.bezier.data.sql.*;

SimpleOpenNI  context;
color[]       userClr = new color[]{ color(255,0,0),
                                     color(0,255,0),
                                     color(0,0,255),
                                     color(255,255,0),
                                     color(255,0,255),
                                     color(0,255,255)
                                   };
PVector com = new PVector();                                   
PVector com2d = new PVector();     

int[] timers;    // timers associated to each user id
int[] timeLost;  // time at which the user was lost. -1 is the undefined state meaning that the counter is not running
int timeOut = 200;  // time, in ms, after which the user is considered lost
boolean[] activeUser;  // used to tell whether a user is active or waiting to be disabled
float[] averageDistance;  // array of the average distance at which the user was observed

MySQL ms;    // database
String database = "placette_data";
String user = "admin_placette";
String pass = "Placette2014";

String dbCommand;

void setup()
{
  size(640,480);
  
  // connect to the database
  ms = new MySQL(this, "80.74.148.106", database, user, pass);
  
  if(ms.connect()) {
     println("database connection successful"); 
  } else {
     println("failed to connect to the database");
     exit();
     return; 
  }
  
  // initialize simpleopenni
  context = new SimpleOpenNI(this);
  if(context.isInit() == false)
  {
     println("Can't init SimpleOpenNI, maybe the camera is not connected!"); 
     exit();
     return;  
  }
  
  // enable depthMap generation 
  context.enableDepth();
   
  // enable skeleton generation for all joints
  context.enableUser();
 
  background(200,0,0);

  stroke(0,0,255);
  strokeWeight(3);
  smooth();  
  
  timers = new int[10];
  activeUser = new boolean[10];
  timeLost = new int[10];
  averageDistance = new float[10];
  
  for (int i=0;i<10;i++) {
    timers[i]=0;
    activeUser[i]=false;
    timeLost[i]=-1;
    averageDistance[i]=0;
  }
}

void draw()
{
  // update the cam
  context.update();
  
  // draw depthImageMap
  //image(context.depthImage(),0,0);
  image(context.userImage(),0,0);
  
  // draw the skeleton if it's available
  int[] userList = context.getUsers();
  for(int i=0;i<userList.length;i++)
  {     if(context.isTrackingSkeleton(userList[i]))
    {
      stroke(userClr[ (userList[i] - 1) % userClr.length ] );
      drawSkeleton(userList[i]);
    }  
    // draw the center of mass
    if(context.getCoM(userList[i],com))
    {
      
      context.convertRealWorldToProjective(com,com2d);
      if(!Float.isNaN(com2d.x))
        println("com : " + com + ", com2d : " + com2d);
      stroke(100,255,0);
      strokeWeight(1);
      beginShape(LINES);
        vertex(com2d.x,com2d.y - 15);
        vertex(com2d.x,com2d.y + 15);

        vertex(com2d.x - 15,com2d.y);
        vertex(com2d.x + 15,com2d.y);
      endShape();
      
      fill(0,255,100);
      text(Integer.toString(userList[i]),com2d.x,com2d.y);
      
      if(Float.isNaN(com2d.x) || Float.isNaN(com2d.y)) {    // the CoM is NaN, meaning the user was lost
        if(activeUser[i]==true) { // the user has just been lost: start timer
          timeLost[i]=millis();
          activeUser[i] = false;
        } else {  // the user was already lost: check timer
          if(millis()-timeLost[i]>timeOut && timeLost[i] != -1) { // we should remove the user
            println("User: " + i + " was lost after " + (millis()-timers[i])/1000 + " seconds");
            dbCommand = "INSERT INTO `passers`(`timespent`,`distance`) VALUES (" + (float)(millis()-timers[i])/1000 + ", -1)"; 
            println(dbCommand);
            ms.execute(dbCommand);
            timeLost[i] = -1;
            averageDistance[i]=0;
          }
        }
      } else {
        if(activeUser[i]==false) { // a previously nonexistant or disabled user is reactivated
          println("acquired user " + i);
          timers[i] = millis();
          activeUser[i] = true;
        }
      }
    }
  }    
  
}

// draw the skeleton with the selected joints
void drawSkeleton(int userId)
{
  // to get the 3d joint data
  /*
  PVector jointPos = new PVector();
  context.getJointPositionSkeleton(userId,SimpleOpenNI.SKEL_NECK,jointPos);
  println(jointPos);
  */
  
  context.drawLimb(userId, SimpleOpenNI.SKEL_HEAD, SimpleOpenNI.SKEL_NECK);

  context.drawLimb(userId, SimpleOpenNI.SKEL_NECK, SimpleOpenNI.SKEL_LEFT_SHOULDER);
  context.drawLimb(userId, SimpleOpenNI.SKEL_LEFT_SHOULDER, SimpleOpenNI.SKEL_LEFT_ELBOW);
  context.drawLimb(userId, SimpleOpenNI.SKEL_LEFT_ELBOW, SimpleOpenNI.SKEL_LEFT_HAND);

  context.drawLimb(userId, SimpleOpenNI.SKEL_NECK, SimpleOpenNI.SKEL_RIGHT_SHOULDER);
  context.drawLimb(userId, SimpleOpenNI.SKEL_RIGHT_SHOULDER, SimpleOpenNI.SKEL_RIGHT_ELBOW);
  context.drawLimb(userId, SimpleOpenNI.SKEL_RIGHT_ELBOW, SimpleOpenNI.SKEL_RIGHT_HAND);

  context.drawLimb(userId, SimpleOpenNI.SKEL_LEFT_SHOULDER, SimpleOpenNI.SKEL_TORSO);
  context.drawLimb(userId, SimpleOpenNI.SKEL_RIGHT_SHOULDER, SimpleOpenNI.SKEL_TORSO);

  context.drawLimb(userId, SimpleOpenNI.SKEL_TORSO, SimpleOpenNI.SKEL_LEFT_HIP);
  context.drawLimb(userId, SimpleOpenNI.SKEL_LEFT_HIP, SimpleOpenNI.SKEL_LEFT_KNEE);
  context.drawLimb(userId, SimpleOpenNI.SKEL_LEFT_KNEE, SimpleOpenNI.SKEL_LEFT_FOOT);

  context.drawLimb(userId, SimpleOpenNI.SKEL_TORSO, SimpleOpenNI.SKEL_RIGHT_HIP);
  context.drawLimb(userId, SimpleOpenNI.SKEL_RIGHT_HIP, SimpleOpenNI.SKEL_RIGHT_KNEE);
  context.drawLimb(userId, SimpleOpenNI.SKEL_RIGHT_KNEE, SimpleOpenNI.SKEL_RIGHT_FOOT);  
}

// -----------------------------------------------------------------
// SimpleOpenNI events

void onNewUser(SimpleOpenNI curContext, int userId)
{
  println("New user: " + userId);
  timers[userId] = millis();
}

void onLostUser(SimpleOpenNI curContext, int userId)
{
  println("Lost user: " + userId + " after " + (millis()-timers[userId])/1000 + " seconds");
  //sm.storeData((float)(millis()-timers[userId])/1000);
}

void onVisibleUser(SimpleOpenNI curContext, int userId)
{
  //println("onVisibleUser - userId: " + userId);
}


void keyPressed()
{
  switch(key)
  {
  case ' ':
    context.setMirror(!context.mirror());
    break;
  }
}  

