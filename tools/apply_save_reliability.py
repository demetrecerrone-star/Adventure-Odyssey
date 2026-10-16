#!/usr/bin/env python3
"""Final reconstruction overlay: safe saves and accurate progression feedback."""
from pathlib import Path
p=Path('scripts/game.gd')
s=p.read_text()
if 'func _normalized_save(' in s:
    print('AO SAVE RELIABILITY OVERLAY: ALREADY APPLIED')
    raise SystemExit(0)
s=s.replace('func _random_default() -> void:\n\tdata = ', 'func _random_default() -> void:\n\tdata = _default_character()\n\nfunc _default_character()->Dictionary:\n\treturn ',1)
start=s.index('func _save()')
end=s.index('func _clear_ui()',start)
s=s[:start]+Path('tools/save_reliability.gd.txt').read_text()+'\n'+s[end:]
def replace(old,new):
    global s
    assert s.count(old)==1, (old,s.count(old))
    s=s.replace(old,new,1)
replace('var hp_label: Label','var hp_label: Label\nvar character_label: Label')
replace('\t_label(hud,stat_line,37,16,705,34,24)','\tcharacter_label=_label(hud,stat_line,37,16,705,34,24)')
replace('func _refresh_hud()->void:\n','func _refresh_hud()->void:\n\tif character_label!=null and is_instance_valid(character_label):\n\t\tcharacter_label.text="%s  |  %s  |  Lv %d" % [data["name"],data["class"],int(data["level"])]\n')
replace('\t\tprompt.text="ATTACK: Green Slime %d/%d HP" % [maxi(0,int(target["hp"])),int(target["max_hp"])] if not target.is_empty() else "Approach a slime to attack  |  West: Elmwatch"','\t\tprompt.text=_combat_target_prompt(target)')
replace('\t\t"forest":\n\t\t\tif int(data.get("quest_kills",0))>=3:', '\t\t"forest":\n\t\t\tif bool(data.get("guild_training_completed",false)):\n\t\t\t\treturn "Guild training complete. Explore Thornbrook; Oldstone lies east."\n\t\t\tif int(data.get("quest_kills",0))>=3:')
replace('func _quit_game() -> void:\n\tget_tree().quit()','func _quit_game() -> void:\n\t_save_active_character()\n\tget_tree().quit()')
p.write_text(s)
print('AO SAVE RELIABILITY OVERLAY: PASS')
