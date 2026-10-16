#!/usr/bin/env python3
"""First-pass original-art-derived wearable gear sprites for Adventure Odyssey.

Makes directional, frame-aligned preview layers from the approved 39 source
equipment icons and original 96 player body sprites. Does not replace originals
or modify saved items. Technical prototype; visual art approval required.
"""
from pathlib import Path
import base64
import json
import math
import re
import zlib
from generate_character_layers import read_rgba, write_rgba, separate_sprite, skin_reference
from generate_gear_art import SPRITES

FACES=("down","left","up","right")

def catalog():
    s=Path("scripts/game.gd").read_text(encoding="utf8")
    start=s.find("const ITEM_CATALOG={\n")
    end=s.find("\n}\n",start)
    if start<0 or end<0:raise RuntimeError("Item catalog not installed")
    return json.loads(s[start+len("const ITEM_CATALOG="):end+2])

def icon_record(item):
    slug=item.lower().replace("'","").replace(" ","_")
    if slug not in SPRITES:raise ValueError(f"No original item art: {item}")
    raw=SPRITES[slug]
    pal=raw["palette"]
    colors=[tuple(int(pal[i+j:i+j+2],16) for j in (0,2,4)) for i in range(0,len(pal),6)]
    packed=zlib.decompress(base64.b85decode(raw["data"]))
    if len(packed)!=512:raise ValueError(f"Bad original art pixel data for {item}")
    cells=[v for b in packed for v in (b>>4,b&15)]
    return slug,colors,cells

def main_color(colors,cells):
    swatches=[]
    for index in cells:
        if not index or index>=len(colors):continue
        color=colors[index]
        light=sum(color)/3
        saturation=max(color)-min(color)
        if light>52 and light<244:
            swatches.append(color)
    if not swatches:return (133,112,93)
    # Weighted image colors: original shape/palette remains the reference.
    return tuple(int(sum(c[k] for c in swatches)/len(swatches)) for k in range(3))

def set_pixel(dst,width,height,x,y,color,alpha=255):
    if 0<=x<width and 0<=y<height:
        i=(y*width+x)*4
        dst[i:i+4]=bytes((*[max(0,min(255,int(c))) for c in color],max(0,min(255,int(alpha)))))

def tint_layer(starter,main,width,height,kind):
    out=bytearray(len(starter))
    for i in range(0,len(starter),4):
        r,g,b,a=starter[i:i+4]
        if a<35:continue
        value=(r*0.24+g*0.65+b*0.11)/255
        if r<48 and g<48 and b<48:shade=0.30
        else:shade=0.47+value*0.72
        color=tuple(int(min(255,c*shade)) for c in main)
        if kind=="plate" and ((i//4)//width)%9 in (0,1):
            color=tuple(min(255,c+21) for c in color)
        out[i:i+4]=bytes((*color,a))
    return out

def draw_icon(dst,w,h,colors,cells,x0,y0,size):
    for dy in range(size):
        sy=min(31,dy*32//size)
        for dx in range(size):
            sx=min(31,dx*32//size)
            idx=cells[sy*32+sx]
            if 0<idx<len(colors):
                set_pixel(dst,w,h,x0+dx,y0+dy,colors[idx],255)

def cloak(dst,w,h,main,face):
    cx=w//2
    for y in range(57,min(125,h)):
        t=(y-57)/68
        radius=int(16+13*t)
        # Wide flowing panels are drawn behind the body in front/side views.
        for x in range(cx-radius,cx+radius+1):
            d=abs(x-cx)
            if d>radius:continue
            if (x+y)%16==0:shade=1.15
            else:shade=0.77 if d<radius-4 else 0.40
            color=tuple(min(255,int(c*shade)) for c in main)
            set_pixel(dst,w,h,x,y,color,247)

def hood(dst,w,h,main,face):
    cx=w//2
    for y in range(11,56):
        t=(y-30)/32.0
        radius=int(23*math.sqrt(max(0.0,1-t*t)))
        for x in range(cx-radius,cx+radius+1):
            edge=radius-abs(x-cx)
            if face!="up" and y>28 and edge>=7:
                continue # keep face uncovered
            shade=0.30 if edge<3 else 0.72 if (x+y)%9<5 else 0.92
            set_pixel(dst,w,h,x,y,tuple(int(c*shade) for c in main),245)

def gloves(dst,w,h,main,source):
    skin=skin_reference(source,w)
    for y in range(72,min(98,h)):
        for x in range(w):
            i=(y*w+x)*4
            r,g,b,a=source[i:i+4]
            if a<90 or abs(x-w/2)<w*0.25:continue
            if math.sqrt((r-skin[0])**2+(g-skin[1])**2+(b-skin[2])**2)>60:continue
            shade=0.62+(r+g+b)/1000
            set_pixel(dst,w,h,x,y,tuple(min(255,int(c*shade)) for c in main),a)

def worn_sprite(item,definition,w,h,source,colors,cells,face):
    base,starter=separate_sprite(w,h,source)
    result=bytearray(w*h*4)
    slot=str(definition["slot"])
    kind=str(definition.get("kind",""))
    main=main_color(colors,cells)
    if slot=="armor":
        result=tint_layer(starter[0],main,w,h,kind)
        if kind=="cloth" and ("Robe" in item):
            cx=w//2
            for y in range(87,107):
                radius=int(13+(y-87)*.3)
                for x in range(cx-radius,cx+radius):
                    shade=0.46 if x in (cx-radius,cx+radius-1) else 0.77
                    set_pixel(result,w,h,x,y,[c*shade for c in main],235)
    elif slot=="boots":
        result=tint_layer(starter[2],main,w,h,kind)
    elif slot=="gloves":
        gloves(result,w,h,main,source)
    elif slot=="head":
        hood(result,w,h,main,face)
    elif slot=="cloak":
        cloak(result,w,h,main,face)
    elif slot=="weapon":
        x=w//2+(4 if face in ("down","up") else -29 if face=="left" else 10)
        draw_icon(result,w,h,colors,cells,x,69,30)
    elif slot=="accessory":
        x=w//2-6 if face in ("down","up") else w//2+(0 if face=="left" else -12)
        draw_icon(result,w,h,colors,cells,x,64,11)
    return result

def make():
    items=catalog()
    out_root=Path("assets/worn_gear")
    manifest={"format":"AO worn gear first-pass preview v1","source":"original extracted icon pixels","items":{}}
    n=0
    for item,definition in items.items():
        slug,colors,cells=icon_record(item)
        main=main_color(colors,cells)
        for body in range(1,9):
            name=f"base_variant_{body:02d}"
            for face in FACES:
                for frame in range(3):
                    filename=f"{face}_{frame:02d}.png"
                    source=Path("assets/characters")/name/filename
                    w,h,rgba=read_rgba(source)
                    output=worn_sprite(item,definition,w,h,rgba,colors,cells,face)
                    write_rgba(out_root/slug/name/filename,w,h,output)
                    n+=1
        manifest["items"][item]={"slug":slug,"slot":definition["slot"],"derived_main_color":list(main)}
    out_root.mkdir(parents=True,exist_ok=True)
    (out_root/"worn_gear_manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf8")
    if n!=len(items)*96:raise RuntimeError("Unexpected worn gear frame count")
    print(f"AO WORN GEAR PREVIEW GENERATION: PASS / {len(items)} items x 96 frames = {n} aligned PNGs")
if __name__=="__main__":make()
