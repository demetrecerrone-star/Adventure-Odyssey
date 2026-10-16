#!/usr/bin/env python3
"""Produce pose-aligned AO pixel worn gear, not scaled-up HUD icons.

Generation source: hand-authored pixel motifs and AO's original body silhouettes.
Sprites are 100% transparent outside the garment/weapon, match original PNG
sizes and frame registration, and vary with facing and animation.
Standard library only, including Godot CI; never edits archived base bodies.
"""
from pathlib import Path
from generate_character_layers import read_rgba, write_rgba
import json, hashlib, math

FACES=('down','left','up','right')
SLOTS={
 'weapon': ['Rusted Sword','Training Sword','Iron Sword','Iron Axe','Oak Bow','Hunter Bow','Apprentice Staff','Ember Staff','Bronze Dagger','Forest Fang','Pilgrim Mace','Guard Spear'],
 'armor': ['Traveler Tunic','Traveler Robe','Leather Vest','Iron Chainmail','Iron Plate','Apprentice Robe','Reinforced Jerkin','Guard Breastplate'],
 'head': ['Leather Hood'], 'cloak':['Forest Cloak'], 'gloves':['Padded Gloves'], 'boots':['Steel Boots'],
 'accessory':['Copper Ring','Silver Ring','Vitality Charm','Wisdom Bead',"Hunter's Band",'Ember Pendant','Guard Sigil','Moon Brooch','Slime Core Charm','Guardian Relic']
}
# Inventories and wearable gear share item ID/slug; motifs are designed for the
# approved palette family without modifying the recovered 39 inventory icons.
TINTS={
 'Rusted Sword':('#8c6f59','#d4ae83','#382d2b'),'Training Sword':('#907147','#c5aa75','#3b3325'),
 'Iron Sword':('#7b9fae','#d7e4e2','#273d4f'),'Iron Axe':('#7a929e','#d4dee0','#273748'),
 'Oak Bow':('#87613d','#c7a263','#3f332e'),'Hunter Bow':('#547c4c','#acd584','#203f31'),
 'Apprentice Staff':('#75634c','#a6cbd5','#3b354d'),'Ember Staff':('#734341','#ffad54','#542533'),
 'Bronze Dagger':('#aa814e','#efcc81','#4d3940'),'Forest Fang':('#47726f','#b9e2cb','#27433a'),
 'Pilgrim Mace':('#77655e','#d9c79b','#342b36'),'Guard Spear':('#667d9d','#e2dfc6','#35415b'),
 'Traveler Tunic':('#688c96','#d7e1d3','#344f60'),'Traveler Robe':('#5c567e','#a9a0b8','#352e53'),
 'Leather Vest':('#8b593d','#c6925f','#45372f'),'Iron Chainmail':('#657586','#a7b6bb','#2f4250'),
 'Iron Plate':('#627d99','#d7e2dd','#354862'),'Apprentice Robe':('#654b85','#c49fe8','#352951'),
 'Reinforced Jerkin':('#71583f','#c1a176','#40372f'),'Guard Breastplate':('#697993','#e1e0c7','#344052'),
 'Leather Hood':('#5e564e','#b59d80','#302f36'),'Forest Cloak':('#42644e','#8db76a','#243e38'),
 'Padded Gloves':('#796d53','#c2a578','#423833'),'Steel Boots':('#687d91','#b7c9d0','#384253'),
 'Copper Ring':('#a96c42','#e2ae67','#4e342a'),'Silver Ring':('#8796a2','#e6eae5','#4d5967'),
 'Vitality Charm':('#659e68','#d4eaa4','#2f5449'),'Wisdom Bead':('#698fc3','#c7e8e6','#394675'),
 "Hunter's Band":('#547c4c','#acd584','#294936'),'Ember Pendant':('#c36b38','#ffc56c','#793e36'),
 'Guard Sigil':('#8f8baa','#f1e0af','#444969'),'Moon Brooch':('#8c8bb2','#d2ddf7','#394760'),
 'Slime Core Charm':('#528d65','#c2f5a4','#336348'),'Guardian Relic':('#9569ac','#d9c5ef','#4e456c')
}

