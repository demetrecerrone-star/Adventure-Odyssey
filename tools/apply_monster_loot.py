#!/usr/bin/env python3
"""Creature-specific rewards on the existing XP/gold/inventory economy.

Apply AFTER world_expansion.py and item_art.py. Do not modify the archived
source; no new save fields or currency denominations are required.
"""
from pathlib import Path

p=Path("scripts/game.gd")
s=p.read_text(encoding="utf8")
def rep(old,new):
    global s
    hits=s.count(old)
    if hits!=1:
        raise SystemExit(f"AO LOOT PATCH ANCHOR FAILED ({hits}): {old[:110]!r}")
    s=s.replace(old,new,1)

# The world expansion kill path has the loot reward in exactly one place.
rep('\t\t_award_gear_material(species)',
    '\t\tvar loot_summary:Dictionary=_award_monster_loot(best)')
rep('\t\tdata["gold"]=int(data["gold"])+int(best.get("gold",3))',
    '''\t\tvar total_gold:int=int(best.get("gold",3))+int(loot_summary.get("bonus_gold",0))
\t\tdata["gold"]=int(data["gold"])+total_gold
\t\t_combat_popup(best["node"].position+Vector2(0,-40),"+%d GOLD" % total_gold,Color("#f6d782"))
\t\tfor item_name in loot_summary.get("items",{}).keys():
\t\t\t_combat_popup(best["node"].position+Vector2(0,-62),"+%d %s" % [int(loot_summary["items"][item_name]),str(item_name)],Color("#acd9b1"))
\t\tif int(loot_summary.get("sigils",0))>0:
\t\t\t_combat_popup(best["node"].position+Vector2(0,-82),"+1 SIGIL!",Color("#72b9ff"))''')
rep('''\t\t\t_record_expedition_kill(species)
\t\t\tvar drop:String=str(best.get("drop",""))
\t\t\tif drop!="":
\t\t\t\tdata["inventory"][drop]=int(data["inventory"].get(drop,0))+1''',
    '''\t\t\t_record_expedition_kill(species)''')

# Keep material-selling inside the existing paginated backpack, not
# a new shop UI or currency/account system. Only whitelisted materials sell.
rep('''\t\telif GEAR_MATERIAL_NAMES.has(item):
\t\t\t_label(popup,"Material",900,y+10,175,33,18,Color("#9ad9b5"))''',
'''\t\telif MONSTER_MATERIAL_SELL_VALUES.has(item):
\t\t\t_button(popup,"SELL 1: %d G" % int(MONSTER_MATERIAL_SELL_VALUES[item]),898,y+6,192,44,_sell_monster_material.bind(item))
\t\telif GEAR_MATERIAL_NAMES.has(item):
\t\t\t_label(popup,"Material",900,y+10,175,33,18,Color("#9ad9b5"))''')

