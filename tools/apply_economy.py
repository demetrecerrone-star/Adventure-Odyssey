#!/usr/bin/env python3
"""Functional Elmwatch traders, unrestricted gear, proficiency and item upgrades."""
from pathlib import Path
p=Path("scripts/game.gd")
s=p.read_text(encoding="utf-8")
def rep(before,after):
    global s
    n=s.count(before)
    if n!=1:raise SystemExit(f"ECONOMY PATCH ANCHOR FAILED ({n}): {before[:110]!r}")
    s=s.replace(before,after,1)

rep('''	_button(hud,"QUEST JOURNAL",781,209,218,44,_open_quest_journal)
	if _has_mentor_skill():''',
'''	_button(hud,"QUEST JOURNAL",781,209,218,44,_open_quest_journal)
	_button(hud,"EQUIPMENT",781,261,218,44,_open_gear_menu)
	if _has_mentor_skill():''')

rep('''	# The first eighteen are always usable. Training teaches a fourth skill.
	if who==_skill_mentor()''',
'''	# Existing NPC dialogue stays available; trade is a separate action.
	if who=="Mara Fenwick":
		_show_npc_chat(n,"Supplies and curiosities for every class! Ask to trade when you're ready.")
		_add_trade_action("MARKET",_open_shop.bind("market"))
		return
	if who=="Brann Ironhand":
		_show_npc_chat(n,"Every adventurer can equip any weapon or armor. Trade or upgrade your favorite gear.")
		_add_trade_action("BLACKSMITH",_open_shop.bind("blacksmith"))
		return
	if who=="Tamsin Reed":
		_show_npc_chat(n,"Welcome to the Lantern Inn! A warm bed and meal restore you for 4 gold.")
		_add_trade_action("REST: 4 GOLD",_rest_at_inn)
		return
	# The first eighteen are always usable. Training teaches a fourth skill.
	if who==_skill_mentor()''')

rep('''	var dmg=8+int(int(data["stats"]["Strength"]) / 2)
	if battle_cry_timer>0.0:dmg+=6''',
'''	_record_weapon_proficiency()
	var dmg=8+int(int(data["stats"]["Strength"]) / 2)+_gear_attack()
	if battle_cry_timer>0.0:dmg+=6''')

rep('''	if float(best.get("mentor_mark_timer",0.0))>0.0:dmg+=8
	best["hp"]''',
'''	if float(best.get("mentor_mark_timer",0.0))>0.0:dmg+=8
	if skill_hit:dmg+=int(_gear_attack()/2)
	best["hp"]''')

rep('''		var next=player.position+axis*240.0*delta''',
'''		var next=player.position+axis*240.0*_gear_movement_factor()*delta''')
rep('''		_combat_popup(player.position,"-5 HP",Color("#ff9a98"))
		data["hp"]=maxi(0,int(data["hp"])-5)''',
'''		var taken:int=maxi(1,5-_gear_defense())
		_combat_popup(player.position,"-%d HP" % taken,Color("#ff9a98"))
		data["hp"]=maxi(0,int(data["hp"])-taken)''')
rep('''		hint_label.text="A slime strikes! -5 HP"''','''		hint_label.text="A slime strikes! -%d HP" % taken''')

