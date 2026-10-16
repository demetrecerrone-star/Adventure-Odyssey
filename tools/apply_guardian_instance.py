#!/usr/bin/env python3
"""Final overlay after save reliability: personal story clear, then regular boss."""
from pathlib import Path
p = Path('scripts/game.gd')
s = p.read_text()
if '# Guardian story instance exit gate.' in s:
    print('AO GUARDIAN INSTANCE OVERLAY: ALREADY APPLIED')
    raise SystemExit(0)
def replace(old, new):
    global s
    assert s.count(old) == 1, (old, s.count(old))
    s = s.replace(old, new, 1)
replace('func _enter_world(map_name:String,spawn:Vector2)->void:\n', '''func _enter_world(map_name:String,spawn:Vector2)->void:
	# Guardian story instance exit gate. Reloading the cleared sanctum keeps it
	# cleared; entering another room ends this personal story visit.
	if map_name!="sanctum":data.erase("guardian_story_exit_pending")
''')
replace('\t\t\tdata["guardian_defeated"]=true\n', '\t\t\tdata["guardian_defeated"]=true\n\t\t\tdata["guardian_story_exit_pending"]=true\n')
replace('''	if bool(data.get("guardian_defeated",false)):
		if str(data.get("guardian_quest_state",""))!="claimed":return
		if not _guardian_respawn_ready():return
	_oldstone_spawn("guardian","guardian",Vector2(1110,640),300,12,88.0,250,65,"")''', '''	if not _guardian_respawn_ready():return
	for mob in mobs:
		if str(mob.get("species",""))=="guardian" and bool(mob.get("alive",false)):return
	_oldstone_spawn("guardian","guardian",Vector2(1110,640),300,12,88.0,250,65,"")
	mobs.back()["guardian_encounter"]="regular" if bool(data.get("guardian_defeated",false)) else "story"''')
replace('''	if str(data.get("guardian_quest_state",""))!="claimed":return false
	return Time.get_unix_time_from_system()-float(data.get("guardian_last_defeat_unix",Time.get_unix_time_from_system()))>=GUARDIAN_RESPAWN_SECONDS''', '''	if bool(data.get("guardian_story_exit_pending",false)):return false
	# Legacy cleared saves without a timestamp are already eligible. Never
	# restart their cooldown on every check or when claiming the quest.
	return Time.get_unix_time_from_system()-float(data.get("guardian_last_defeat_unix",0.0))>=GUARDIAN_RESPAWN_SECONDS''')
replace('''	if not data.has("guardian_last_defeat_unix"):
		data["guardian_last_defeat_unix"]=Time.get_unix_time_from_system()
''', '')
replace('''	if bool(normalized.get("guardian_defeated",false)) and not normalized.has("guardian_quest_state"):
''', '''	# Existing claim/ready records also prove the story was completed.
	if str(normalized.get("guardian_quest_state","")) in ["ready","claimed"]:
		normalized["guardian_defeated"]=true
	if bool(normalized.get("guardian_defeated",false)) and not normalized.has("guardian_quest_state"):
''')
replace('The Guardian\'s challenge returns 60 seconds after each victory.', 'After leaving the completed story instance, return for the regular Guardian challenge. Its cooldown is 60 seconds after each victory, independent of claiming this reward.')
p.write_text(s)
print('AO GUARDIAN INSTANCE OVERLAY: PASS')
