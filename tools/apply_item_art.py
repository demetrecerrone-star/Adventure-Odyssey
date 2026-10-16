#!/usr/bin/env python3
"""Adventure Odyssey: integrate original concept-derived item art and expanded gear.
Run after apply_economy.py and apply_world_expansion.py. Original compass untouched.
"""
from pathlib import Path
p=Path('scripts/game.gd')
s=p.read_text(encoding='utf8')
def rep(before,after):
 global s
 n=s.count(before)
 if n!=1:raise SystemExit(f'ITEM ART ANCHOR FAILED ({n}): {before[:140]!r}')
 s=s.replace(before,after,1)
def between(a,b,replacement):
 global s
 begin=s.find(a);end=s.find(b,begin)
 if begin<0 or end<0 or s.find(a,begin+1)>=0:raise SystemExit(f'ITEM ART SECTION NOT UNIQUE: {a[:90]}')
 s=s[:begin]+replacement+s[end:]

WEAPONS={
 'Rusted Sword':('sword',2,9),'Training Sword':('sword',0,0),'Iron Sword':('sword',5,44),
 'Iron Axe':('axe',7,42),'Oak Bow':('bow',5,35),'Hunter Bow':('bow',8,73),
 'Apprentice Staff':('staff',5,39),'Ember Staff':('staff',9,105),
 'Bronze Dagger':('dagger',4,27),'Forest Fang':('dagger',8,70),
 'Pilgrim Mace':('mace',6,51),'Guard Spear':('spear',8,82)
}
ARMOR={
 'Traveler Tunic':('armor',1,14),'Traveler Robe':('armor',1,19),
 'Leather Vest':('armor',2,33),'Leather Hood':('head',1,22),
 'Iron Chainmail':('armor',3,59),'Iron Plate':('armor',4,65),
 'Apprentice Robe':('armor',2,48),'Reinforced Jerkin':('armor',3,79),
 'Guard Breastplate':('armor',5,115),'Forest Cloak':('cloak',2,64),
 'Padded Gloves':('gloves',1,26),'Steel Boots':('boots',2,48)
}
ACCESSORIES={
 'Copper Ring':(2,0,24),'Silver Ring':(0,2,32),
 'Vitality Charm':(0,3,55),'Wisdom Bead':(3,0,52),
 "Hunter's Band":(3,1,67),'Ember Pendant':(5,0,97),
 'Guard Sigil':(0,4,88),'Moon Brooch':(1,2,75),
 'Slime Core Charm':(1,3,68),'Guardian Relic':(5,3,150)
}
MATERIALS=['Iron Ore','Beast Hide','Enchanted Thread','Slime Gel','Ember Shard']
records=[]
for name,(kind,power,price) in WEAPONS.items():
 rarity='Rare' if name in ['Ember Staff','Guard Spear'] else ('Uncommon' if price>=65 else 'Common')
 records.append((name,{'slot':'weapon','kind':kind,'power':power,'defense':0,'price':price,'rarity':rarity}))
for name,(slot,defense,price) in ARMOR.items():
 rarity='Rare' if name=='Guard Breastplate' else ('Uncommon' if price>=50 else 'Common')
 records.append((name,{'slot':slot,'kind':('plate' if 'Plate' in name or 'Breastplate' in name else 'cloth' if 'Robe' in name or 'Tunic' in name else 'leather'), 'power':0,'defense':defense,'price':price,'rarity':rarity}))
for name,(power,defense,price) in ACCESSORIES.items():
 rarity='Rare' if name in ('Guardian Relic','Ember Pendant') else ('Uncommon' if price>=52 else 'Common')
 records.append((name,{'slot':'accessory','kind':'charm','power':power,'defense':defense,'price':price,'rarity':rarity}))
import json
catalog='const ITEM_CATALOG={\n'+',\n'.join('\t'+json.dumps(k)+':'+json.dumps(v) for k,v in records)+'\n}\n'
# Legacy 10 records remain compatible. Every approved illustrated equip item is now a real game entry.
between('const ITEM_CATALOG={\n','const MARKET_STOCK=',catalog)
market=['Health Potion','Traveler Tunic','Traveler Robe','Leather Vest','Apprentice Robe','Leather Hood','Forest Cloak','Padded Gloves','Copper Ring','Silver Ring','Vitality Charm','Wisdom Bead',"Hunter's Band",'Moon Brooch','Slime Core Charm','Oak Bow','Bronze Dagger','Apprentice Staff']
forge=['Rusted Sword','Iron Sword','Iron Axe','Hunter Bow','Ember Staff','Pilgrim Mace','Guard Spear','Iron Chainmail','Iron Plate','Reinforced Jerkin','Guard Breastplate','Steel Boots','Guard Sigil','Ember Pendant','Health Potion']
rep('const MARKET_STOCK=["Health Potion","Traveler Robe","Leather Vest","Copper Ring","Silver Charm"]','const MARKET_STOCK='+json.dumps(market))
rep('const FORGE_STOCK=["Iron Axe","Oak Bow","Iron Plate","Leather Vest","Health Potion"]','const FORGE_STOCK='+json.dumps(forge))
# Preserve existing backpack UI entrance and implement a paginated, image-rich bag.
rep('func _open_menu(menu:String)->void:\n\tif popup!=null and is_instance_valid(popup):return',
'''func _open_menu(menu:String)->void:
	if menu=="inventory":
		_open_item_inventory()
		return
	if popup!=null and is_instance_valid(popup):return''')
