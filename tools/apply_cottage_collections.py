#!/usr/bin/env python3
"""Install bedroom-only AO Decor collection menu and grouped Sigil purchases.

Runs after apply_sigils_currency.py. It extends the existing persistent bedroom
furniture slots rather than altering original sprites or gameplay interactions.
Each paid tier contains three complete, real illustrated furniture styles.
"""
from pathlib import Path

game = Path("scripts/game.gd")
s = game.read_text(encoding="utf-8")
def replace_once(a,b):
    global s
    count=s.count(a)
    if count!=1: raise SystemExit(f"COTTAGE COLLECTIONS ANCHOR FAILED {count}: {a[:120]!r}")
    s=s.replace(a,b,1)

replace_once(
    '\tsigils_hud_label=_label(hud,"",1052,104,175,32,19,Color("#ffe7a7"))',
    '''\tsigils_hud_label=_label(hud,"",1052,104,175,32,19,Color("#ffe7a7"))
\tif current_map=="bedroom":
\t\t_button(hud,"DECOR",1024,211,216,43,_open_cottage_collections)
\t\t_draw_sigil_coin(hud,Vector2(1041,218),28)'''
)
# Keep the original ROOM STYLE access in the chest while using the same menu.
replace_once(
    'func _open_home_decor()->void:\n\t_ensure_home_styles()',
    'func _open_home_decor()->void:\n\t_open_cottage_collections()\n\treturn\n\t_ensure_home_styles()'
)
s+=r'''

# --- AO Cottage Decor: one purchase unlocks 3 matching complete styles. ---
const COTTAGE_COLLECTION_TIERS={
    "starter":{"name":"STARTER OAK","price":0,"description":"Your original, functional oak furnishings."},
    "noble":{"name":"NOBLE COURT","price":30,"description":"Fine fabrics, polished woods and tasteful gilding."},
    "castle":{"name":"CASTLE GRANDEUR","price":60,"description":"Towering canopies, crests and jeweled fittings."},
    "royal":{"name":"ROYAL LEGACY","price":120,"description":"A spectacular royal chamber for a hero."}
}
const COTTAGE_COLLECTION_ORDER=["starter","noble","castle","royal"]
const COTTAGE_STYLE_NAMES={
    "feminine":"QUEEN'S CHAMBER",
    "masculine":"KING'S HALL",
    "unisex":"ROYAL HARMONY"
}
const COTTAGE_STYLE_ORDER=["feminine","masculine","unisex"]

func _ensure_cottage_collections()->void:
    _ensure_home_styles()
    if typeof(data.get("cottage_tiers_owned",null))!=TYPE_ARRAY:
        data["cottage_tiers_owned"]=["starter"]
    elif not data["cottage_tiers_owned"].has("starter"):
        data["cottage_tiers_owned"].append("starter")
    if typeof(data.get("cottage_style_choices",null))!=TYPE_DICTIONARY:
        data["cottage_style_choices"]={}
    var active:String=str(data.get("cottage_active_tier","starter"))
    if not COTTAGE_COLLECTION_TIERS.has(active) or not data["cottage_tiers_owned"].has(active):
        active="starter"
    data["cottage_active_tier"]=active

func _cottage_asset_path(tier:String,style:String,slot:String)->String:
    return "res://assets/home/collections/%s/%s/%s.svg" % [tier,style,slot.to_lower()]

func _cottage_tier_art_ready(tier:String)->bool:
    if tier=="starter":return true
    if not COTTAGE_COLLECTION_TIERS.has(tier):return false
    for style:String in COTTAGE_STYLE_ORDER:
        for slot:String in ["Bed","Mirror","Chest"]:
            if not ResourceLoader.exists(_cottage_asset_path(tier,style,slot)):
                return false
    return true

func _cottage_collection_owned(tier:String)->bool:
    _ensure_cottage_collections()
    return data["cottage_tiers_owned"].has(tier)

func _cottage_equip(tier:String,style:String="unisex")->bool:
    if current_map!="bedroom":return false
    _ensure_cottage_collections()
    if not COTTAGE_COLLECTION_TIERS.has(tier):return false
    if not data["cottage_tiers_owned"].has(tier):return false
    if tier!="starter" and (not COTTAGE_STYLE_NAMES.has(style) or not _cottage_tier_art_ready(tier)):
        return false
    var variant:String="collection_%s_%s" % [tier,style]
    for slot:String in ["Bed","Mirror","Chest"]:
        var chosen:String=str(HOME_STARTER[slot]) if tier=="starter" else variant
        if not data["home_owned"][slot].has(chosen):
            data["home_owned"][slot].append(chosen)
        data["home_styles"][slot]=chosen
    data["cottage_active_tier"]=tier
    if tier!="starter":data["cottage_style_choices"][tier]=style
    if bedroom_art!=null and is_instance_valid(bedroom_art):
        bedroom_art.call("apply_styles",data["home_styles"])
    _save()
    return true

func _cottage_buy_tier(tier:String)->bool:
    if current_map!="bedroom":return false
    _ensure_cottage_collections()
    if tier=="starter" or not COTTAGE_COLLECTION_TIERS.has(tier):return false
    if data["cottage_tiers_owned"].has(tier):return false
    if not _cottage_tier_art_ready(tier):return false
    var price:int=int(COTTAGE_COLLECTION_TIERS[tier]["price"])
    if price<=0 or _sigils_balance()<price:return false
    if not _spend_sigils(price):return false
    data["cottage_tiers_owned"].append(tier)
    if not _cottage_equip(tier,"unisex"):
        data["cottage_tiers_owned"].erase(tier)
        _award_sigils(price)
        return false
    return true

func _cottage_view_tier(tier:String,style:String)->void:
    _open_cottage_collections(tier,style)

func _cottage_buy_and_show(tier:String,style:String)->void:
    _cottage_buy_tier(tier)
    if _cottage_collection_owned(tier):
        _cottage_equip(tier,style)
    _open_cottage_collections(tier,style)

func _cottage_equip_and_show(tier:String,style:String)->void:
    _cottage_equip(tier,style)
    _open_cottage_collections(tier,style)

func _cottage_image(parent:Control,path:String,rect:Rect2)->void:
    if not ResourceLoader.exists(path):return
    var texture:Texture2D=load(path)
    if texture==null:return
    var picture=TextureRect.new()
    picture.texture=texture
    picture.position=rect.position
    picture.size=rect.size
    picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
    picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
    parent.add_child(picture)

func _open_cottage_collections(tier:String="starter",style:String="unisex")->void:
    if current_map!="bedroom":return
    _ensure_cottage_collections()
    if not COTTAGE_COLLECTION_TIERS.has(tier):tier="starter"
    if not COTTAGE_STYLE_NAMES.has(style):style="unisex"
    if popup!=null and is_instance_valid(popup):popup.queue_free()
    popup=Control.new()
    popup.name="CottageDecorMenu"
    popup.size=Vector2(1280,720)
    ui.add_child(popup)
    var shade=ColorRect.new()
    shade.color=Color(0.0,0.0,0.0,0.76)
    shade.size=popup.size
    popup.add_child(shade)
    _panel(popup,Rect2(55,55,1170,617),Color("#152c42"))
    _label(popup,"COTTAGE DECOR",102,72,728,48,29,Color("#ffdfa0"),true)
    _draw_sigil_coin(popup,Vector2(1014,78),32)
    _label(popup,"%d SIGILS" % _sigils_balance(),1050,79,157,34,19,Color("#ffe6a3"))
    _label(popup,"Each tier unlocks Queen, King and Unisex sets in ONE purchase.",101,120,1090,38,17,Color("#d5e6ed"))
    _panel(popup,Rect2(82,171,554,423),Color("#20394e"))
    _panel(popup,Rect2(648,171,548,423),Color("#20394e"))
    var active:String=str(data.get("cottage_active_tier","starter"))
    for i in range(COTTAGE_COLLECTION_ORDER.size()):
        var key:String=COTTAGE_COLLECTION_ORDER[i]
        var info:Dictionary=COTTAGE_COLLECTION_TIERS[key]
        var y:float=183.0+float(i)*100.0
        _panel(popup,Rect2(94,y,529,88),Color("#294861") if key==tier else Color("#1a3043"))
        var picture_path:String="res://assets/home/beds/oak_green.png" if key=="starter" else _cottage_asset_path(key,"unisex","Bed")
        _cottage_image(popup,picture_path,Rect2(103,y+8,80,73))
        _button(popup,str(info["name"]),188,y+6,237,40,_cottage_view_tier.bind(key,style))
        var price:int=int(info["price"])
        _label(popup,"FREE" if price==0 else "%d SIGILS" % price,196,y+48,177,27,17,Color("#f1d09a"))
        if key==active:
            _label(popup,"EQUIPPED",454,y+30,149,29,19,Color("#a9f2c6"),true)
        elif _cottage_collection_owned(key):
            _button(popup,"EQUIP",452,y+19,147,49,_cottage_equip_and_show.bind(key,str(data["cottage_style_choices"].get(key,"unisex"))))
        elif not _cottage_tier_art_ready(key):
            _label(popup,"ART PENDING",452,y+30,145,29,15,Color("#bbcad3"),true)
        else:
            _button(popup,"BUY",452,y+19,147,49,_cottage_buy_and_show.bind(key,style))
    var chosen:Dictionary=COTTAGE_COLLECTION_TIERS[tier]
    _label(popup,str(chosen["name"]),673,181,493,43,26,Color("#f5d6a2"),true)
    _label(popup,str(chosen["description"]),669,226,507,50,17,Color("#d9e5e9"),true)
    var preview_style:String=style
    if tier=="starter":preview_style="unisex"
    if tier!="starter":
        for i in range(COTTAGE_STYLE_ORDER.size()):
            var option:String=COTTAGE_STYLE_ORDER[i]
            _button(popup,"QUEEN" if option=="feminine" else ("KING" if option=="masculine" else "UNISEX"),673+i*165,286,154,42,_cottage_view_tier.bind(tier,option))
        _label(popup,COTTAGE_STYLE_NAMES[preview_style],681,346,490,33,19,Color("#ccebf3"),true)
    else:
        _label(popup,"Original Oak Furnishings",681,346,490,33,19,Color("#ccebf3"),true)
    for j in range(3):
        var slot:String=["Bed","Mirror","Chest"][j]
        var path:String="res://assets/home/%s/%s.png" % [["beds","mirrors","chests"][j],str(HOME_STARTER[slot])] if tier=="starter" else _cottage_asset_path(tier,preview_style,slot)
        _cottage_image(popup,path,Rect2(677+j*162,391,146,132))
        _label(popup,slot.to_upper(),681+j*162,532,142,29,17,Color("#f3dda8"),true)
    if tier!="starter" and _cottage_collection_owned(tier):
        var current_style:String=str(data["cottage_style_choices"].get(tier,"unisex"))
        if active==tier and current_style==preview_style:
            _label(popup,"EQUIPPED",824,559,201,29,19,Color("#a9f2c6"),true)
        else:
            _button(popup,"EQUIP THIS STYLE",812,555,230,41,_cottage_equip_and_show.bind(tier,preview_style))
    _button(popup,"CLOSE",979,616,199,48,_dismiss_message)
'''
# Maintain the project convention of tab-indented GDScript blocks.
marker="\n# --- AO Cottage Decor: one purchase unlocks 3 matching complete styles. ---"
assert s.count(marker)==1
before,block=s.split(marker,1)
fixed=[]
for line in (marker+block).split("\n"):
    spaces=len(line)-len(line.lstrip(" "))
    if spaces and spaces%4: raise SystemExit("COTTAGE COLLECTIONS INDENT ERROR")
    fixed.append("\t"*(spaces//4)+line[spaces:])
game.write_text(before+"\n".join(fixed),encoding="utf-8")

# Swappable collection SVG art lives beside, not over, original PNG furniture.
room=Path("scripts/bedroom_scene.gd")
r=room.read_text(encoding="utf-8")
needle='''        var path=prefix+variant+".png"
        if not ResourceLoader.exists(path):
            path=prefix+DEFAULT_STYLE[slot]+".png"'''
replacement='''        var path=prefix+variant+".png"
        if variant.begins_with("collection_"):
            var parts=variant.substr(11).split("_")
            if parts.size()==2:
                path="res://assets/home/collections/%s/%s/%s.svg" % [parts[0],parts[1],slot.to_lower()]
        if not ResourceLoader.exists(path):
            path=prefix+DEFAULT_STYLE[slot]+".png"'''
if r.count(needle)!=1:raise SystemExit("COTTAGE ROOM IMAGE PATH ANCHOR FAILED")
room.write_text(r.replace(needle,replacement,1),encoding="utf-8")
print("AO COTTAGE COLLECTIONS: HUD coin, bundle prices, 3 styles, ownership/equip/save and real SVG textures.")
