#!/usr/bin/env python3
"""Replace duplicated/tinted mentor NPC sprites with independent directional art."""
from pathlib import Path
p=Path("scripts/game.gd")
s=p.read_text(encoding="utf-8")
def rep(a,b):
    global s
    n=s.count(a)
    if n!=1:raise SystemExit(f"MENTOR ART PATCH ANCHOR FAILED ({n}): {a[:120]!r}")
    s=s.replace(a,b,1)

rep('''	var sprite_path:String=_sprite_path("npcs",str(npc["variant"]),face,frame)
	if not ResourceLoader.exists(sprite_path):''',
'''	var sprite_path:String=_sprite_path("npcs",str(npc["variant"]),face,frame)
	var named:String=str(npc.get("name",""))
	if named=="Mira Ashwood" or named=="Kael Rook":
		var key:String="mira_ashwood" if named=="Mira Ashwood" else "kael_rook"
		sprite_path="res://assets/npc_custom/%s_%s.svg" % [key,face]
		spr.modulate=Color.WHITE
		spr.position.y=-3.0+sin(phase*10.0)*3.0 if walking else 0.0
	if not ResourceLoader.exists(sprite_path):''')
rep('''	var npc_sprite="res://assets/npcs/%s/down_00.png" % str(n.get("variant",""))
	if str(n.get("routine_state","Working"))''',
'''	var npc_sprite="res://assets/npcs/%s/down_00.png" % str(n.get("variant",""))
	if npc_name=="Mira Ashwood":npc_sprite="res://assets/npc_custom/mira_ashwood_down.svg"
	elif npc_name=="Kael Rook":npc_sprite="res://assets/npc_custom/kael_rook_down.svg"
	if str(n.get("routine_state","Working"))''')
rep('''		elif str(entry[0])=="Kael Rook":
			actor["routine_key"]="kael_rook"
			actor["sprite"].modulate=Color("#ceb8e8")
		npcs.append(actor)''',
'''		elif str(entry[0])=="Kael Rook":
			actor["routine_key"]="kael_rook"
		if str(entry[0]) in ["Mira Ashwood","Kael Rook"]:
			_pose_resident(actor,false,0.0)
		npcs.append(actor)''')
p.write_text(s,encoding="utf-8")
print("AO MENTOR NPC ART PATCH OK: new Mira and Kael directional assets.")