# Weapon, clothing and accessories all contribute stats, with no class limits.
rep('for slot in ["weapon","armor","accessory"]:',
    'for slot in ["weapon","armor","head","cloak","gloves","boots","accessory"]:')
rep('for slot in ["armor","accessory"]:',
    'for slot in ["armor","head","cloak","gloves","boots","accessory"]:')
rep('return 0.88 if _equipped("armor")=="Iron Plate" else 1.0',
'''return 0.88 if _equipped("armor") in ["Iron Plate","Guard Breastplate"] else (0.94 if _equipped("armor")=="Iron Chainmail" else 1.0)''')
# Treat truly worn slots equally when selling (no duping equipped objects).
rep('if item==_equipped("weapon") or item==_equipped("armor") or item==_equipped("accessory"):',
    'if item in data["equipment"].values():')
# Two-page item selectors; retain existing _equip_item and _unequip_slot save behavior.
between('func _open_gear_menu()->void:\n','func _add_trade_action(','''func _open_gear_menu()->void:
	_ensure_gear()
	_panel_dialog("EQUIPMENT & PROFICIENCY")
	_label(popup,"Unrestricted equipment  •  Heavy plate slows movement",159,116,960,30,19,Color("#bddfee"))
	var slots=["weapon","armor","head","cloak","gloves","boots","accessory"]
	for i in range(slots.size()):
		var slot:String=slots[i]
		var current:String=_equipped(slot)
		var x:int=147+(i%2)*492
		var y:int=155+int(i/2)*86
		_panel(popup,Rect2(x,y,471,77),Color("#283b4d"))
		_label(popup,slot.to_upper(),x+74,y+5,160,26,17,Color("#efce85"))
		_label(popup,current if current!="" else "Empty",x+73,y+34,262,31,18)
		if current!="":
			_item_icon(popup,current,Vector2(x+8,y+9),58)
			_button(popup,"X",x+414,y+13,42,49,_unequip_slot.bind(slot))
	_label(popup,"BACKPACK EQUIPMENT",164,501,540,35,22,Color("#efce85"))
	var items:Array=[]
	for item in data["inventory"].keys():
		if int(data["inventory"][item])>0 and not _gear_def(str(item)).is_empty():items.append(str(item))
	items.sort()
	var pages:int=maxi(1,int(ceil(float(items.size())/4.0)))
	gear_bag_page=clampi(gear_bag_page,0,pages-1)
	for k in range(4):
		var index:int=gear_bag_page*4+k
		if index>=items.size():break
		var item:String=items[index]
		var x:int=166+(k%2)*479
		var y:int=541+int(k/2)*53
		_button(popup,"EQUIP  "+item.to_upper(),x,y,446,47,_equip_item.bind(item))
		_item_icon(popup,item,Vector2(x+4,y+3),42)
	if pages>1:
		_button(popup,"<",734,496,50,36,_change_gear_page.bind(-1))
		_label(popup,"%d/%d" % [gear_bag_page+1,pages],793,500,68,32,18)
		_button(popup,">",871,496,50,36,_change_gear_page.bind(1))

''')
# Paging the expanded market while retaining previous prices, buying and selling.
between('func _open_shop(shop:String)->void:\n','func _buy_item(','''func _open_shop(shop:String)->void:
	_ensure_gear()
	_panel_dialog("ELMWATCH %s" % ("MARKET" if shop=="market" else "BLACKSMITH"))
	_label(popup,"Gold: %d   •   Items use earned in-game currency" % int(data.get("gold",0)),163,118,950,37,20,Color("#ffdf97"))
	var stock:Array=_shop_items(shop)
	var pages:int=maxi(1,int(ceil(float(stock.size())/5.0)))
	gear_shop_page=clampi(gear_shop_page,0,pages-1)
	for k in range(5):
		var index:int=gear_shop_page*5+k
		if index>=stock.size():break
		var item:String=str(stock[index])
		var y:int=166+k*82
		_panel(popup,Rect2(154,y,962,72),Color("#263a4b"))
		_item_icon(popup,item,Vector2(162,y+5),60)
		_label(popup,item,233,y+4,490,32,21)
		_label(popup,"%d gold  |  owned %d" % [_shop_price(item),int(data["inventory"].get(item,0))],237,y+38,385,27,17,Color("#d5c394"))
		_button(popup,"BUY",882,y+8,101,49,_buy_item.bind(shop,item))
		_button(popup,"SELL",989,y+8,111,49,_sell_item.bind(shop,item))
	_button(popup,"< PREV",419,588,160,42,_shop_page.bind(shop,-1))
	_label(popup,"PAGE %d / %d" % [gear_shop_page+1,pages],595,593,155,29,19,Color("#efce85"))
	_button(popup,"NEXT >",773,588,160,42,_shop_page.bind(shop,1))
	if shop=="blacksmith":
		_button(popup,"FORGE EQUIPPED WEAPON",448,636,404,38,_forge_weapon)

''')
# Old monster loot remains valid. New drawn materials now enter gameplay too.
rep('''		var species:String=str(best.get("species","slime"))
		data["xp"]''', '''		var species:String=str(best.get("species","slime"))
		_award_gear_material(species)
		data["xp"]''')
