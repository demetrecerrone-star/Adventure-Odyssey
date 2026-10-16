#!/usr/bin/env python3
"""Upgrade the cottage furniture preview into a working Sigil cosmetic boutique.

Apply after tools/apply_sigils_currency.py and character/equipment patches.
Purchased furniture remains a purely visual switch; its underlying chest,
mirror and bed interactions and collision never change.
"""
from pathlib import Path

p=Path("scripts/game.gd")
s=p.read_text(encoding="utf8")
start=s.index("func _open_home_decor()->void:")
end=s.index("\n# -- Starter cottage:",start)
old=s[start:end]
assert '_draw_sigil_coin(popup' in old and 'BACK TO CHEST' in old, "Unexpected cosmetic menu baseline"
new='''func _open_home_decor()->void:
\t_ensure_home_styles()
\tif popup!=null and is_instance_valid(popup):popup.queue_free()
\tpopup=Control.new()
\tpopup.name="CottageCosmeticBoutique"
\tpopup.size=Vector2(1280,720)
\tui.add_child(popup)
\tvar shade=ColorRect.new()
\tshade.color=Color(0,0,0,0.78)
\tshade.size=Vector2(1280,720)
\tpopup.add_child(shade)
\t_panel(popup,Rect2(146,66,988,611),Color("#173044"))
\t_label(popup,"COTTAGE BOUTIQUE   /   FURNITURE",186,84,776,46,27,Color("#f1d695"))
\t_draw_sigil_coin(popup,Vector2(934,91),34)
\t_label(popup,str(_sigils_balance()),979,91,105,35,25,Color("#ffe1a0"))
\t_label(popup,"Original furnishings are yours forever. Cosmetic styles change only their appearance.",191,137,872,41,17,Color("#d2dddb"))
\tvar slots=["Bed","Mirror","Chest"]
\tfor i in range(slots.size()):
\t\tvar slot:String=slots[i]
\t\tvar variants:Dictionary=SIGIL_COTTAGE_ART[slot]
\t\tvar variant:String=str(variants.keys()[0])
\t\tvar info:Dictionary=variants[variant]
\t\tvar label_name:String=variant.replace("_"," ").capitalize()
\t\tvar y:int=204+i*124
\t\t_panel(popup,Rect2(177,y,920,112),Color("#233949"))
\t\t_label(popup,slot.to_upper(),197,y+10,141,36,20,Color("#f3cb81"))
\t\tvar img:TextureRect=TextureRect.new()
\t\timg.name="StylePreview_"+slot
\t\timg.position=Vector2(331,y+8)
\t\timg.size=Vector2(109,96)
\t\timg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
\t\timg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
\t\timg.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
\t\timg.mouse_filter=Control.MOUSE_FILTER_IGNORE
\t\tvar path:String="res://assets/home/%s/%s.png" % [str(info["folder"]),variant]
\t\tif ResourceLoader.exists(path):img.texture=load(path)
\t\tpopup.add_child(img)
\t\t_label(popup,label_name,462,y+11,340,37,21,Color("#f5e9cc"))
\t\tvar owned:bool=data["home_owned"][slot].has(variant)
\t\tvar equipped:bool=str(data["home_styles"][slot])==variant
\t\tvar status:String="EQUIPPED" if equipped else ("OWNED" if owned else "%d SIGILS" % int(info["price"]))
\t\t_label(popup,status,462,y+51,325,31,16,Color("#9fe2c6") if owned else Color("#eac581"))
\t\tvar action_text:String="EQUIPPED" if equipped else ("EQUIP" if owned else "BUY  %d" % int(info["price"]))
\t\t_button(popup,action_text,839,y+7,224,45,_cottage_boutique_buy.bind(slot,variant))
\t\tvar using_starter:bool=str(data["home_styles"][slot])==HOME_STARTER[slot]
\t\t_button(popup,"STARTER ACTIVE" if using_starter else "USE STARTER",839,y+60,224,40,_cottage_boutique_starter.bind(slot))
\t_label(popup,"Sigils come from rare boss rewards.  No real-money purchases are enabled.",193,588,851,30,17,Color("#c3d6dc"))
\tif not cottage_cosmetic_notice.is_empty():
\t\t_label(popup,cottage_cosmetic_notice,193,617,752,30,16,Color("#ffe3a8"))
\t_button(popup,"BACK TO CHEST",875,614,211,47,_open_home_chest)

func _cottage_boutique_buy(slot:String,variant:String)->void:
\t_ensure_home_styles()
\tif not SIGIL_COTTAGE_ART.has(slot):return
\tif not SIGIL_COTTAGE_ART[slot].has(variant):return
\tvar owned_before:bool=data["home_owned"][slot].has(variant)
\tif _buy_sigil_cottage_style(slot,variant):
\t\tcottage_cosmetic_notice=("%s equipped." if owned_before else "%s purchased and equipped!") % variant.replace("_"," ").capitalize()
\telse:
\t\tcottage_cosmetic_notice="Not enough Sigils, or cosmetic art is unavailable."
\t_open_home_decor()

func _cottage_boutique_starter(slot:String)->void:
\t_ensure_home_styles()
\tif not HOME_STARTER.has(slot):return
\tvar variant:String=HOME_STARTER[slot]
\tif not data["home_owned"][slot].has(variant):return
\tdata["home_styles"][slot]=variant
\tif bedroom_art!=null and is_instance_valid(bedroom_art):
\t\tbedroom_art.call("apply_styles",data["home_styles"])
\tcottage_cosmetic_notice="%s starter style equipped." % slot
\t_save()
\t_open_home_decor()
'''
s=s[:start]+new+s[end:]
needle='var sigils_hud_label:Label'
assert s.count(needle)==1
s=s.replace(needle,needle+'\nvar cottage_cosmetic_notice:String=""',1)
p.write_text(s,encoding="utf8")
print("AO COTTAGE BOUTIQUE PATCH: PASS / genuine previews, buy, equip, reset and persistence.")
