#!/usr/bin/env python3
"""AO sprite-layer prototype, deterministic and no third-party Python dependencies.

Reads the preserved 8*4*3 original RGBA8 character sprites and separates a
modest, always-opaque underwear base from three independently switchable
starting-clothes layers. This is a first-pass pixel reconstruction: manual art
polish is still needed before final outfit approval. Never modify originals.
"""
from pathlib import Path
import zlib, struct, statistics, math, hashlib, json

PNG_SIG=b'\x89PNG\r\n\x1a\n'
DIRECTIONS=('down','left','up','right')
BODY_VARIANTS=range(1,9)
ANIM_FRAMES=range(3)
LAYER_NAMES=('underwear_base','starter_top','starter_pants','starter_shoes')

def _chunk(name,data):
    return struct.pack('>I',len(data))+name+data+struct.pack('>I',zlib.crc32(name+data)&0xffffffff)

def read_rgba(path):
    binary=Path(path).read_bytes()
    if not binary.startswith(PNG_SIG):raise ValueError('Expected PNG: '+str(path))
    cursor=8; chunks=[]; width=height=0; color=None
    while cursor<len(binary):
        length=struct.unpack('>I',binary[cursor:cursor+4])[0]; name=binary[cursor+4:cursor+8]; payload=binary[cursor+8:cursor+8+length];cursor+=12+length
        if name==b'IHDR':
            width,height,depth,color,compression,filter_type,interlace=struct.unpack('>IIBBBBB',payload)
            if (depth,color,compression,filter_type,interlace)!=(8,6,0,0,0):raise ValueError(f'Expected 8-bit RGBA noninterlaced: {path}')
        elif name==b'IDAT':chunks.append(payload)
        elif name==b'IEND':break
    raw=zlib.decompress(b''.join(chunks));rows=[]; pos=0; stride=width*4
    for y in range(height):
        mode=raw[pos];pos+=1;scan=bytearray(raw[pos:pos+stride]);pos+=stride
        if mode not in (0,1,2,3,4):raise ValueError(f'PNG filter unsupported: {mode}')
        prev=rows[-1] if rows else bytes(stride)
        for k in range(stride):
            a=scan[k-4] if k>=4 else 0;b=prev[k];c=prev[k-4] if k>=4 else 0
            if mode==1:predictor=a
            elif mode==2:predictor=b
            elif mode==3:predictor=(a+b)//2
            elif mode==4:
                p=a+b-c;pa=abs(p-a);pb=abs(p-b);pc=abs(p-c)
                predictor=a if pa<=pb and pa<=pc else b if pb<=pc else c
            else:predictor=0
            scan[k]=(scan[k]+predictor)&255
        rows.append(scan)
    return width,height,bytearray().join(rows)

def write_rgba(path,width,height,rgba):
    dest=Path(path);dest.parent.mkdir(parents=True,exist_ok=True)
    stride=width*4;data=b''.join(b'\x00'+rgba[y*stride:(y+1)*stride] for y in range(height))
    ihdr=struct.pack('>IIBBBBB',width,height,8,6,0,0,0)
    dest.write_bytes(PNG_SIG+_chunk(b'IHDR',ihdr)+_chunk(b'IDAT',zlib.compress(data,9))+_chunk(b'IEND',b''))

