#!/usr/bin/env python3
"""Guardian Legacy class-themed pixel weapons for AO's exact 77x128 poses.

Uses the same Art and PNG helpers as existing worn equipment. Every frame
remains a transparent, body-aligned weapon-only overlay; it never overwrites
base characters or hair. Generates each body's 4x3 sprite sheet and a 96px
inventory icon. No Pillow requirement in GitHub Actions.
"""
from pathlib import Path
import json
from generate_character_layers import read_rgba, write_rgba
from generate_worn_equipment_art import Art, rgba, make_icon, TINTS

WEAPONS = {
    "Warrior":("Oldstone Oathblade","sword","#737e8f","#8df0ff","#273343"),
    "Ranger":("Oldstone Starbow","bow","#89704d","#8de5ff","#342b34"),
    "Mage":("Oldstone Astral Staff","staff","#947a55","#a5f0ff","#312942"),
    "Necromancer":("Oldstone Soulreaper","scythe","#77749b","#c6a0ff","#302342"),
    "Assassin":("Oldstone Twin Fangs","dagger","#546c81","#60e4e3","#243245"),
    "Paladin":("Oldstone Dawnlance","spear","#c9a767","#fff0aa","#564029"),
}
FACES=("down","left","up","right")
GOLD=rgba("#e7b75a")
OUTLINE=rgba("#1f283d")
STONE=rgba("#465a70")

def weapon_pixels(klass,face,frame,width=77,height=128):
    name,kind,base_hex,gem_hex,edge_hex=WEAPONS[klass]
    base,gem,edge=rgba(base_hex),rgba(gem_hex),rgba(edge_hex)
    art=Art(width,height)
    center=width//2
    sign=-1 if face=="left" else 1
    offset=frame-1 if frame in (0,2) else 0
    hand=center+sign*(16 if face in ("left","right") else 21)
    y=94+offset
    def ln(x1,y1,x2,y2,col=base,thick=2):
        art.line(x1,y1,x2,y2,col,thick)
    def poly(points,fill,stroke=edge):
        art.outlined(points,fill,stroke,2)
    def gem_diamond(x,gy,rx=5,ry=8,col=gem):
        poly([(x,gy-ry),(x+rx,gy),(x,gy+ry),(x-rx,gy)],col,edge)
        ln(x,gy-ry+2,x,gy+ry-2,rgba("#ecfaff"),1)
    def grip(x,top,bottom):
        ln(x,top,x,bottom,OUTLINE,6)
        ln(x,top+2,x,bottom-2,base,4)
        for h in range(top+4,bottom,7):
            ln(x-2,h,x+2,h+3,GOLD,1)
    if klass=="Warrior":
        blade_x=hand+sign*1
        grip(blade_x,76+offset,109+offset)
        poly([(blade_x-7,65+offset),(blade_x-8,38+offset),
              (blade_x,22+offset),(blade_x+8,38+offset),(blade_x+7,65+offset),
              (blade_x,78+offset)],STONE)
        gem_diamond(blade_x,53+offset,4,18)
        ln(blade_x-13,78+offset,blade_x+13,78+offset,GOLD,5)
        gem_diamond(blade_x,78+offset,4,6)
        gem_diamond(blade_x,111+offset,4,5)
    elif klass=="Ranger":
        x=hand+sign*1
        # Angular recurve bow with glowing blue string and golden nocks.
        for a,b,c,d in [(-5,39,7,54),(7,54,10,69),(10,69,7,87),(7,87,-5,104)]:
            ln(x+sign*a,b+offset,x+sign*c,d+offset,OUTLINE,7)
            ln(x+sign*a,b+offset,x+sign*c,d+offset,base,4)
        ln(x-sign*5,39+offset,x-sign*5,104+offset,gem,1)
        ln(x-sign*10,39+offset,x-sign*1,46+offset,GOLD,2)
        ln(x-sign*10,104+offset,x-sign*1,98+offset,GOLD,2)
        gem_diamond(x+sign*9,69+offset,4,7)
        ln(x-sign*4,72+offset,x+sign*17,61+offset,GOLD,2)
        poly([(x+sign*17,60+offset),(x+sign*12,57+offset),(x+sign*14,64+offset)],gem)
    elif klass=="Mage":
        x=hand
        grip(x,56+offset,113+offset)
        ln(x,47+offset,x,60+offset,GOLD,5)
        poly([(x-9,42+offset),(x,15+offset),(x+9,42+offset),(x,57+offset)],gem)
        gem_diamond(x,36+offset,6,16)
        for dx in (-16,16):
            ln(x,52+offset,x+dx,34+offset,GOLD,3)
            gem_diamond(x+dx,32+offset,3,4)
        gem_diamond(x,111+offset,3,5)
    elif klass=="Necromancer":
        x=hand
        grip(x,46+offset,112+offset)
        # Raised crescent scythe: bone-and-stone edge, lilac soul-glow.
        poly([(x+sign*5,47+offset),(x-sign*4,34+offset),(x+sign*3,17+offset),
              (x+sign*21,13+offset),(x+sign*14,23+offset),
              (x+sign*3,31+offset),(x+sign*13,46+offset)],STONE)
        ln(x+sign*4,20+offset,x+sign*17,17+offset,gem,3)
        gem_diamond(x,48+offset,5,8)
        for dx,dy in [(12,29),(19,40),(-10,53)]:
            art.dot(x+sign*dx,dy+offset,gem)
        gem_diamond(x,111+offset,3,5)
    elif klass=="Assassin":
        # Two readable short blades: left and right hands, never a dagger blob.
        for blade_sign in (-1,1):
            x=center+blade_sign*(17 if face in ("left","right") else 22)
            shift=-3 if blade_sign==sign else 3
            blade_y=76+offset+shift
            grip(x,blade_y,99+offset+shift)
            poly([(x-5,blade_y),(x-6,blade_y-20),(x,blade_y-37),
                  (x+6,blade_y-20),(x+5,blade_y)],STONE)
            ln(x,blade_y-32,x,blade_y-5,gem,2)
            ln(x-8,blade_y+1,x+8,blade_y+1,GOLD,3)
            gem_diamond(x,blade_y+1,3,5)
    elif klass=="Paladin":
        x=hand
        grip(x,44+offset,113+offset)
        poly([(x,11+offset),(x+7,29+offset),(x+6,46+offset),
              (x,54+offset),(x-6,46+offset),(x-7,29+offset)],STONE)
        gem_diamond(x,33+offset,5,15)
        poly([(x-17,51+offset),(x-5,44+offset),(x,55+offset),
              (x+5,44+offset),(x+17,51+offset),(x,61+offset)],GOLD)
        gem_diamond(x,54+offset,4,6)
        gem_diamond(x,112+offset,4,6)
    return art.buf

