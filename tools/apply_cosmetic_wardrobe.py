#!/usr/bin/env python3
"""AO visible wardrobe: purchasable colorways for the existing starter clothing.
Apply after cottage collections and equipment visuals. Does not modify original
character sprites, armor layering, stats, furniture or the app icon.
"""
from pathlib import Path
p=Path("scripts/game.gd")
s=p.read_text(encoding="utf8")
def replace_once(old,new):
    global s
    n=s.count(old)
    if n!=1:
        raise SystemExit(f"WARDROBE PATCH ANCHOR FAILED ({n}): {old[:120]!r}")
    s=s.replace(old,new,1)

# Each generated outfit sprite is tinted when updated in any facing/frame.
replace_once('''\t\t\tsprite.texture=load(path)
\t\t\tsprite.visible=true''','''\t\t\tsprite.texture=load(path)
\t\t\tsprite.modulate=_wardrobe_tint(layer)
\t\t\tsprite.visible=true''')
# A distinct, accessible bedroom-only wardrobe button alongside cottage decor.
replace_once('''\t\t_draw_sigil_coin(hud,Vector2(1041,218),28)''','''\t\t_draw_sigil_coin(hud,Vector2(1041,218),28)
\t\t_button(hud,"WARDROBE",1024,261,216,43,_open_wardrobe)''')

