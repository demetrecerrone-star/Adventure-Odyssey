"""Reproducible texture-preserving cutout rigs; no frame duplication or crossfades.
Original imagegen atlases remain in assets/title. Each rendered frame has
independent IK targets, two alternating support/swing legs, and counter-swing arms.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance
import math, json
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/qa/title-cycle'; OUT.mkdir(parents=True,exist_ok=True)
N=24; COLS=6; SIZE=512; PERIOD=.8; SPEED=112; STANCE=.36

def cut(im,poly):
 mask=Image.new('L',im.size);ImageDraw.Draw(mask).polygon(poly,fill=255)
 out=Image.new('RGBA',im.size);out.paste(im,(0,0),mask);return out

def place(layer,a,b,da,db):
 # Inverse similarity transform keeps each texture bone rigid and connected.
 sx,sy=b[0]-a[0],b[1]-a[1];tx,ty=db[0]-da[0],db[1]-da[1]
 den=tx*tx+ty*ty
 u=(sx*tx+sy*ty)/den;v=(sy*tx-sx*ty)/den
 return layer.transform((512,512),Image.Transform.AFFINE,(u,-v,a[0]-u*da[0]+v*da[1],v,u,a[1]-v*da[0]-u*da[1]),Image.Resampling.BICUBIC)

def move(layer,dx,dy):
 return layer.transform((512,512),Image.Transform.AFFINE,(1,0,-dx,0,1,-dy),Image.Resampling.BICUBIC)

def ik(hip,foot,l1,l2):
 dx,dy=foot[0]-hip[0],foot[1]-hip[1];d=math.hypot(dx,dy)
 assert d < l1+l2, (d,l1+l2)
 along=(l1*l1-l2*l2+d*d)/(2*d);side=math.sqrt(max(0,l1*l1-along*along))
 return hip[0]+dx*along/d+dy*side/d, hip[1]+dy*along/d-dx*side/d

def smooth(t):return t*t*(3-2*t)

def rig(name):
 im=Image.open(ROOT/f'assets/title/{name}-run.png').convert('RGBA').crop((0,0,512,512))
 if name=='goblin':
  hip=(264,286);lens=(68,66);scale=.23;dy=0
  upper=cut(im,[(268,274),(302,274),(340,298),(333,321),(310,329),(275,309),(253,307)])
  lower=cut(im,[(311,295),(339,298),(371,320),(363,350),(340,342),(316,322)])
  boot=cut(im,[(360,307),(382,318),(410,299),(440,286),(449,320),(431,355),(403,387),(373,379),(338,350)])
  bones=[((275,290),(323,309)),((323,309),(361,332))];ankle=(361,332)
  body=cut(im,[(178,55),(376,55),(401,186),(368,211),(321,221),(325,250),(297,277),(278,293),(265,312),(247,316),(230,308),(213,292),(180,286),(161,279),(156,268),(199,242),(218,205),(198,183),(177,166)])
  arm_back=cut(im,[(224,160),(232,184),(209,192),(183,208),(174,236),(141,244),(124,222),(130,197),(180,165),(202,158)])
  arm_front=cut(im,[(307,202),(334,208),(346,224),(359,216),(363,187),(391,179),(415,198),(411,221),(376,248),(348,259),(320,247),(300,230)])
  shoulder_back=(216,177);shoulder_front=(318,220)
 else:
  hip=(262,256);lens=(74,80);scale=.27;dy=0
  upper=cut(im,[(253,243),(280,248),(341,267),(353,285),(341,304),(322,302),(304,285),(262,277),(248,264)])
  lower=cut(im,[(325,274),(346,274),(358,298),(376,325),(362,344),(343,331),(332,308),(322,292)])
  boot=cut(im,[(357,308),(386,305),(397,335),(416,349),(444,333),(467,335),(466,363),(429,397),(404,410),(383,391),(354,360),(340,340)])
  bones=[((263,259),(334,285)),((334,285),(365,331))];ankle=(365,331)
  body=cut(im,[(222,105),(283,61),(337,57),(366,80),(367,119),(344,160),(317,176),(310,205),(288,224),(280,243),(260,253),(245,280),(237,307),(222,322),(211,307),(223,278),(203,298),(180,293),(139,287),(139,261),(186,236),(217,217),(226,186),(212,165),(208,143)])
  arm_back=cut(im,[(221,126),(227,153),(202,162),(182,171),(167,196),(162,222),(139,237),(119,219),(123,196),(142,178),(163,145),(190,133)])
  arm_front=cut(im,[(303,160),(321,177),(330,190),(350,183),(357,170),(370,153),(405,104),(450,61),(470,55),(470,89),(422,154),(397,191),(384,211),(370,235),(349,246),(338,231),(350,215),(323,215),(309,204),(297,181)])
  shoulder_back=(219,145);shoulder_front=(309,178)
 # The original passing pose supplies a neutral shin/flat boot, avoiding a
 # rotated airborne boot's crouched posture. Shaft belongs to the shin.
 passing=Image.open(ROOT/f'assets/title/{name}-run.png').convert('RGBA').crop((512,0,1024,512))
 if name=='goblin':
  lower=cut(passing,[(218,323),(253,329),(249,351),(225,371),(215,397),(186,406),(161,395),(178,368),(195,345)])
  ankle=(194,393);bones[1]=((239,338),ankle)
  boot=cut(passing,[(175,384),(213,387),(221,400),(246,402),(264,416),(258,432),(157,432),(156,402)])
 else:
  lower=cut(passing,[(206,307),(228,313),(226,332),(210,353),(204,379),(203,401),(170,404),(160,389),(172,359),(190,338)])
  ankle=(185,393);bones[1]=((214,320),ankle)
  boot=cut(passing,[(166,386),(203,388),(211,401),(229,409),(234,429),(156,432),(153,408)])
 sole=boot.getbbox()[3]-ankle[1];ground_ankle=430-sole
 frames=[];measure=[];grip=[]
 for i in range(N):
  phase=i/N; bounce=-5*math.cos(4*math.pi*phase)
  h=(hip[0],hip[1]+dy+bounce)
  result=Image.new('RGBA',(512,512));legs=[]
  for leg in range(2):
   p=(phase+leg*.5)%1
   travel=SPEED*PERIOD*STANCE/scale
   if p<STANCE:
    t=p/STANCE;x=hip[0]+travel*(.5-t);y=ground_ankle;toe_angle=0
   else:
    t=(p-STANCE)/(1-STANCE);x=hip[0]+travel*(-.5+smooth(t));y=ground_ankle-38*math.sin(math.pi*t)**1.4
    toe_angle=-.65*math.sin(math.pi*t)
   foot=(x,y);knee=ik(h,foot,*lens)
   limb=Image.new('RGBA',(512,512))
   for layer,(a,b),dest in [(upper,bones[0],(h,knee)),(lower,bones[1],(knee,foot))]:
    limb.alpha_composite(place(layer,a,b,*dest))
   limb.alpha_composite(place(boot,ankle,(ankle[0]+40,ankle[1]),foot,(foot[0]+40*math.cos(toe_angle),foot[1]+40*math.sin(toe_angle))))
   if leg==0:
    alpha=limb.getchannel('A');limb=ImageEnhance.Brightness(limb).enhance(.81);limb.putalpha(alpha)
   legs.append(limb)
   measure.append(dict(frame=i,leg=leg,phase=round(p,5),stance=p<STANCE,hip=h,knee=knee,ankle=foot))
  # Back limbs, torso/skirt, then the near arm. Sword and hand are one rigid layer.
  result.alpha_composite(legs[0]);result.alpha_composite(legs[1])
  for layer,shoulder,angle in [(arm_back,shoulder_back,.35*math.sin(phase*math.tau)),(body,(0,0),None),(arm_front,shoulder_front,-.22*math.sin(phase*math.tau))]:
   if angle is None: result.alpha_composite(move(layer,0,dy+bounce))
   else:
    dest=(shoulder[0],shoulder[1]+dy+bounce)
    result.alpha_composite(place(layer,shoulder,(shoulder[0]+50,shoulder[1]),dest,(dest[0]+50*math.cos(angle),dest[1]+50*math.sin(angle))))
  frames.append(result)
  if name=='skeleton':
   angle=-.22*math.sin(phase*math.tau)
   def carried(point):
    dx,dy0=point[0]-shoulder_front[0],point[1]-shoulder_front[1]
    return [shoulder_front[0]+dx*math.cos(angle)-dy0*math.sin(angle),shoulder_front[1]+dy+bounce+dx*math.sin(angle)+dy0*math.cos(angle)]
   grip.append({'frame':i,'hand':carried((367,200)),'hilt':carried((374,190)),'tip':carried((460,67))})
 atlas=Image.new('RGBA',(COLS*512,4*512))
 for i,f in enumerate(frames):atlas.alpha_composite(f,((i%COLS)*512,(i//COLS)*512))
 atlas.save(ROOT/f'assets/title/{name}-run-smooth.png')
 sheet=Image.new('RGB',(6*256,4*278),(42,45,51));draw=ImageDraw.Draw(sheet)
 for i,f in enumerate(frames):
  x,y=(i%6)*256,(i//6)*278;sheet.paste(f.resize((256,256)),(x,y),f.resize((256,256)))
  draw.text((x+8,y+255),f'{i:02} phase {i/N:.3f}',fill='white')
 sheet.save(OUT/f'{name}-contact-sheet.jpg')
 json.dump(measure,open(OUT/f'{name}-kinematics.json','w'),indent=2)
 if grip: json.dump(grip,open(OUT/'skeleton-grip.json','w'),indent=2)
 return frames

if __name__=='__main__':
 s=rig('skeleton');g=rig('goblin');previews=[]
 for i in range(N):
  canvas=Image.new('RGB',(680,240),(48,53,61));d=ImageDraw.Draw(canvas);d.line((0,202,680,202),fill=(115,111,100),width=2)
  for frames,x,sz in [(s,60,230),(g,355,210)]:
   f=frames[i].resize((sz,sz),Image.Resampling.LANCZOS);canvas.paste(f,(x,202-round(430*sz/512)),f)
  previews.append(canvas)
 previews[0].save(OUT/'chase-cycle.gif',save_all=True,append_images=previews[1:],duration=[33,33,34]*8,loop=0)
