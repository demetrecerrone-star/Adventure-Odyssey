#!/usr/bin/env python3
"""Non-destructively derive opaque underwear/base and independent starter-clothing layers.

Uses only Python's standard library. All images use original AO frame sizes,
poses and alpha; original art stays untouched and backed up before processing.
This is a prototype for visual review, not final approved worn armor art.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zlib

DIRECTIONS = ("down","left","up","right")
SIG = b"\x89PNG\r\n\x1a\n"

def read_png(path):
    content=path.read_bytes()
    if content[:8]!=SIG:
        raise ValueError(f"Not a PNG: {path}")
    offset=8; data=b""; width=height=0
    while offset<len(content):
        length=struct.unpack_from(">I",content,offset)[0]
        kind=content[offset+4:offset+8]
        block=content[offset+8:offset+8+length]
        if kind==b"IHDR":
            width,height,depth,color,compression,filt,interlace=struct.unpack(">IIBBBBB",block)
            if (depth,color,compression,filt,interlace)!=(8,6,0,0,0):
                raise ValueError(f"Expected 8-bit RGBA noninterlaced PNG: {path}")
        elif kind==b"IDAT":
            data+=block
        elif kind==b"IEND":
            break
        offset+=12+length
    raw=zlib.decompress(data)
    rows=[]; prev=bytearray(width*4); p=0; stride=width*4
    for y in range(height):
        filt=raw[p];p+=1
        row=bytearray(raw[p:p+stride]);p+=stride
        for i in range(stride):
            a=row[i-4] if i>=4 else 0
            b=prev[i]
            c=prev[i-4] if i>=4 else 0
            if filt==1:row[i]=(row[i]+a)&255
            elif filt==2:row[i]=(row[i]+b)&255
            elif filt==3:row[i]=(row[i]+((a+b)//2))&255
            elif filt==4:
                predictor=a+b-c
                da=abs(predictor-a);db=abs(predictor-b);dc=abs(predictor-c)
                row[i]=(row[i]+(a if da<=db and da<=dc else b if db<=dc else c))&255
            elif filt!=0:raise ValueError(f"PNG row filter {filt} unsupported: {path}")
        rows.append(row);prev=row
    if p!=len(raw):
        raise ValueError(f"PNG data length mismatch: {path}")
    return width,height,rows

def chunk(tag,data):
    return struct.pack(">I",len(data))+tag+data+struct.pack(">I",zlib.crc32(tag+data)&0xffffffff)

def write_png(path,width,height,rows):
    path.parent.mkdir(parents=True,exist_ok=True)
    raw=b"".join(b"\0"+bytes(row) for row in rows)
    encoded=SIG+chunk(b"IHDR",struct.pack(">IIBBBBB",width,height,8,6,0,0,0))
    encoded+=chunk(b"IDAT",zlib.compress(raw,9))+chunk(b"IEND",b"")
    path.write_bytes(encoded)

def split_original(original,width,height):
    skin=list(original[26][(width//2)*4:(width//2)*4+3])
    base=[bytearray(r) for r in original]
    clothes={k:[bytearray(width*4) for _ in range(height)] for k in ("shirt","pants","shoes")}
    cx=width/2.0
    for y in range(height):
        for x in range(width):
            i=x*4
            r,g,b,a=original[y][i:i+4]
            if a<20:
                continue
            updated=[r,g,b,a]
            layer=None
            if 59<=y<=86 and abs(x-cx)<width*0.42 and abs(r-g)<35 and abs(g-b)<45:
                # Practical, opaque gray-blue undershirt; leave skin and outlines.
                if r>75 and g>65:
                    k=0.78+0.34*((r+g+b)/765)
                    updated=[int(min(255,157*k)),int(min(255,160*k)),int(min(255,169*k)),a]
                    layer="shirt"
            elif 83<=y<=101 and abs(x-cx)<width*0.31 and abs(r-g)<30 and abs(g-b)<35:
                if r>40:
                    k=0.55+0.7*((r+g+b)/765)
                    updated=[int(77*k),int(82*k),int(97*k),a]
                    layer="pants"
            elif 100<=y<=124 and abs(x-cx)<width*0.45:
                if 50<r<225 and 20<g<185 and 8<b<160 and r>g*1.06 and g>=b*0.85:
                    k=0.68+((r+g+b)/765)*0.48
                    updated=[int(min(255,c*k)) for c in skin]+[a]
                    layer="shoes"
            if layer and updated!=[r,g,b,a]:
                base[y][i:i+4]=bytes(updated)
                # Separate starting clothing restores original silhouette/details.
                clothes[layer][y][i:i+4]=bytes([r,g,b,a])
    return base,clothes

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--source",default="assets/characters")
    p.add_argument("--output",default="assets/appearance")
    args=p.parse_args()
    src=Path(args.source);out=Path(args.output)
    manifest={"format":"AO appearance layers preview v1","frames":[]}
    count=0
    for variant in range(1,9):
        for facing in DIRECTIONS:
            for frame in range(3):
                rel=Path(f"base_variant_{variant:02d}/{facing}_{frame:02d}.png")
                path=src/rel
                w,h,original=read_png(path)
                if h!=128 or not 70<=w<=80:
                    raise ValueError(f"Unexpected AO frame dimensions: {path}: {w}x{h}")
                base,clothes=split_original(original,w,h)
                write_png(out/"base"/rel,w,h,base)
                for name,rows in clothes.items():
                    write_png(out/"starter"/name/rel,w,h,rows)
                manifest["frames"].append({"source":path.as_posix(),"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"width":w,"height":h})
                count+=1
    (out/"derived_manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
    print(f"AO UNDERWEAR/STARTER LAYERS GENERATED: PASS {count} frames x 4 aligned RGBA textures")

if __name__=="__main__":
    main()
