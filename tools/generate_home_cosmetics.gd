extends SceneTree
# Generate three finished transparent furniture variants from the exact approved
# starter PNG silhouettes. Never overwrite starter sprites or the room backdrop.
# Runs once during CI reconstruction before Godot imports the generated assets.

const VARIANTS=[
    {"slot":"bed","source":"res://assets/home/beds/oak_green.png","target":"res://assets/home/beds/royal_blue.png"},
    {"slot":"mirror","source":"res://assets/home/mirrors/tall_oak.png","target":"res://assets/home/mirrors/sunburst_gold.png"},
    {"slot":"chest","source":"res://assets/home/chests/plain_wood.png","target":"res://assets/home/chests/moonstone_trim.png"}
]

func _initialize()->void:
    var completed:int=0
    for spec in VARIANTS:
        var input_path:String=ProjectSettings.globalize_path(str(spec["source"]))
        var output_path:String=ProjectSettings.globalize_path(str(spec["target"]))
        var image:Image=Image.load_from_file(input_path)
        if image==null or image.is_empty():
            push_error("AO COSMETIC ART: missing source "+input_path)
            quit(1)
            return
        image.convert(Image.FORMAT_RGBA8)
        var nontransparent:int=0
        var modified:int=0
        for y in range(image.get_height()):
            for x in range(image.get_width()):
                var src:Color=image.get_pixel(x,y)
                if src.a<0.02:
                    continue
                nontransparent+=1
                var dst:Color=_restyle(str(spec["slot"]),src)
                if absf(dst.r-src.r)>0.04 or absf(dst.g-src.g)>0.04 or absf(dst.b-src.b)>0.04:
                    modified+=1
                image.set_pixel(x,y,dst)
        if nontransparent==0 or modified<100:
            push_error("AO COSMETIC ART: style transform produced too few pixels "+str(spec["slot"]))
            quit(1)
            return
        var error:int=image.save_png(output_path)
        if error!=OK:
            push_error("AO COSMETIC ART: cannot save "+output_path)
            quit(1)
            return
        print("AO COSMETIC ART: "+str(spec["slot"])+" "+str(image.get_width())+"x"+str(image.get_height())+" changed "+str(modified)+" pixels")
        completed+=1
    print("AO COTTAGE COSMETIC ART: PASS / "+str(completed)+" aligned recolored transparent sprites")
    quit(0)

func _restyle(slot:String,c:Color)->Color:
    var h:float=c.h
    var sat:float=c.s
    var val:float=c.v
    if slot=="bed":
        # Preserve timber frame, pillow and bedding folds; change green fabric
        # into saturated royal-blue cloth with the existing source shading.
        if h>0.19 and h<0.49 and sat>0.12 and val>0.08:
            return Color.from_hsv(0.605,clampf(sat*1.33,0.42,0.82),clampf(val*0.98,0.0,1.0),c.a)
    elif slot=="mirror":
        # A warm gilt timber frame surrounding the original reflective glass.
        if h>0.025 and h<0.19 and sat>0.15 and val>0.07:
            return Color.from_hsv(0.123,clampf(sat*0.86+0.13,0.43,0.81),clampf(val*1.22+0.025,0.0,0.99),c.a)
        if h>0.51 and h<0.75 and sat>0.13 and val>0.23:
            return Color.from_hsv(0.555,clampf(sat*0.86,0.19,0.54),clampf(val*1.06,0.0,1.0),c.a)
    elif slot=="chest":
        # Moonstone navy finish: preserve light-and-shadow and individual iron
        # hardware pixels; cool the clasps to blue-silver.
        if h>0.025 and h<0.21 and sat>0.19 and val>0.06:
            return Color.from_hsv(0.64,clampf(sat*0.68,0.30,0.56),clampf(val*0.78+0.015,0.0,0.82),c.a)
        if sat<0.22 and val>0.10:
            return Color.from_hsv(0.54,0.28,clampf(val*1.09+0.05,0.0,1.0),c.a)
    return c