def skin_reference(src,width):
    samples=[tuple(src[(y*width+x)*4:(y*width+x)*4+3]) for y in range(23,34) for x in range(width//2-10,width//2+11)
        if src[(y*width+x)*4+3]>=195 and min(src[(y*width+x)*4:(y*width+x)*4+3])>35]
    if not samples:raise ValueError('Cannot find head skin reference')
    return tuple(int(statistics.median(rgb[c] for rgb in samples)) for c in range(3))

def separate_sprite(width,height,src):
    base=bytearray(src); layers=[bytearray(len(src)) for _ in range(3)]
    skin=skin_reference(src,width);cx=width/2
    for y in range(55,height):
        for x in range(width):
            i=(y*width+x)*4;r,g,b,a=src[i:i+4]
            if a<90:continue
            distance=math.sqrt(sum((v-t)**2 for v,t in zip((r,g,b),skin)))
            if distance<43 or max(r,g,b)<80:continue
            if y<84:
                if max(r,g,b)<125 or (abs(r-g)>65 and abs(g-b)>55):continue
                layer=0;shade=0.80+0.11*(1-(y-55)/29)
                if 61<=y<=73 and abs(x-cx)<(18 if y<68 else 17):
                    color=(min(255,int(skin[0]*.65+62)),min(255,int(skin[1]*.63+72)),min(255,int(skin[2]*.63+81)))
                else:color=tuple(min(255,int(channel*shade)) for channel in skin)
            elif y<101:
                layer=1
                color=((68,76,86) if (x+y)%7<5 else (74,82,91)) if y<95 else tuple(int(c*.82) for c in skin)
            else:
                layer=2
                color=tuple(int(c*.78) for c in skin) if y<113 else (115,123,132)
            layers[layer][i:i+4]=src[i:i+4]
            base[i:i+3]=bytes(color)
    # Add close-fitting starter-trouser cuffs on the original uncovered shins.
    # These pixels are transparent when trousers are removed; the underwear
    # base retains the original skintone and keeps every character covered.
    for y in range(96,min(height,111)):
        for x in range(width):
            if abs(x-cx)>width*.28:continue
            i=(y*width+x)*4
            r,g,b,a=src[i:i+4]
            if a<120:continue
            if math.sqrt(sum((v-t)**2 for v,t in zip((r,g,b),skin)))>=49:continue
            shade=.81 if (x+y)%9<4 else .95
            layers[1][i:i+4]=bytes((int(72*shade),int(73*shade),int(80*shade),a))
    return base,layers

import math

def polish_underlayers(width, height, original, base, layers, facing):
    skin=skin_reference(original,width)
    # Work from original source bytes, not the first-pass recolor: this avoids
    # leaving seams and shirt lace details behind in underwear-only mode.
    base[:]=original
    for layer in layers:layer[:]=bytes(len(layer))
    cx=(width-1)/2.0
    shift=3.0 if facing=='left' else (-1.0 if facing=='right' else 0.0)
    torso_c=cx+shift
    def stamp(src_offset,y,x,group,rgb,alpha):
        layers[group][src_offset:src_offset+4]=original[src_offset:src_offset+4]
        base[src_offset:src_offset+4]=bytes((*rgb,alpha))
    for y in range(54,min(height,104)):
        for x in range(width):
            idx=(y*width+x)*4
            r,g,b,a=original[idx:idx+4]
            if a<32:continue
            d=abs(x-torso_c)
            distance=math.sqrt((r-skin[0])**2+(g-skin[1])**2+(b-skin[2])**2)
            # Keep hands and arms. In upper torso, preserve outer silhouette
            # outlines but replace the already-baked shirt and printed laces.
            if y<=85:
                region=27.0 if y<77 else 22.0
                if d>region or (y>=79 and d>20):continue
                if distance<42 and d>15:continue
                if max(r,g,b)<49 and d>19:continue
                vest_width=12 if y<=72 else 14
                vest = (y>=61 and y<=87 and d<=vest_width)
                if vest:
                    # Ordinary opaque slate undershirt, no anatomy exposed.
                    shade=1.0-(max(0,d-6)*.018)
                    rgb=tuple(int(v*shade) for v in (86,99,111))
                    if y in (62,63) and d<7:rgb=(128,142,149)
                    if y>=83:rgb=(67,79,93)
                else:
                    shade=1.0-(min(15,d)*.006)
                    rgb=tuple(max(15,min(255,int(v*shade))) for v in skin)
                stamp(idx,y,x,0,rgb,a)
            elif y<=101:
                if d>20:continue
                if distance<42 and y>96:continue
                shade=0.95 if d>15 else 1.00
                rgb=tuple(int(v*shade) for v in (65,76,89))
                if y in (86,87):rgb=(98,108,117)
                if d<1.25 and y>93:rgb=(45,55,67)
                stamp(idx,y,x,1,rgb,a)
    # Shoe pixels become fitted skin-tone feet. All original shoe pixels are
    # carried in the removable footwear layer even where base alpha is 0.
    for y in range(102,min(height,127)):
        for x in range(width):
            idx=(y*width+x)*4
            r,g,b,a=original[idx:idx+4]
            if a<20:continue
            layers[2][idx:idx+4]=original[idx:idx+4]
            if facing in ('left','right'):
                mid=cx+(-3 if facing=='left' else 3)
                active=abs(x-mid)<=(11 if y<117 else 13) and y<=123
            else:
                active=(abs(x-(cx-12))<=(7 if y<116 else 8) or abs(x-(cx+12))<=(7 if y<116 else 8)) and y<=123
            if not active:
                base[idx:idx+4]=b"\0\0\0\0"
                continue
            shade=.96 if y<115 else .89
            rgb=tuple(max(0,min(255,int(v*shade))) for v in skin)
            if y>=122:rgb=(54,51,49)
            base[idx:idx+4]=bytes((*rgb,a))
    return base,layers
def make(src_root='assets/characters',output_root='assets/character_layers'):
    src_root=Path(src_root);output_root=Path(output_root)
    count=0;manifest={'format':'ao_layered_sprites_v0_1','source':'original body sprites backed up separately, never overwritten','description':'Provisional base underwear and separately removable starter clothing; manual pixel polish needed','layers':list(LAYER_NAMES),'frames':{},'source_count':96}
    for body in BODY_VARIANTS:
        variant=f'base_variant_{body:02d}'
        for face in DIRECTIONS:
            for frame in ANIM_FRAMES:
                name=f'{face}_{frame:02d}.png';srcfile=src_root/variant/name
                w,h,src=read_rgba(srcfile)
                base,layers=polish_underlayers(w,h,src,*separate_sprite(w,h,src),face)
                dests=[output_root/layer/variant/name for layer in LAYER_NAMES]
                for dest,data in zip(dests,[base,*layers]):write_rgba(dest,w,h,data)
                manifest['frames'][f'{variant}/{name}']={'original_sha256':hashlib.sha256(srcfile.read_bytes()).hexdigest(),'size':[w,h],'outputs':[p.as_posix() for p in dests]}
                count+=1
    output_root.mkdir(parents=True,exist_ok=True)
    (output_root/'sprite_layers_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    if count!=96:raise RuntimeError('Expected precisely 96 original body frames')
    print('AO CHARACTER LAYERS GENERATED: PASS / 8 appearances x 4 directions x 3 frames x 4 layers = 384 PNGs')

if __name__=='__main__':make()