def put_frame(sheet,src,w,h,col,row,columns=3):
    stride=w*4
    for y in range(h):
        dest=((row*h+y)*w*columns+col*w)*4
        sheet[dest:dest+stride]=src[y*stride:(y+1)*stride]

def generate(root="assets/characters",dest="assets/equipment_worn",
             icons="assets/equipment_item_icons",sheets="assets/guardian_weapon_sheets"):
    root,dest,icons,sheets=map(Path,(root,dest,icons,sheets))
    entries={}
    count=0
    for klass,(name,kind,a,b,c) in WEAPONS.items():
        slug=name.lower().replace(" ","_")
        TINTS[name]=(a,b,c)
        entries[klass]={"item":name,"kind":kind,"slug":slug,"poses":0}
        for body in range(1,9):
            width,height,_=read_rgba(root/f"base_variant_{body:02d}/down_00.png")
            if height!=128:
                raise ValueError(f"Expected body height 128, got {height}")
            pixels=bytearray(width*3*height*4*4)
            for row,face in enumerate(FACES):
                for frame in range(3):
                    source=root/f"base_variant_{body:02d}/{face}_{frame:02d}.png"
                    w,h,_=read_rgba(source)
                    if (w,h)!=(width,height):raise ValueError(f"Pose mismatch: {source}")
                    artwork=weapon_pixels(klass,face,frame,w,h)
                    if not any(artwork[i] for i in range(3,len(artwork),4)):
                        raise ValueError(f"Empty weapon frame: {name}/{face}/{frame}")
                    write_rgba(dest/"weapon"/slug/f"base_variant_{body:02d}"/f"{face}_{frame:02d}.png",w,h,artwork)
                    put_frame(pixels,artwork,w,h,frame,row)
                    count+=1
                    entries[klass]["poses"]+=1
                    if body==5 and face=="down" and frame==1:
                        write_rgba(icons/f"{slug}.png",96,96,make_icon(artwork,w,h,"weapon",name))
            write_rgba(sheets/slug/f"base_variant_{body:02d}.png",width*3,height*4,pixels)
    sheets.mkdir(parents=True,exist_ok=True)
    (sheets/"guardian_weapon_manifest.json").write_text(json.dumps({
        "format":"3-column walk poses x 4-row facings down/left/up/right",
        "pixel_grid":"exact original body pixel dimensions; alpha-transparent overlays",
        "weapons":entries,
        "frames":count,
        "quest_reward_status":"class-specific one-time Guild claim; preview weapons are not generic shop stock"
    },indent=2)+"\n")
    print(f"AO GUARDIAN QUEST WEAPONS: PASS / {len(WEAPONS)} weapons / {count} transparent pose frames / 48 sprite sheets / 6 icons")

if __name__=="__main__":generate()