rep('''	if hero_class in ["Warrior","Ranger","Mage","Necromancer"] and targets.is_empty():''',
'''\tif hero_class in ["Warrior","Ranger","Mage","Necromancer"] and targets.is_empty():''') if False else None
s=s.replace('var gear_shop_page:', 'var gear_shop_page:')
# New state variables remain nonpersistent as only current menu page selection.
rep('var mentor_skill_cooldown:float=0.0', '''var gear_shop_page:int=0
var gear_bag_page:int=0
var gear_inventory_page:int=0
var mentor_skill_cooldown:float=0.0''')
s+='''
# -- Original 2026 Adventure Odyssey equipment sheet integration ------------
const GEAR_MATERIAL_NAMES=["Iron Ore","Beast Hide","Enchanted Thread","Slime Gel","Ember Shard"]

func _item_icon(parent:Control,item:String,at:Vector2,side:int)->void:
	var path:String="res://assets/items/%s.svg" % item.to_lower().replace("'","").replace(" ","_")
	if not ResourceLoader.exists(path):return
	var node=TextureRect.new()
	node.texture=load(path)
	node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	node.position=at
	node.size=Vector2(side,side)
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.name="ItemIcon_"+item.to_lower().replace(" ","_").replace("'","")
	parent.add_child(node)

func _change_gear_page(delta:int)->void:
	gear_bag_page=maxi(0,gear_bag_page+delta)
	_open_gear_menu()

func _shop_page(shop:String,delta:int)->void:
	gear_shop_page=maxi(0,gear_shop_page+delta)
	_open_shop(shop)

func _change_inventory_page(delta:int)->void:
	gear_inventory_page=maxi(0,gear_inventory_page+delta)
	_open_item_inventory()

func _open_item_inventory()->void:
	_ensure_gear()
	_panel_dialog("ADVENTURER'S BACKPACK")
	_label(popup,"Gold: %d   •   Collected supplies and equipment" % int(data.get("gold",0)),159,119,935,34,21,Color("#ffdf97"))
	var items:Array=[]
	for entry in data["inventory"].keys():
		if int(data["inventory"][entry])>0:items.append(str(entry))
	items.sort()
	var pages:int=maxi(1,int(ceil(float(items.size())/7.0)))
	gear_inventory_page=clampi(gear_inventory_page,0,pages-1)
	for row in range(7):
		var index:int=gear_inventory_page*7+row
		if index>=items.size():break
		var item:String=items[index]
		var y:int=164+row*63
		_panel(popup,Rect2(154,y,954,58),Color("#273949"))
		_item_icon(popup,item,Vector2(169,y+4),49)
		_label(popup,"%s  x%d" % [item,int(data["inventory"][item])],238,y+8,610,38,23)
		var item_data:Dictionary=_gear_def(item)
		if not item_data.is_empty():
			_label(popup,str(item_data.get("rarity","Common")),900,y+10,175,33,18,Color("#efce85"))
		elif GEAR_MATERIAL_NAMES.has(item):
			_label(popup,"Material",900,y+10,175,33,18,Color("#9ad9b5"))
	_button(popup,"< PREV",305,614,148,41,_change_inventory_page.bind(-1))
	_label(popup,"PAGE %d/%d" % [gear_inventory_page+1,pages],468,617,178,37,18)
	_button(popup,"NEXT >",645,614,150,41,_change_inventory_page.bind(1))
	_button(popup,"USE POTION",816,614,257,41,_use_potion)

func _award_gear_material(species:String)->void:
	_ensure_gear()
	var item:String=""
	match species:
		"slime":
			if int(data.get("quest_kills",0))%3==2:item="Slime Gel"
		"wolf":item="Beast Hide"
		"fungus":item="Enchanted Thread"
		"guardian":item="Ember Shard"
	if item!="":data["inventory"][item]=int(data["inventory"].get(item,0))+1
'''
p.write_text(s,encoding='utf8')
print('ITEM ART PATCH OK: 39 original-derived item icons, catalog, bag, trade paging, equipment and materials')