s+=r'''
# -- Unrestricted equipment, persistent proficiency and real Elmwatch shops ----
# Items have trade-offs; class and stat restrictions are intentionally absent.
const ITEM_CATALOG={
	"Training Sword":{"slot":"weapon","kind":"sword","power":0,"defense":0,"price":0,"rarity":"Common"},
	"Iron Axe":{"slot":"weapon","kind":"axe","power":7,"defense":0,"price":42,"rarity":"Common"},
	"Oak Bow":{"slot":"weapon","kind":"bow","power":5,"defense":0,"price":35,"rarity":"Common"},
	"Traveler Robe":{"slot":"armor","kind":"cloth","power":1,"defense":1,"price":19,"rarity":"Common"},
	"Leather Vest":{"slot":"armor","kind":"leather","power":0,"defense":2,"price":33,"rarity":"Common"},
	"Iron Plate":{"slot":"armor","kind":"plate","power":0,"defense":3,"price":65,"rarity":"Uncommon"},
	"Copper Ring":{"slot":"accessory","kind":"ring","power":2,"defense":0,"price":24,"rarity":"Common"},
	"Silver Charm":{"slot":"accessory","kind":"charm","power":0,"defense":2,"price":45,"rarity":"Uncommon"},
	"Forest Fang":{"slot":"weapon","kind":"dagger","power":8,"defense":0,"price":70,"rarity":"Uncommon"},
	"Guardian Relic":{"slot":"accessory","kind":"relic","power":5,"defense":3,"price":150,"rarity":"Rare"}
}
const MARKET_STOCK=["Health Potion","Traveler Robe","Leather Vest","Copper Ring","Silver Charm"]
const FORGE_STOCK=["Iron Axe","Oak Bow","Iron Plate","Leather Vest","Health Potion"]

func _ensure_gear()->void:
	if typeof(data.get("equipment",null))!=TYPE_DICTIONARY:data["equipment"]={}
	if typeof(data.get("proficiency",null))!=TYPE_DICTIONARY:data["proficiency"]={}
	if typeof(data.get("equipment_upgrades",null))!=TYPE_DICTIONARY:data["equipment_upgrades"]={}
	if typeof(data.get("inventory",null))!=TYPE_DICTIONARY:data["inventory"]={}

func _gear_def(item:String)->Dictionary:
	return ITEM_CATALOG.get(item,{})

func _equipped(slot:String)->String:
	_ensure_gear()
	return str(data["equipment"].get(slot,""))

func _gear_attack()->int:
	_ensure_gear()
	var bonus:int=0
	for slot in ["weapon","armor","accessory"]:
		var item:String=_equipped(slot)
		var defn:Dictionary=_gear_def(item)
		bonus+=int(defn.get("power",0))
		bonus+=int(data["equipment_upgrades"].get(item,0))*2
	var weapon:String=_equipped("weapon")
	var kind:String=str(_gear_def(weapon).get("kind","unarmed"))
	bonus+=int(int(data["proficiency"].get(kind,0))/20)
	return bonus

func _gear_defense()->int:
	_ensure_gear()
	var defense:int=0
	for slot in ["armor","accessory"]:
		defense+=int(_gear_def(_equipped(slot)).get("defense",0))
	return defense

func _gear_movement_factor()->float:
	return 0.88 if _equipped("armor")=="Iron Plate" else 1.0

func _record_weapon_proficiency()->void:
	_ensure_gear()
	var kind:String=str(_gear_def(_equipped("weapon")).get("kind","unarmed"))
	data["proficiency"][kind]=mini(500,int(data["proficiency"].get(kind,0))+1)
	_save()

func _equip_item(item:String)->void:
	_ensure_gear()
	var definition:Dictionary=_gear_def(item)
	if definition.is_empty() or int(data["inventory"].get(item,0))<=0:return
	data["equipment"][str(definition["slot"])]=item
	_save()
	_open_gear_menu()

func _unequip_slot(slot:String)->void:
	_ensure_gear()
	data["equipment"].erase(slot)
	_save()
	_open_gear_menu()

func _open_gear_menu()->void:
	_ensure_gear()
	_panel_dialog("EQUIPMENT & PROFICIENCY")
	_label(popup,"Every class may equip EVERY item. Heavy plate reduces movement speed.",164,120,940,35,18,Color("#a9d9eb"))
	var slots=["weapon","armor","accessory"]
	for i in range(slots.size()):
		var slot:String=slots[i]
		var current:String=_equipped(slot)
		var top:int=173+i*86
		_panel(popup,Rect2(164,top,925,76),Color("#273746"))
		_label(popup,slot.to_upper(),185,top+5,205,33,21,Color("#efce85"))
		_label(popup,current if current!="" else "Empty",401,top+5,465,33,22)
		if current!="":
			_button(popup,"REMOVE",906,top+10,158,49,_unequip_slot.bind(slot))
	_label(popup,"Available equipment in your backpack",168,444,890,37,22,Color("#efce85"))
	var n:int=0
	for item in data["inventory"].keys():
		if n>=4:break
		var definition:Dictionary=_gear_def(str(item))
		if definition.is_empty() or int(data["inventory"][item])<=0:continue
		var x:int=172+(n%2)*467
		var y:int=498+int(n/2)*58
		_button(popup,"EQUIP "+str(item).to_upper(),x,y,446,50,_equip_item.bind(str(item)))
		n+=1
	_label(popup,"Weapon proficiency improves naturally as you use weapons.",181,628,800,25,17,Color("#bad5e2"))

func _add_trade_action(button_text:String,handler:Callable)->void:
	if popup==null or not is_instance_valid(popup):return
	_button(popup,button_text,563,638,193,52,handler)

func _shop_items(shop:String)->Array:
	return MARKET_STOCK if shop=="market" else FORGE_STOCK

func _shop_price(item:String)->int:
	return 9 if item=="Health Potion" else int(_gear_def(item).get("price",0))

func _open_shop(shop:String)->void:
	_ensure_gear()
	_panel_dialog("ELMWATCH %s" % ("MARKET" if shop=="market" else "BLACKSMITH"))
	_label(popup,"Gold: %d  |  Buying and selling use earned game currency." % int(data.get("gold",0)),165,119,950,40,21,Color("#ffdf97"))
	var stock:Array=_shop_items(shop)
	for i in range(stock.size()):
		var item:String=str(stock[i])
		var y:int=178+i*82
		_panel(popup,Rect2(158,y,956,72),Color("#253949"))
		_label(popup,item,174,y+8,476,32,21)
		_label(popup,"%d gold  /  owned %d" % [_shop_price(item),int(data["inventory"].get(item,0))],620,y+9,226,28,18,Color("#d5c394"))
		_button(popup,"BUY",876,y+7,102,49,_buy_item.bind(shop,item))
		_button(popup,"SELL",988,y+7,110,49,_sell_item.bind(shop,item))
	if shop=="blacksmith":
		_button(popup,"UPGRADE EQUIPPED WEAPON",429,590,434,52,_forge_weapon)
		_label(popup,"Upgrade costs 35 gold + 2 Iron Ore; max level +3.",310,643,711,23,16)

func _buy_item(shop:String,item:String)->void:
	if not _shop_items(shop).has(item):return
	var cost:int=_shop_price(item)
	if cost<=0 or int(data.get("gold",0))<cost:
		_message("You need %d gold to buy %s." % [cost,item])
		return
	data["gold"]=int(data["gold"])-cost
	data["inventory"][item]=int(data["inventory"].get(item,0))+1
	_save()
	_refresh_hud()
	_open_shop(shop)

func _sell_item(shop:String,item:String)->void:
	if not _shop_items(shop).has(item):return
	if item==_equipped("weapon") or item==_equipped("armor") or item==_equipped("accessory"):
		_message("Unequip this item before selling it.")
		return
	if int(data["inventory"].get(item,0))<=0:return
	data["inventory"][item]=int(data["inventory"][item])-1
	if int(data["inventory"][item])<=0:data["inventory"].erase(item)
	data["gold"]=int(data["gold"])+maxi(1,int(_shop_price(item)/2))
	_save()
	_refresh_hud()
	_open_shop(shop)

func _forge_weapon()->void:
	_ensure_gear()
	var weapon:String=_equipped("weapon")
	if weapon=="":
		_message("Equip a weapon before visiting the forge.")
		return
	var rank:int=int(data["equipment_upgrades"].get(weapon,0))
	if rank>=3:
		_message("This weapon has reached its current upgrade limit.")
		return
	if int(data["gold"])<35 or int(data["inventory"].get("Iron Ore",0))<2:
		_message("Forging needs 35 gold and 2 Iron Ore from tougher enemies.")
		return
	data["gold"]=int(data["gold"])-35
	data["inventory"]["Iron Ore"]=int(data["inventory"]["Iron Ore"])-2
	data["equipment_upgrades"][weapon]=rank+1
	_save()
	_refresh_hud()
	_open_shop("blacksmith")

func _rest_at_inn()->void:
	if int(data.get("gold",0))<4:
		_message("A meal and bed cost 4 gold. Come back when you have enough.")
		return
	data["gold"]=int(data["gold"])-4
	data["hp"]=int(data["max_hp"])
	data["world_minutes"]=fposmod(float(data.get("world_minutes",540.0))+480.0,1440.0)
	_save()
	_refresh_hud()
	_message("You enjoyed a warm meal and rested. HP restored; eight in-game hours have passed.")
'''
p.write_text(s,encoding="utf-8")
print("AO ECONOMY PATCH OK: unrestricted gear, proficiency, shops, forge and inn.")
