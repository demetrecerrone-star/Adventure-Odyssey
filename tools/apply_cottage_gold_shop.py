#!/usr/bin/env python3
"""Add optional gold-furnished cottage styles without altering existing AO artwork.

Runs AFTER apply_cottage_collections.py during reconstruction. The original
starter bedroom, storage chest, mirror and three Sigil collections stay intact.
"""
from pathlib import Path

game_file = Path("scripts/game.gd")
game = game_file.read_text(encoding="utf-8")
marker = "# --- AO Cottage Decor: one purchase unlocks 3 matching complete styles. ---"
if game.count(marker) != 1 or "func _cottage_gold_buy(" in game:
    raise SystemExit("COTTAGE GOLD SHOP: required existing collection patch missing or duplicate")

game += '''
# --- Everyday cottage decor: permanent, individual GOLD purchases. ---
# Future outfit/accessory entries reuse these save categories but have NO live
# products, purchases, or character stat effects until reviewed artwork exists.
const COTTAGE_GOLD_ITEMS={
\t"Bed":{"name":"RIVERSIDE BLUE BED","variant":"riverside_blue","price":25,"folder":"beds"},
\t"Mirror":{"name":"COPPER LEAF MIRROR","variant":"copper_leaf","price":18,"folder":"mirrors"},
\t"Chest":{"name":"IRONWOOD STORAGE CHEST","variant":"ironwood","price":20,"folder":"chests"}
}

func _ensure_cosmetic_categories()->void:
\tif typeof(data.get("cosmetic_owned",null))!=TYPE_DICTIONARY:
\t\tdata["cosmetic_owned"]={}
\tif typeof(data.get("cosmetic_equipped",null))!=TYPE_DICTIONARY:
\t\tdata["cosmetic_equipped"]={}
\tfor group:String in ["outfits","accessories"]:
\t\tif typeof(data["cosmetic_owned"].get(group,null))!=TYPE_ARRAY:
\t\t\tdata["cosmetic_owned"][group]=[]
\t\tif not data["cosmetic_equipped"].has(group):
\t\t\tdata["cosmetic_equipped"][group]=""

func _cottage_gold_asset(slot:String)->String:
\tif not COTTAGE_GOLD_ITEMS.has(slot):return ""
\tvar offer:Dictionary=COTTAGE_GOLD_ITEMS[slot]
\treturn "res://assets/home/%s/%s.svg" % [str(offer["folder"]),str(offer["variant"])]

func _cottage_gold_owned(slot:String)->bool:
\t_ensure_home_styles()
\tif not COTTAGE_GOLD_ITEMS.has(slot):return false
\treturn data["home_owned"][slot].has(str(COTTAGE_GOLD_ITEMS[slot]["variant"]))

func _cottage_gold_equip(slot:String)->bool:
\tif current_map!="bedroom" or not COTTAGE_GOLD_ITEMS.has(slot):return false
\tif not ResourceLoader.exists(_cottage_gold_asset(slot)) or not _cottage_gold_owned(slot):return false
\tdata["home_styles"][slot]=str(COTTAGE_GOLD_ITEMS[slot]["variant"])
\tdata["cottage_active_tier"]="custom"
\tif bedroom_art!=null and is_instance_valid(bedroom_art):
\t\tbedroom_art.call("apply_styles",data["home_styles"])
\t_save()
\treturn true

func _cottage_gold_buy(slot:String)->bool:
\tif current_map!="bedroom" or not COTTAGE_GOLD_ITEMS.has(slot):return false
\t_ensure_home_styles()
\t_ensure_cosmetic_categories()
\tif not ResourceLoader.exists(_cottage_gold_asset(slot)):return false
\tif _cottage_gold_owned(slot):return _cottage_gold_equip(slot)
\tvar price:int=int(COTTAGE_GOLD_ITEMS[slot]["price"])
\tif price<=0 or int(data.get("gold",0))<price:return false
\tdata["gold"]=int(data["gold"])-price
\tdata["home_owned"][slot].append(str(COTTAGE_GOLD_ITEMS[slot]["variant"]))
\tif not _cottage_gold_equip(slot):
\t\tdata["gold"]=int(data["gold"])+price
\t\tdata["home_owned"][slot].erase(str(COTTAGE_GOLD_ITEMS[slot]["variant"]))
\t\t_save()
\t\treturn false
\t_refresh_hud()
\treturn true

func _cottage_gold_buy_and_show(slot:String)->void:
\t_cottage_gold_buy(slot)
\t_open_cottage_gold_shop()

func _cottage_gold_equip_and_show(slot:String)->void:
\t_cottage_gold_equip(slot)
\t_open_cottage_gold_shop()

func _open_cottage_gold_shop()->void:
\tif current_map!="bedroom":return
\t_ensure_home_styles()
\t_ensure_cosmetic_categories()
\tif popup!=null and is_instance_valid(popup):popup.queue_free()
\tpopup=Control.new()
\tpopup.name="CottageGoldShop"
\tpopup.size=Vector2(1280,720)
\tui.add_child(popup)
\tvar shade=ColorRect.new()
\tshade.color=Color(0,0,0,0.78)
\tshade.size=popup.size
\tpopup.add_child(shade)
\t_panel(popup,Rect2(138,42,1005,636),Color("#172f42"))
\t_label(popup,"EVERYDAY COTTAGE FURNISHINGS",184,69,879,48,28,Color("#ffdfa0"),true)
\t_label(popup,"Gold %d    |    Sigils %d" % [int(data.get("gold",0)),_sigils_balance()],184,121,768,37,20,Color("#f0d9a9"))
\t_label(popup,"Buy each piece once. Owned furniture can be equipped again free.",184,158,878,34,17,Color("#d7e6ea"))
\tfor i in range(3):
\t\tvar slot:String=["Bed","Mirror","Chest"][i]
\t\tvar offer:Dictionary=COTTAGE_GOLD_ITEMS[slot]
\t\tvar y:float=206.0+float(i)*122.0
\t\t_panel(popup,Rect2(177,y,919,112),Color("#243c4b"))
\t\t_cottage_image(popup,_cottage_gold_asset(slot),Rect2(197,y+7,120,95))
\t\t_label(popup,str(offer["name"]),344,y+10,516,33,22,Color("#f3dbaf"),true)
\t\t_label(popup,"%d GOLD | %s" % [int(offer["price"]),slot.to_upper()],344,y+51,400,30,18,Color("#d1e3ea"))
\t\tif not ResourceLoader.exists(_cottage_gold_asset(slot)):
\t\t\t_label(popup,"ART PENDING",858,y+35,215,37,17,Color("#bfcbd0"))
\t\telif str(data["home_styles"][slot])==str(offer["variant"]):
\t\t\t_label(popup,"EQUIPPED",880,y+35,192,35,18,Color("#a7efbf"),true)
\t\telif _cottage_gold_owned(slot):
\t\t\t_button(popup,"EQUIP",856,y+27,208,51,_cottage_gold_equip_and_show.bind(slot))
\t\telse:
\t\t\t_button(popup,"BUY",856,y+27,208,51,_cottage_gold_buy_and_show.bind(slot))
\t_button(popup,"SIGIL COLLECTIONS",190,592,356,55,_open_cottage_collections)
\t_button(popup,"CLOSE",875,592,213,55,_dismiss_message)
'''
game_file.write_text(game,encoding="utf-8")