s += '''
# -- Character cosmetic colorways: actual worn top, trousers and shoes -------
# No gear stats, equipment restrictions, random purchases or paid billing.
const WARDROBE_ORDER=["traveler","forest","twilight","ember","azure","moonlit"]
const WARDROBE_COLORS={
    "traveler":{"name":"ORIGINAL TRAVELER","price":0,"top":"#ffffff","pants":"#ffffff","shoes":"#ffffff"},
    "forest":{"name":"FOREST WANDERER","price":5,"top":"#b0d7b7","pants":"#9fb590","shoes":"#d0c9a2"},
    "twilight":{"name":"TWILIGHT ROGUE","price":8,"top":"#bcaddc","pants":"#8e96c5","shoes":"#b1adca"},
    "ember":{"name":"EMBER SCOUT","price":10,"top":"#f3a39b","pants":"#ad878b","shoes":"#dbc4a0"},
    "azure":{"name":"AZURE VOYAGER","price":15,"top":"#9ed6f9","pants":"#a2bee9","shoes":"#b0d7e7"},
    "moonlit":{"name":"MOONLIT FINERY","price":25,"top":"#e0e8ff","pants":"#c2bfef","shoes":"#eee1bf"}
}
const WARDROBE_LAYERS={"starter_top":"top","starter_pants":"pants","starter_shoes":"shoes"}

func _wardrobe_ensure()->void:
    if typeof(data.get("wardrobe_owned",null))!=TYPE_ARRAY:
        data["wardrobe_owned"]=["traveler"]
    if not data["wardrobe_owned"].has("traveler"):
        data["wardrobe_owned"].append("traveler")
    var equipped:String=str(data.get("wardrobe_equipped","traveler"))
    if not WARDROBE_COLORS.has(equipped) or not data["wardrobe_owned"].has(equipped):
        equipped="traveler"
    data["wardrobe_equipped"]=equipped

func _wardrobe_tint(layer:String)->Color:
    var selected:String=str(data.get("wardrobe_equipped","traveler"))
    if not WARDROBE_COLORS.has(selected):selected="traveler"
    var color_key:String=str(WARDROBE_LAYERS.get(layer,"top"))
    return Color(str(WARDROBE_COLORS[selected][color_key]))

func _wardrobe_owned(outfit:String)->bool:
    _wardrobe_ensure()
    return outfit in data["wardrobe_owned"]

func _wardrobe_buy(outfit:String)->bool:
    if current_map!="bedroom":return false
    _wardrobe_ensure()
    if not WARDROBE_COLORS.has(outfit) or outfit=="traveler":return false
    if data["wardrobe_owned"].has(outfit):return false
    var price:int=int(WARDROBE_COLORS[outfit]["price"])
    if price<=0 or _sigils_balance()<price:return false
    if not _spend_sigils(price):return false
    data["wardrobe_owned"].append(outfit)
    # The purchase automatically equips the colorway, unlike a mere preview.
    data["wardrobe_equipped"]=outfit
    _update_starter_clothing_layers()
    _update_worn_equipment_frames()
    _save()
    return true

func _wardrobe_equip(outfit:String)->bool:
    if current_map!="bedroom":return false
    _wardrobe_ensure()
    if not WARDROBE_COLORS.has(outfit) or not data["wardrobe_owned"].has(outfit):
        return false
    data["wardrobe_equipped"]=outfit
    _update_starter_clothing_layers()
    _update_worn_equipment_frames()
    _save()
    return true

func _wardrobe_select(outfit:String)->void:
    _open_wardrobe(outfit)

func _wardrobe_buy_show(outfit:String)->void:
    _wardrobe_buy(outfit)
    _open_wardrobe(outfit)

func _wardrobe_equip_show(outfit:String)->void:
    _wardrobe_equip(outfit)
    _open_wardrobe(outfit)

func _wardrobe_preview_sprite(holder:Node2D,path:String,color:Color=Color.WHITE)->void:
    if not ResourceLoader.exists(path):return
    var image:Sprite2D=Sprite2D.new()
    image.texture=load(path)
    image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    image.modulate=color
    image.scale=Vector2(2.1,2.1)
    holder.add_child(image)

func _wardrobe_preview(parent:Control,outfit:String)->void:
    # Actual source-derived sprite layers, not concept art or upscaled icons.
    var variant:String="base_variant_%02d" % (int(data.get("body",0))+1)
    var frame:String="down_00.png"
    var stand=Node2D.new()
    stand.name="WardrobeCharacterPreview"
    stand.position=Vector2(931,407)
    parent.add_child(stand)
    _wardrobe_preview_sprite(stand,"res://assets/character_layers/underwear_base/%s/%s" % [variant,frame])
    var shade:Dictionary=WARDROBE_COLORS[outfit]
    for pair in [["starter_pants","pants"],["starter_top","top"],["starter_shoes","shoes"]]:
        _wardrobe_preview_sprite(stand,"res://assets/character_layers/%s/%s/%s" % [pair[0],variant,frame],Color(str(shade[pair[1]])))
    var hair:String=HAIR[clampi(int(data.get("hair",0)),0,HAIR.size()-1)]
    var tint_index:int=clampi(int(data.get("hair_tint",0)),0,HAIR_TINTS.size()-1)
    _wardrobe_preview_sprite(stand,_sprite_path("hair",hair,"down",0),HAIR_TINTS[tint_index])

func _open_wardrobe(outfit:String="")->void:
    if current_map!="bedroom":return
    _wardrobe_ensure()
    if not WARDROBE_COLORS.has(outfit):
        outfit=str(data["wardrobe_equipped"])
    if popup!=null and is_instance_valid(popup):popup.queue_free()
    popup=Control.new()
    popup.name="CharacterWardrobeMenu"
    popup.size=Vector2(1280,720)
    ui.add_child(popup)
    var shade:ColorRect=ColorRect.new()
    shade.color=Color(0,0,0,0.78)
    shade.size=popup.size
    popup.add_child(shade)
    _panel(popup,Rect2(60,52,1160,620),Color("#152e44"))
    _label(popup,"CHARACTER WARDROBE",93,70,688,47,29,Color("#f5d79a"),true)
    _draw_sigil_coin(popup,Vector2(1023,78),32)
    _label(popup,"%d SIGILS" % _sigils_balance(),1060,80,150,36,19,Color("#ffe6a3"))
    _label(popup,"Dye the clothes you wear beneath your armor. One purchase, yours forever.",94,121,1083,32,18,Color("#d3e4ed"))
    _panel(popup,Rect2(88,169,558,440),Color("#203c51"))
    _panel(popup,Rect2(657,169,530,440),Color("#203c51"))
    for i in range(WARDROBE_ORDER.size()):
        var name:String=WARDROBE_ORDER[i]
        var colors:Dictionary=WARDROBE_COLORS[name]
        var y:float=179.0+i*70.0
        _panel(popup,Rect2(100,y,532,64),Color("#304e67") if outfit==name else Color("#1a3045"))
        _button(popup,str(colors["name"]),113,y+5,309,36,_wardrobe_select.bind(name))
        for k in range(3):
            var swatch:ColorRect=ColorRect.new()
            swatch.position=Vector2(429+k*27,y+12)
            swatch.size=Vector2(22,22)
            swatch.color=Color(str(colors[["top","pants","shoes"][k]]))
            popup.add_child(swatch)
        var is_owned:bool=_wardrobe_owned(name)
        _label(popup,"EQUIPPED" if name==str(data["wardrobe_equipped"]) else ("OWNED" if is_owned else ("%d SIGILS" % int(colors["price"])) ,112,y+41,290,19,15,Color("#a8ecc8") if is_owned else Color("#f0cb8a"))
        if outfit==name:
            _label(popup,"VIEWING",525,y+38,89,24,14,Color("#cce8fb"))
    _label(popup,str(WARDROBE_COLORS[outfit]["name"]),676,183,490,37,25,Color("#f5d69a"),true)
    _label(popup,"YOUR CHARACTER / FRONT VIEW",688,226,474,32,18,Color("#d5e6f2"),true)
    _wardrobe_preview(popup,outfit)
    _label(popup,"Cosmetic only  -  armor, stats and skills unchanged",682,516,482,35,16,Color("#bcd4e4"),true)
    if outfit==str(data["wardrobe_equipped"]):
        _label(popup,"CURRENTLY EQUIPPED",792,556,300,42,19,Color("#a8ecc8"),true)
    elif _wardrobe_owned(outfit):
        _button(popup,"EQUIP THIS COLORWAY",784,553,313,45,_wardrobe_equip_show.bind(outfit))
    else:
        _button(popup,"UNLOCK  /  %d SIGILS" % int(WARDROBE_COLORS[outfit]["price"]),784,553,313,45,_wardrobe_buy_show.bind(outfit))
    _button(popup,"CLOSE",975,617,205,47,_dismiss_message)
'''
marker="\n# -- Character cosmetic colorways: actual worn top, trousers and shoes -------"
assert s.count(marker)==1
before,block=s.split(marker,1)
fixed=[]
for line in (marker+block).split("\n"):
    spaces=len(line)-len(line.lstrip(" "))
    if spaces and spaces%4:
        raise SystemExit("WARDROBE INDENT ERROR")
    fixed.append("\t"*(spaces//4)+line[spaces:])
p.write_text(before+"\n".join(fixed),encoding="utf8")
print("AO WARDROBE PATCH: 6 visible outfit tints / 5 Sigil unlocks / ownership, saves, 8 bodies and 4-directions.")
