import com.hamoid.*;
String HIGHLIGHT_FILE = "P:/YT/EWOW/ewow3b/highlights.csv";
String IMAGE_FILE = "P:/YT/EWOW/ewow3b/shot1.png";
String VIDEO_FILE_NAME = "EWOW_3b.mp4";

String START_STR = "0:00.00";
String END_STR = "2:00.00";
color LINE_COLOR = color(160,0,0,150); // color(0,110,0,160);
float THICKNESS = 7.5;
VideoExport videoExport;

int W_W = 1920;
int W_H = 1080;
int START;
int END;
int FPS = 30;
int SPM = 60;
int LEN;
float THICK = 10;
String[] data;
int[] timestamps;
float[][] coors;
float[][] cameras;
PImage img;
float min_zoom;

int time_to_frame(String s){
  int i = s.indexOf(":");
  int minutes = Integer.parseInt(s.substring(0,i));
  float seconds = Float.parseFloat(s.substring(i+1));
  return (int)((minutes*SPM+seconds)*FPS);
}
int frame_to_t(int frame, int[] timestamps){
  for(int i = 0; i < timestamps.length; i++){
    if(timestamps[i] >= frame){
      return max(0,i-1);
    }
  }
  return timestamps.length-1;
}
float frame_to_tsmooth(int frame, int[] timestamps){
  int TT = 22;
  float value_sum = 0;
  float weight_sum = 0;
  for(int f = -TT; f <= TT; f++){
    float weight = pow(0.5+0.5*cos((float)(f)/TT*PI),4.3);
    weight_sum += weight;
    value_sum += weight*frame_to_t(frame+f,timestamps);
  }
  return value_sum/weight_sum;
}
float cclip(float x){
  return min(max(x,0),1);
}
void drawRectUp(float x, float y, float w, float h, float thick, float factor){
  if(x < -1000){
    return;
  }
  pushMatrix();
  translate(x,y);
  noStroke();
  fill(LINE_COLOR);
  
  float thresh = (w+thick*2)/(w+thick*2+h);
  if(factor < thresh){
    float anim_w = (w+thick*2)*cclip(factor/thresh);
    rect(-thick, -thick, anim_w, thick);
    rect(w+thick-anim_w, h, anim_w, thick);
  }else{
    float anim_h = h*cclip((factor-thresh)/(1-thresh));
    rect(-thick, -thick, w+thick*2, thick);
    rect(w, 0, thick, anim_h);
    rect(-thick, h, w+thick*2, thick);
    rect(-thick, h-anim_h, thick, anim_h);
  }
  popMatrix();
}
void drawRectDown(float x, float y, float w, float h, float thick, float factor){
  if(x < -1000){
    return;
  }
  pushMatrix();
  translate(x,y);
  noStroke();
  fill(LINE_COLOR);
  
  float thresh = (w+thick*2)/(w+thick*2+h);
  if(factor < thresh){
    float anim_w = (w+thick*2)*cclip(1-factor/thresh);
    rect(w+thick-anim_w, -thick, anim_w, thick);
    rect(-thick, h, anim_w, thick);
    rect(w, 0, thick, h);
    rect(-thick, 0, thick, h);
  }else{
    float anim_h = h*cclip(1-(factor-thresh)/(1-thresh));
    rect(w, h-anim_h, thick, anim_h);
    rect(-thick, 0, thick, anim_h);
  }
  popMatrix();
  
}
void drawHighlights(float tsmooth){
  
  int t1 = (int)tsmooth;
  int t2 = t1+1;
  float t_rem = tsmooth%1.0;
  
  float[] c1 = coors[t1];
  float[] c2 = coors[t2];
  float zoom = lerp(cameras[t1][2],cameras[t2][2],t_rem);
  float trueThick = max(THICK, THICKNESS/zoom);
  if(cameras[t1][3] == 1){
    for(int c = 0; c < 12; c+=4){
      drawRectDown(c1[c+0],c1[c+1],c1[c+2]-c1[c+0],c1[c+3]-c1[c+1],trueThick,t_rem);
    }
  }
  if(cameras[t2][3] == 1){
    for(int c = 0; c < 12; c+=4){
      drawRectUp(c2[c+0],c2[c+1],c2[c+2]-c2[c+0],c2[c+3]-c2[c+1],trueThick,t_rem);
    }
  }
}