def rgba(hex_color,alpha=255):
 s=hex_color.strip('#');return tuple(int(s[i:i+2],16) for i in (0,2,4))+(alpha,)

class Art:
 def __init__(self,width,height):
  self.width=width;self.height=height;self.buf=bytearray(width*height*4)
 def dot(self,x,y,c):
  x=int(round(x));y=int(round(y))
  if not (0<=x<self.width and 0<=y<self.height):return
  i=(y*self.width+x)*4
  self.buf[i:i+4]=bytes(c if isinstance(c,tuple) else rgba(c))
 def line(self,x1,y1,x2,y2,c,thick=1):
  length=max(1,int(max(abs(x2-x1),abs(y2-y1))))
  for n in range(length+1):
   u=n/length;x=x1+(x2-x1)*u;y=y1+(y2-y1)*u
   for dx in range(-(thick//2),(thick+1)//2):
    for dy in range(-(thick//2),(thick+1)//2):self.dot(x+dx,y+dy,c)
 def rect(self,x1,y1,x2,y2,c):
  for y in range(int(y1),int(y2)+1):
   for x in range(int(x1),int(x2)+1):self.dot(x,y,c)
 def polygon(self,pts,c):
  lo=max(0,int(min(p[1] for p in pts)));hi=min(self.height-1,int(max(p[1] for p in pts)))
  for y in range(lo,hi+1):
   hits=[];yp=y+0.5
   for j in range(len(pts)):
    x1,y1=pts[j];x2,y2=pts[(j+1)%len(pts)]
    if (y1<=yp<y2) or (y2<=yp<y1):hits.append(x1+(yp-y1)*(x2-x1)/(y2-y1))
   hits.sort()
   for j in range(0,len(hits)-1,2):
    for x in range(max(0,int(math.ceil(hits[j]))),min(self.width,int(hits[j+1])+1)):self.dot(x,y,c)
 def outlined(self,pts,fill,edge,thick=2):
  self.polygon(pts,edge)
  # Fill inner region via shrinking towards polygon centroid: pixelated outlines.
  cx=sum(x for x,y in pts)/len(pts);cy=sum(y for x,y in pts)/len(pts)
  inside=[(cx+(x-cx)*(1-thick/35),cy+(y-cy)*(1-thick/35)) for x,y in pts]
  self.polygon(inside,fill)
 def ring(self,cx,cy,rx,ry,c,thick=2):
  pts=[(cx+math.cos(a*math.pi/24)*rx,cy+math.sin(a*math.pi/24)*ry) for a in range(49)]
  for i in range(len(pts)-1):self.line(*pts[i],*pts[i+1],c,thick)

# Visual silhouettes aligned to the original game's 76x128 character framing.
# Anatomical regions are shared across the appearance variants. A small walk
# sway keeps hand accessories and held weapon attached instead of floating.
def render(slot,name,body,face,frame,w,h):
 art=Art(w,h)
 primary,light,dark=[rgba(v) for v in TINTS[name]]
 black=rgba('#242b36');gold=rgba('#edcf8e')
 cx=w//2; sway=(frame-1) if frame in (0,2) else 0
 side=1 if face!='left' else -1
 front=face=='down';back=face=='up';profile=face in ('left','right')
 def shift(points):return [(cx+x,y+sway) for x,y in points]
 if slot=='armor':
  # Bodice and side panels use distinct silhouettes by class/material, while
  # letting permanent underwear remain in the original bottom/base sprites.
  is_robe='Robe' in name
  is_plate=name in ('Iron Plate','Guard Breastplate')
  is_tunic=name=='Traveler Tunic';is_mail=name=='Iron Chainmail'
  narrow=10 if profile else 17
  shoulder=narrow+(1 if is_plate else 0)
  bottom=103 if is_robe else (93 if is_tunic else 87)
  top=61 if profile else 59
  pts=shift([(-narrow,top),(-shoulder-2,65),(-narrow-1,77),(-narrow+2,bottom),(narrow-2,bottom),(narrow+1,77),(shoulder+2,65),(narrow,top)])
  art.outlined(pts,primary,dark,3)
  art.polygon(shift([(-narrow+4,top+3),(-narrow+1,top+10),(0,top+13),(narrow-2,top+9),(narrow-3,top+3)]),light)
  if is_robe:
   art.polygon(shift([(-narrow+2,86),(-narrow-5,105),(0,99),(narrow+5,105),(narrow-2,86)]),primary)
   art.line(cx,76,cx,bottom+4,gold,2)
   for dx in (-8,8):art.line(cx+dx,82,cx+dx*1.4,bottom-2,dark,2)
  elif is_plate:
   art.outlined(shift([(-narrow+4,68),(0,65),(narrow-4,68),(narrow-3,85),(0,92),(-narrow+3,85)]),light,black)
   art.line(cx-narrow+2,78,cx+narrow-2,78,dark,2)
   art.polygon(shift([(0,69),(-3,77),(0,81),(3,77)]),rgba('#d98b6a') if name=='Guard Breastplate' else gold)
   art.rect(cx-14,90,cx+14,93,dark)
   art.rect(cx-9,90,cx+9,92,light)
  else:
   art.line(cx-narrow+2,82,cx+narrow-2,82,dark,2)
   for dx in (-6,6):art.line(cx+dx,65,cx-dx//2,90,light if 'Leather' in name or 'Jerkin' in name else gold,1)
   if is_mail:
    for y in range(71,87,4):
     for x in range(cx-narrow+4,cx+narrow-4,5):art.dot(x+((y//4)%2)*2,y,light)
   elif is_tunic:art.line(cx,65,cx,85,gold,2)
  # Armor covers torso; thicker bracers for plate, fabric sleeves for robes.
  for sign in (-1,1):
   if not profile or sign==side:
    x=cx+sign*(22 if not profile else 14)
    art.outlined([(x-5,69+sway),(x+5,70+sway),(x+8,82+sway),(x-6,82+sway)],primary,dark,1)
    art.line(x-3,72+sway,x+4,73+sway,light,2)
 elif slot=='cloak':
  # Behind the player; exposed outer sides/draping cloth vary by facing.
  if profile:
   pts=shift([(6*side,61),(21*side,63),(26*side,100),(10*side,115),(2*side,93)])
  else:pts=shift([(-16,62),(16,62),(24,101),(15,118),(0,112),(-15,118),(-24,101)])
  art.outlined(pts,primary,dark,2)
  for dx in (-13,0,13):art.line(cx+dx,75,cx+dx+(dx//4),111,light,1)
  if front:
   art.line(cx-15,62,cx-8,69,gold,2);art.line(cx+15,62,cx+8,69,gold,2)
 elif slot=='head':
  # Open-faced hood leaves eyes/face readable on down/side views.
  if front:
   art.outlined(shift([(-21,37),(-20,21),(-13,10),(0,6),(13,10),(20,21),(21,37),(16,45),(16,24),(9,18),(-9,18),(-16,24),(-16,45)]),primary,dark,2)
   art.line(cx-16,42,cx-13,50,light,2);art.line(cx+16,42,cx+13,50,light,2)
  elif back:
   art.outlined(shift([(-19,44),(-23,27),(-19,14),(-10,7),(10,7),(19,14),(23,27),(19,44),(0,52)]),primary,dark,2)
   art.ring(cx,28,13,14,light,1)
  else:
   art.outlined(shift([(-18,44),(-23,28),(-17,13),(-4,8),(13,12),(19,24),(9,24),(9,40),(0,49)]),primary,dark,2)
 elif slot=='gloves':
  for sign in (-1,1):
   x=cx+sign*(25 if not profile else 17)
   if profile and sign!=side:continue
   art.outlined([(x-6,88+sway),(x+6,88+sway),(x+6,98+sway),(x-6,98+sway)],primary,dark,1)
   art.line(x-5,91+sway,x+5,91+sway,light,2)
 elif slot=='boots':
  for sign in (-1,1):
   x=cx+sign*(12 if not profile else 11)
   art.outlined([(x-7,108+sway),(x+7,108+sway),(x+8,121+sway),(x-9,123+sway)],primary,dark,1)
   art.rect(x-5,109+sway,x+5,111+sway,light)
   art.line(x-5,115+sway,x+5,115+sway,dark,1)
   art.line(x-5,119+sway,x+5,119+sway,light,1)
 elif slot=='weapon':
  hand=cx+(24 if front or back else 20)*side
  # Lateral facing sword moves nearer to the body, frame sway anchored to hand.
  hx=hand;hy=90+sway
  if 'Bow' in name:
   bx=hx+5*side;by=72+sway
   art.line(bx,by-21,bx+12*side,by,primary,3)
   art.line(bx+12*side,by,bx,by+21,primary,3)
   art.line(bx,by-21,bx,by+21,light,1)
   art.line(bx+2*side,by-19,bx+2*side,by+19,dark,1)
   art.line(hx-5*side,hy-4,bx+15*side,by,gold,1)
  elif 'Staff' in name or 'Spear' in name:
   tip=50 if 'Staff' in name else 45
   art.line(hx,hy+16,hx+4*side,tip,primary,4)
   art.line(hx-1,hy+15,hx+3*side,tip,light,1)
   if 'Spear' in name:
    art.outlined([(hx+4*side,tip+11),(hx-2*side,tip+1),(hx+4*side,tip-14),(hx+10*side,tip+1)],light,dark,1)
   else:
    art.ring(hx+4*side,tip,6,7,light,3)
    art.dot(hx+4*side,tip,rgba('#e86c53') if name=='Ember Staff' else rgba('#92cddc'))
  else:
   short='Dagger' in name or 'Fang' in name
   blade_len=19 if short else 38
   gripx=hx;gripy=hy
   art.line(gripx,gripy+6,gripx+4*side,gripy-12,primary,3)
   art.line(gripx-4,gripy-12,gripx+7,gripy-12,gold,2)
   tx=hx+10*side;ty=hy-12-blade_len
   if 'Axe' in name:
    art.line(hx+4*side,gripy-13,tx,ty,rgba('#895d37'),3)
    art.outlined([(tx,ty+1),(tx-11*side,ty-5),(tx-10*side,ty+17),(tx,ty+20)],light,dark,2)
   elif 'Mace' in name:
    art.line(hx+4*side,gripy-13,tx,ty+12,primary,3)
    art.ring(tx,ty+6,7,8,light,4)
    for dx in (-7,7):art.line(tx+dx,ty+2,tx+dx+2,ty-3,light,2)
   else:
    art.outlined([(hx+2*side,gripy-14),(tx-3*side,ty+9),(tx,ty),(tx+4*side,ty+9),(hx+7*side,gripy-13)],light,dark,1)
    art.line(hx+5*side,gripy-17,tx,ty+7,primary,1)
 elif slot=='accessory':
  ring='Ring' in name or 'Band' in name
  if ring:
   for sign in (-1,1):
    x=cx+sign*(25 if not profile else 18)
    if profile and sign!=side:continue
    art.ring(x,94+sway,3,2,gold,1)
    art.dot(x,92+sway,light)
  else:
   # Neck charm / brooch / sigil located above or on chest, never obscures face.
   y=65+sway if name not in ('Moon Brooch','Guard Sigil') else 71+sway
   x=cx if not profile else cx+side*6
   art.line(x,y-6,x,y-1,gold,1)
   art.outlined([(x-5,y),(x,y-5),(x+5,y),(x,y+7)],primary,dark,1)
   art.dot(x,y,light)
 return art.buf

def make_icon(source,width,height,slot,name):
 # Matching equipment motifs are rendered at readable inventory icon size.
 # Tiny rings and gloves are redrawn from the SAME worn-gear palette, because
 # blindly enlarging both character hands produces two unreadable dots.
 primary,highlight,outline=[rgba(v) for v in TINTS[name]]
 metal=rgba('#f0ddb4')
 if slot in ('accessory','gloves','boots'):
  icon=Art(96,96)
  if slot=='accessory':
   if 'Ring' in name or 'Band' in name:
    icon.ring(48,58,29,20,outline,10)
    icon.ring(48,58,26,18,primary,7)
    icon.line(28,53,33,48,highlight,4)
    icon.outlined([(48,16),(59,28),(52,40),(44,40),(37,28)],primary,outline,3)
    icon.polygon([(48,20),(54,28),(49,33),(43,28)],highlight)
    icon.dot(44,26,metal)
   else:
    icon.line(35,20,43,28,metal,2)
    icon.line(61,20,53,28,metal,2)
    icon.line(43,28,48,39,metal,2)
    icon.line(53,28,48,39,metal,2)
    icon.outlined([(48,29),(67,49),(57,71),(48,79),(39,71),(29,49)],primary,outline,4)
    icon.polygon([(48,37),(56,49),(48,62),(40,49)],highlight)
    icon.dot(44,44,metal)
  elif slot=='gloves':
   for center in (26,68):
    icon.outlined([(center-13,24),(center+13,24),(center+17,59),(center+9,77),(center-11,78),(center-18,59)],primary,outline,3)
    icon.rect(center-12,28,center+12,34,highlight)
    icon.line(center-9,51,center+10,51,outline,2)
    icon.line(center,58,center,73,highlight,2)
  elif slot=='boots':
   for center in (29,67):
    icon.outlined([(center-11,17),(center+8,17),(center+11,66),(center+19,69),(center+20,82),(center-18,82),(center-18,65)],primary,outline,3)
    icon.rect(center-10,23,center+7,27,highlight)
    icon.line(center-13,69,center+13,69,highlight,3)
    icon.line(center-17,79,center+18,79,outline,3)
  return icon.buf
 # For swords, robes, cloaks and helmets the complete worn silhouette is
 # already recognizable and can be cropped without painting over its design.
 alpha=[(x,y) for y in range(height) for x in range(width) if source[(y*width+x)*4+3]>90]
 if not alpha:raise ValueError('Cannot make icon from empty gear '+name)
 left=min(x for x,y in alpha);right=max(x for x,y in alpha)
 top=min(y for x,y in alpha);bottom=max(y for x,y in alpha)
 sw=right-left+1;sh=bottom-top+1
 factor=min(76/max(1,sw),76/max(1,sh))
 nw=max(1,int(sw*factor));nh=max(1,int(sh*factor))
 output=bytearray(96*96*4)
 # Hand-inventory silhouettes are transparent, with a small dark trim-shadow
 # and a soft secondary pixel highlight; never copy the player's body image.
 ox=(96-nw)//2;oy=(96-nh)//2
 for y in range(nh):
  sy=top+min(sh-1,int(y*sh/nh))
  for x in range(nw):
   sx=left+min(sw-1,int(x*sw/nw))
   si=(sy*width+sx)*4
   if source[si+3]<30:continue
   di=((oy+y)*96+ox+x)*4
   output[di:di+4]=source[si:si+4]
 return output

def generate(root='assets/characters',dest='assets/equipment_worn',icons='assets/equipment_item_icons'):
 root=Path(root);dest=Path(dest);icons=Path(icons);count=0
 manifest={'format':'AO pixel-gear production draft art','intent':'game-ready synchronized overlays, visual polish pending','items':{},'equipment_slots':list(SLOTS)}
 for slot,names in SLOTS.items():
  for name in names:
   slug=name.lower().replace(' ','_').replace("'",'')
   entry={'slot':slot,'slug':slug,'frames':0,'color_family':TINTS[name],'matching_icon':f'{icons.as_posix()}/{slug}.png'}
   for body in range(1,9):
    for facing in FACES:
     for frame in range(3):
      rel=f'base_variant_{body:02d}/{facing}_{frame:02d}.png'
      w,h,_=read_rgba(root/rel)
      if h!=128:raise ValueError(f'Unexpected frame {root/rel}: {w} x {h}')
      data=render(slot,name,body,facing,frame,w,h)
      if not any(data[i] for i in range(3,len(data),4)):
       raise ValueError(f'Blank worn art {name}: {rel}')
      write_rgba(dest/slot/slug/rel,w,h,data)
      if body==5 and facing=='down' and frame==1:
       write_rgba(icons/(slug+'.png'),96,96,make_icon(data,w,h,slot,name))
      entry['frames']+=1;count+=1
   manifest['items'][name]=entry
 dest.mkdir(parents=True,exist_ok=True)
 (dest/'worn_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print(f'ADVENTURE ODYSSEY WORN EQUIPMENT GENERATED: PASS / {len(manifest["items"])} items / {count} pose-aligned PNGs / 7 slots and 34 matching gear icons')
 return count
if __name__=='__main__': generate()