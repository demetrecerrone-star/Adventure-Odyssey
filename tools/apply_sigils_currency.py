#!/usr/bin/env python3
"""Add distinct, save-compatible Odyssey Sigils and ready-for-art home styling.

Runs after item_art, monster_loot and home_furniture. Sigils are separate from
gold: early guild and one-time boss milestones grant small amounts. Only styles
with an actual installed sprite can be purchased; no blank or fictitious paid
cosmetics. Preserve all original furniture and the approved app icon.
"""
from pathlib import Path
path=Path("scripts/game.gd")
s=path.read_text(encoding="utf8")

def rep(old,new):
    global s
    if s.count(old)!=1:
        raise SystemExit("AO SIGILS PATCH ANCHOR FAILED (%d): %r" % (s.count(old),old[:110]))
    s=s.replace(old,new,1)

rep('"gold":15, "quest_kills":0','"gold":15, "sigils":0, "quest_kills":0')
rep('\tdata = parsed\n\treturn true',
    '\tparsed["sigils"]=maxi(0,int(parsed.get("sigils",0)))\n\tdata = parsed\n\treturn true')
rep('var starter_clothes_sprites: Dictionary={}',
    'var sigils_hud_label:Label\nvar starter_clothes_sprites: Dictionary={}')
rep('\thp_label=_label(hud,"",37,48,705,42,21,Color("e8bdaf"))',
'''\thp_label=_label(hud,"",37,48,705,42,21,Color("e8bdaf"))
\t_draw_sigil_coin(hud,Vector2(1016,104),31)
\tsigils_hud_label=_label(hud,"",1052,104,175,32,19,Color("#ffe7a7"))''')
rep('\thp_label.text="HP %d/%d     EXP %d/%d     Gold %d     %s" % [int(data["hp"]),int(data["max_hp"]),int(data["xp"]),int(data["level"])*50,int(data["gold"]),mission]',
'''\thp_label.text="HP %d/%d     EXP %d/%d     Gold %d     %s" % [int(data["hp"]),int(data["max_hp"]),int(data["xp"]),int(data["level"])*50,int(data["gold"]),mission]
\tif sigils_hud_label!=null and is_instance_valid(sigils_hud_label):
\t\tsigils_hud_label.text="Sigils  %d" % _sigils_balance()''')
rep('\t_label(popup,"Gold: %d   •   Collected supplies and equipment" % int(data.get("gold",0)),159,119,935,34,21,Color("#ffdf97"))',
    '\t_label(popup,"Gold: %d   |   Sigils: %d   |   Collected supplies" % [int(data.get("gold",0)),_sigils_balance()],159,119,935,34,21,Color("#ffdf97"))')
rep('\t_label(popup,"More designs will be earnable with in-game gold in a future update.",290,511,703,42,17,Color("#b9cfd8"),true)',
'''\t_draw_sigil_coin(popup,Vector2(296,517),29)
\t_label(popup,"Sigils: %d  |  Special cottage styles use Sigils when their art arrives." % _sigils_balance(),336,510,671,42,16,Color("#b9cfd8"),true)''')
# Once-only quest and boss rewards respect existing completion checks.
rep('\t\t\tdata["guild_training_completed"]=true',
    '\t\t\tdata["guild_training_completed"]=true\n\t\t\t_award_sigils(5)')
rep('\t\t\tdata["guardian_defeated"]=true',
    '\t\t\tdata["guardian_defeated"]=true\n\t\t\t_award_sigils(25)')

s+='''
# -- Two distinct currencies: gold for trades, Sigils for exclusive cosmetics.
# No cash purchase system, no class/stat advantages and no repeatable boss farm.
const SIGIL_COTTAGE_ART={
    "Bed":{"royal_blue":{"price":30,"folder":"beds"}},
    "Mirror":{"sunburst_gold":{"price":20,"folder":"mirrors"}},
    "Chest":{"moonstone_trim":{"price":25,"folder":"chests"}}
}

func _sigils_balance()->int:
\treturn maxi(0,int(data.get("sigils",0)))

func _award_sigils(amount:int)->void:
\tif amount<=0:return
\tdata["sigils"]=_sigils_balance()+amount
\t_refresh_hud()
\t_save()

func _spend_sigils(amount:int)->bool:
\tif amount<=0 or _sigils_balance()<amount:return false
\tdata["sigils"]=_sigils_balance()-amount
\t_refresh_hud()
\treturn true

func _draw_sigil_coin(parent:Control,where:Vector2,size:int)->void:
\tvar path:String="res://assets/ui/odyssey_sigil.svg"
\tif not ResourceLoader.exists(path):return
\tvar icon=TextureRect.new()
\ticon.name="OdysseySigilCoin"
\ticon.texture=load(path)
\ticon.position=where
\ticon.size=Vector2(size,size)
\ticon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
\ticon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
\ticon.mouse_filter=Control.MOUSE_FILTER_IGNORE
\tparent.add_child(icon)

func _buy_sigil_cottage_style(slot:String,variant:String)->bool:
\t_ensure_home_styles()
\tif not SIGIL_COTTAGE_ART.has(slot):return false
\tvar catalog:Dictionary=SIGIL_COTTAGE_ART[slot]
\tif not catalog.has(variant):return false
\tvar offer:Dictionary=catalog[variant]
\t# Only enable purchases of completed transparent sprites, NEVER placeholders.
\tvar sprite_path:String="res://assets/home/%s/%s.png" % [str(offer["folder"]),variant]
\tif not ResourceLoader.exists(sprite_path):return false
\tif data["home_owned"][slot].has(variant):
\t\tdata["home_styles"][slot]=variant
\telse:
\t\tif not _spend_sigils(int(offer["price"])):return false
\t\tdata["home_owned"][slot].append(variant)
\t\tdata["home_styles"][slot]=variant
\tif bedroom_art!=null and is_instance_valid(bedroom_art):
\t\tbedroom_art.call("apply_styles",data["home_styles"])
\t_save()
\treturn true
'''
path.write_text(s,encoding="utf8")
print("AO SIGILS PATCH OK: separate saved currency, coin UI, once-only rewards, art-gated cottage unlocks.")