room_file=Path("scripts/bedroom_scene.gd")
room=room_file.read_text(encoding="utf-8")
old='''        if not ResourceLoader.exists(path):
            path=prefix+DEFAULT_STYLE[slot]+".png"'''
new='''        if not ResourceLoader.exists(path) and not variant.begins_with("collection_"):
            var svg_path=prefix+variant+".svg"
            if ResourceLoader.exists(svg_path):
                path=svg_path
        if not ResourceLoader.exists(path):
            path=prefix+DEFAULT_STYLE[slot]+".png"'''
if room.count(old)!=1:
    raise SystemExit("COTTAGE GOLD SHOP: existing sprite resolver changed")
room_file.write_text(room.replace(old,new,1),encoding="utf-8")

# Link the additional page into the existing Sigil cottage UI.
game = game_file.read_text(encoding="utf-8")
old='\t_label(popup,"Each tier unlocks Queen, King and Unisex sets in ONE purchase.",101,120,1090,38,17,Color("#d5e6ed"))'
new='''\t_label(popup,"Each tier unlocks Queen, King and Unisex sets in ONE purchase.",101,120,810,38,17,Color("#d5e6ed"))
\t_button(popup,"GOLD FURNITURE",729,616,224,48,_open_cottage_gold_shop)'''
if game.count(old)!=1:
    raise SystemExit("COTTAGE GOLD SHOP: Sigil shop menu anchor changed")
# Custom gold furnishings must not be reset as an invalid paid tier on reload.
old_active='''    if not COTTAGE_COLLECTION_TIERS.has(active) or not data["cottage_tiers_owned"].has(active):
        active="starter"'''