s+='''
# -- Field loot, material trade-in, and anti-duplicate reward accounting -------
# Each enemy retains its existing guaranteed base gold and EXP. The additional
# random coins and items are rolled ONCE on defeat, independent of damage type.
# Drop probabilities and merchant sale values are early balance targets.
const MONSTER_LOOT_PROFILES={
    # Every roll is independent per actual kill, including first kills.
    # Zero kill-count thresholds or escalating pity for ultra-rare gear.
    "slime":{"coin_bonus":[0,2],"sigil_chance":0.005,"rolls":[["Slime Gel",0.35],["Health Potion",0.06],["Slime Core Charm",0.0025]]},
    "wolf":{"coin_bonus":[0,3],"sigil_chance":0.0075,"rolls":[["Beast Hide",0.55],["Health Potion",0.08],["Forest Fang",0.0035]]},
    "goblin":{"coin_bonus":[0,4],"sigil_chance":0.0075,"rolls":[["Iron Ore",0.30],["Health Potion",0.10],["Guard Sigil",0.0025]]},
    "fungus":{"coin_bonus":[0,2],"sigil_chance":0.006,"rolls":[["Enchanted Thread",0.45],["Health Potion",0.09],["Wisdom Bead",0.003]]},
    "guardian":{"coin_bonus":[8,16],"sigil_chance":0.0,"rolls":[["Ember Pendant",0.03]]}
}
const MONSTER_MATERIAL_SELL_VALUES={
    "Slime Gel":2,"Wolf Pelt":4,"Beast Hide":5,"Iron Ore":7,
    "Herb":3,"Enchanted Thread":6,"Ember Shard":24
}

func _loot_add_item(items:Dictionary,item:String,amount:int=1)->void:
    if item.is_empty() or amount<=0:return
    items[item]=int(items.get(item,0))+amount
    data["inventory"][item]=int(data["inventory"].get(item,0))+amount

func _award_monster_loot(mob:Dictionary,forced_rolls:Dictionary={})->Dictionary:
    # Guard both the live kill path and direct reward calls against duplication.
    if bool(mob.get("loot_claimed",false)):
        return {"bonus_gold":0,"items":{},"sigils":0}
    mob["loot_claimed"]=true
    _ensure_gear()
    var species:String=str(mob.get("species","slime"))
    var profile:Dictionary=MONSTER_LOOT_PROFILES.get(species,MONSTER_LOOT_PROFILES["slime"])
    var coin_bounds:Array=profile["coin_bonus"]
    var coin_bonus:int=randi_range(int(coin_bounds[0]),int(coin_bounds[1]))
    if forced_rolls.has("bonus_gold"):
        coin_bonus=clampi(int(forced_rolls["bonus_gold"]),int(coin_bounds[0]),int(coin_bounds[1]))
    var items:Dictionary={}
    # Retain guaranteed beginner and crafting drops already present in AO.
    var guaranteed:String=str(mob.get("drop",""))
    if not guaranteed.is_empty():
        _loot_add_item(items,guaranteed)
    # Existing third-slime material cadence remains reliable for early crafting.
    if species=="slime" and int(data.get("quest_kills",0))%3==2:
        _loot_add_item(items,"Slime Gel")
    if species=="guardian":
        _loot_add_item(items,"Ember Shard")
    for entry in profile["rolls"]:
        var item:String=str(entry[0])
        var chance:float=float(entry[1])
        # Distinct RNG draw for every entry: a 0.25% drop can occur on kill 1.
        var roll:float=float(forced_rolls.get(item,randf()))
        if roll<chance:
            _loot_add_item(items,item)
    var sigils:int=0
    var sigil_chance:float=float(profile.get("sigil_chance",0.0))
    if sigil_chance>0.0 and float(forced_rolls.get("sigil_roll",randf()))<sigil_chance:
        sigils=1
        data["sigils"]=maxi(0,int(data.get("sigils",0)))+sigils
    return {"bonus_gold":coin_bonus,"items":items,"sigils":sigils}

func _sell_monster_material(item:String)->void:
    _ensure_gear()
    if not MONSTER_MATERIAL_SELL_VALUES.has(item):
        return
    var owned:int=int(data["inventory"].get(item,0))
    if owned<=0:
        return
    if owned==1:
        data["inventory"].erase(item)
    else:
        data["inventory"][item]=owned-1
    data["gold"]=int(data.get("gold",0))+int(MONSTER_MATERIAL_SELL_VALUES[item])
    _save()
    _refresh_hud()
    _open_item_inventory()
'''
# The historical game script uses tabs; keep appended GDScript in that style.
marker="\n# -- Field loot, material trade-in, and anti-duplicate reward accounting -------"
assert s.count(marker)==1
prefix,gd=s.split(marker,1)
gd=marker+gd
lines=[]
for line in gd.split("\n"):
    spaces=len(line)-len(line.lstrip(" "))
    if spaces and spaces%4:
        raise SystemExit("AO LOOT INDENTATION: unexpected mixed indentation")
    lines.append("\t"*(spaces//4)+line[spaces:])
s=prefix+"\n".join(lines)
p.write_text(s,encoding="utf8")
print("AO MONSTER LOOT: PASS / creature tables, gold rewards, material sales, single-claim protection")