float true_scale(float w, float h, boolean haveMargin, boolean multiple){
  float v = max(w/W_W, 0.65*h/W_H);
  float margin = (multiple ? 0.8 : 0.6);  // 0.45
  float basis = (haveMargin ? margin : 1.0);
  return min(basis/v,2.02);
}

float caryclip(float x, float _min, float _max){
  if(_min >= _max){
    return (_min+_max)/2;
  }
  return min(max(x, _min), _max);
}

float getZoomExtra(int frame, int t){
  if(cameras[t][2] == min_zoom){
    return 1;
  }
  float zoom;
  if(t%2 == 0){
    float result = ((float)frame-timestamps[t])/FPS;
    zoom = pow(1.03,result);
  }else{
    float result = ((float)timestamps[t+1]-frame)/FPS;
    zoom = pow(1.03,result);
  }
  return zoom;
}

void moveCameras(float tsmooth){
  int t1 = (int)tsmooth;
  int t2 = t1+1;
  float t_rem = tsmooth%1.0;
  float[] c1 = cameras[t1];
  float[] c2 = cameras[t2];
  float cx = lerp(c1[0],c2[0],t_rem);
  float cy = lerp(c1[1],c2[1],t_rem);
  
  float startZoom = 1/c1[2]*getZoomExtra(frame,t1);
  float endZoom = 1/c2[2]*getZoomExtra(frame,t2);
  float cs = 1/lerp(startZoom,endZoom,t_rem);

  translate(W_W/2,W_H/2);
  scale(cs);
  translate(-cx,-cy);
}

float[] getExtremes(float[] coor){
  float[] result = {9999.0,9999.0,-9999.0,-9999.0};
  for(int c = 0; c < 12; c++){
    if(coor[c] >= -1000){
      int i = c%4;
      if(i < 2){
        if(coor[c] < result[i]){
          result[i] = coor[c];
        }
      }else{
        if(coor[c] > result[i]){
          result[i] = coor[c];
        }
      }
    }
  }
  return result;
}


void setup(){
  START = time_to_frame(START_STR);
  END = time_to_frame(END_STR);
  frame = START;
  
  img = loadImage(IMAGE_FILE);
  size(1920,1080);
  data = loadStrings(HIGHLIGHT_FILE);
  LEN = data.length;
  timestamps = new int[LEN];
  coors = new float[LEN][12];
  cameras = new float[LEN][4];
  min_zoom = true_scale(img.width, img.height,false,false);
  for(int t = 0; t < LEN; t++){
    String[] parts = data[t].split(",");
    timestamps[t] = time_to_frame(parts[0]);
    for(int c = 0; c < 12; c++){
      coors[t][c] = -9999;
    }
    if(parts.length >= 4){
      int max_c = (parts.length/4)*4;
      for(int c = 0; c < max_c; c++){
        coors[t][c] = Integer.parseInt(parts[c+1]);
      }
      float[] extremes = getExtremes(coors[t]);
      cameras[t][2] = max(min_zoom,true_scale(extremes[2]-extremes[0], extremes[3]-extremes[1],true,(parts.length >= 8)));
      float y_give = W_H/2/cameras[t][2];
      float margin_more = 200;
      float minY = -margin_more+y_give;
      float maxY = img.height+margin_more-y_give;
      cameras[t][0] = (extremes[0]+extremes[2])/2;
      cameras[t][1] = (extremes[1]+extremes[3])/2;  // caryclip((coors[t][1]+coors[t][3])/2,minY,maxY);
    }
    if(parts.length <= 4 || (parts.length%4 == 2 && parts[parts.length-1].equals("out"))){
      cameras[t][0] = img.width/2;
      cameras[t][1] = img.height/2;
      cameras[t][2] = min_zoom;
    }
    cameras[t][3] = 1;
    if(parts.length == 6 && parts[5].equals("none")){
      cameras[t][3] = 0;
    }
  }
  videoExport = new VideoExport(this, VIDEO_FILE_NAME);
  //videoExport.forgetFfmpegPath();
  videoExport.startMovie();
}
int frame = START;
void draw(){
  float tsmooth = frame_to_tsmooth(frame, timestamps);
  background(255);
  pushMatrix();
  moveCameras(tsmooth);
  image(img,0,0);
  drawHighlights(tsmooth);
  popMatrix();
  
  videoExport.saveFrame();
  frame++;
  if(frame >= END){
    videoExport.endMovie();
  }
}