new_active='''    if active!="custom" and (not COTTAGE_COLLECTION_TIERS.has(active) or not data["cottage_tiers_owned"].has(active)):
        active="starter"'''
# Previous patch normalizes indentation to tabs.
old_active=old_active.replace("    ","\t")
new_active=new_active.replace("    ","\t")
if game.count(old_active)!=1:
    raise SystemExit("COTTAGE GOLD SHOP: collection save migration anchor changed")
game=game.replace(old,new,1).replace(old_active,new_active,1)
# Sprite2D is deliberately used for UI thumbnails; its native-size scale is
# predictable after add_child, unlike TextureRect minimum-size negotiations.
# This changes only how already-approved image resources are drawn.
def replace_function(head: str, next_head: str, replacement: str) -> None:
    global game
    anchor = "\n" + head
    end_anchor = "\n" + next_head
    if game.count(anchor) != 1 or game.count(end_anchor) != 1:
        raise SystemExit("COTTAGE SPRITE HELPER ANCHOR FAILED: " + head)
    first = game.index(anchor)
    last = game.index(end_anchor, first)
    game = game[:first] + "\n" + replacement.rstrip("\n") + "\n" + game[last:]

replace_function(
    "func _cottage_image(parent:Control,path:String,rect:Rect2)->void:",
    "func _open_cottage_collections(tier:String=\"starter\",style:String=\"unisex\")->void:",
    """func _cottage_image(parent:Control,path:String,rect:Rect2)->void:
\tif not ResourceLoader.exists(path):return
\tvar texture:Texture2D=load(path)
\tif texture==null:return
\tvar native_size:Vector2=texture.get_size()
\tif native_size.x<=0.0 or native_size.y<=0.0:return
\tvar picture=Sprite2D.new()
\tpicture.texture=texture
\tpicture.name="CottagePreviewSprite"
\tpicture.centered=true
\tpicture.position=rect.position+rect.size*0.5
\tpicture.scale=Vector2.ONE*minf(rect.size.x/native_size.x,rect.size.y/native_size.y)
\tpicture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
\tparent.add_child(picture)
""")

replace_function(
    "func _draw_sigil_coin(parent:Control,where:Vector2,size:int)->void:",
    "func _buy_sigil_cottage_style(slot:String,variant:String)->bool:",
    """func _draw_sigil_coin(parent:Control,where:Vector2,size:int)->void:
\tvar path:String="res://assets/ui/odyssey_sigil.svg"
\tif not ResourceLoader.exists(path):return
\tvar texture:Texture2D=load(path)
\tif texture==null or texture.get_width()<=0:return
\tvar icon=Sprite2D.new()
\ticon.name="OdysseySigilCoin"
\ticon.texture=texture
\ticon.centered=true
\ticon.position=where+Vector2.ONE*float(size)*0.5
\ticon.scale=Vector2.ONE*float(size)/float(texture.get_width())
\ticon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
\tparent.add_child(icon)
""")

# Tidy original Sigil collection panel spacing for phone-scale readability.
# Do not alter assets or costs, only where the existing Godot controls render.
replacements = (
    ('_draw_sigil_coin(popup,Vector2(1014,78),32)',
     '_draw_sigil_coin(popup,Vector2(953,79),20)'),
    ('_label(popup,"%d SIGILS" % _sigils_balance(),1050,79,157,34,19',
     '_label(popup,"%d SIGILS" % _sigils_balance(),1043,82,161,32,18'),
    ('_cottage_image(popup,picture_path,Rect2(103,y+8,80,73))',
     '_cottage_image(popup,picture_path,Rect2(111,y+22,49,44))'),
    ('_cottage_image(popup,path,Rect2(677+j*162,391,146,132))',
     '_cottage_image(popup,path,Rect2(685+j*162,382,132,112))'),
    ('_label(popup,slot.to_upper(),681+j*162,532,142,29,17',
     '_label(popup,slot.to_upper(),681+j*162,509,142,25,16'),
    ('_label(popup,"EQUIPPED",824,559,201,29,19',
     '_label(popup,"EQUIPPED",824,556,201,28,18'),
    ('_button(popup,"EQUIP THIS STYLE",812,555,230,41',
     '_button(popup,"EQUIP THIS STYLE",812,547,230,41'),
)
for original, replacement in replacements:
    if game.count(original) != 1:
        raise SystemExit("COTTAGE SHOP LAYOUT ANCHOR FAILED: " + original)
    game = game.replace(original, replacement, 1)

game_file.write_text(game,encoding="utf-8")
print("AO COTTAGE GOLD SHOP: three independent illustrated upgrades and persistent currency-safe inventory.")
