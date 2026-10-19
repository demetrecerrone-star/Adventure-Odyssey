extends "res://tests/tutorial_save_test.gd"
func run() -> void:
 for selected_class in ["Warrior","Ranger","Mage","Necromancer","Assassin","Paladin"]:
  var state=fixture(selected_class)
  check(state.set_location("starter_region",Vector2(1000,2020)),"Enter wilderness without quest")
  var first=[{"index":0,"generation":0}]
  fail_write(state,func(): return state.record_spawn_defeats("south_meadow_slimes",first,state.combat,1000),"pre-quest kill")
  check(state.record_spawn_defeats("south_meadow_slimes",first,state.combat,1000),"First independent kill")
  check(state.wallet_gold==3 and state.wallet_sigils==1 and state.get_progression_summary().total_xp==10,"First life rewards")
  check(state.progression.population.quest_kills.south_meadow_slimes==0,"No pre-accept quest credit")
  var before=snap(state)
  check(state.record_spawn_defeats("south_meadow_slimes",first,state.combat,2000) and snap(state)==before,"Old incarnation replay cannot pay later")
  check(not state.record_spawn_defeats("south_meadow_slimes",[{"index":0,"generation":1}],state.combat,1024),"Cooldown cannot be skipped")
  check(state.record_spawn_defeats("south_meadow_slimes",[{"index":0,"generation":1}],state.combat,1025),"Next life pays")
  check(state.wallet_gold==6 and state.wallet_sigils==1 and state.get_progression_summary().total_xp==20,"Repeat gives gold/XP, no repeat Sigils")
  var loaded=Save.new(); loaded.path=state.path
  check(loaded.load_saved() and snap(loaded)==snap(state),"Respawn counters and deadline survive reload")
  check(not loaded.spawn_ready("south_meadow_slimes",0,1049) and loaded.spawn_ready("south_meadow_slimes",0,1050),"Reload keeps cooldown")
  var data=snap(state); data.version=12; data.progression= {"version":1,"base_level":1,"kills":state.progression.kills.duplicate(true)}
  data.wallet_gold=3
  write_json(state.path,data)
  check(loaded.load_saved() and loaded.wallet_gold==3 and loaded.wallet_sigils==1,"v12 migration preserves prior reward balances")
  check(loaded.spawn_generation("south_meadow_slimes",0)==1 and loaded.spawn_ready("south_meadow_slimes",0,0),"Legacy cleared monster returns as new life")
  var migrated=snap(loaded)
  check(loaded.load_saved() and snap(loaded)==migrated,"Migration twice adds nothing")
  check(loaded.record_spawn_defeats("south_meadow_slimes",[{"index":0,"generation":1}],loaded.combat,2000),"Migrated repeat remains playable")
  check(loaded.wallet_gold==6 and loaded.wallet_sigils==1,"Migrated repeat never duplicates original Sigil")
 var cooldown=fixture()
 check(cooldown.set_location("starter_region",Vector2(1000,2020)),"Cooldown migration location")
 for group in Save.Rewards.ENCOUNTERS:
  for index in Save.Rewards.ENCOUNTERS[group].count:
   check(cooldown.record_spawn_defeats(group,[{"index":index,"generation":0}],cooldown.combat,1000),"Prepare each paid spawn")
 var old13=snap(cooldown);old13.version=13
 for spawn in old13.progression.population.spawns.values():spawn.ready_at=1045
 write_json(cooldown.path,old13)
 fail_write(cooldown,func():return cooldown.load_saved(),"v13 cooldown migration rollback")
 check(cooldown.load_saved(),"v13 cooldown migration succeeds")
 for group in Save.Rewards.ENCOUNTERS:
  for index in Save.Rewards.ENCOUNTERS[group].count:
   check(not cooldown.spawn_ready(group,index,1024) and cooldown.spawn_ready(group,index,1025),"Existing 45-second deadline becomes 25 seconds")
 check(cooldown.wallet_gold==old13.wallet_gold and cooldown.wallet_sigils==old13.wallet_sigils and cooldown.progression.kills==old13.progression.kills,"Migration changes no rewards or receipts")
 var after14=snap(cooldown)
 check(cooldown.load_saved() and snap(cooldown)==after14,"Deadline shifts only once across reloads")
 check(cooldown.record_spawn_defeats("south_meadow_slimes",[{"index":0,"generation":0}],cooldown.combat,2000) and snap(cooldown)==after14,"Old paid incarnation stays idempotent after timer migration")
 var quest=fixture()
 var weapon: String=Save.Inventory.starter_weapon("Warrior")
 check(quest.transfer(weapon,false) and quest.equip(weapon),"Prepare ordinary starter")
 for action in ["read_envelope","guild_assign_blacksmith","blacksmith_claim_starter","upgrade","guild_after_blacksmith","apothecary_claim_gift","guild_after_apothecary","general_store_claim_keepsake","guild_after_general_store","guild_assign_first_combat"]: take_step(quest,action)
 check(quest.set_location("starter_region",Vector2(1000,2020)),"Accepted assignment outside")
 var legacy_complete=Save.new(); legacy_complete.path="user://respawn_legacy_complete_%d.json" % Time.get_ticks_usec(); paths.append(legacy_complete.path)
 legacy_complete._restore(quest.snapshot())
 check(legacy_complete.save() and legacy_complete.record_enemy_defeats("south_meadow_slimes",[0,1,2],legacy_complete.combat),"Old split-write completed kill checkpoint")
 var old_complete=legacy_complete.snapshot(); old_complete.version=12; old_complete.progression={"version":1,"base_level":1,"kills":legacy_complete.progression.kills.duplicate(true)}
 write_json(legacy_complete.path,old_complete)
 fail_write(legacy_complete,func(): return legacy_complete.load_saved(),"completed legacy migration")
 check(legacy_complete.load_saved() and legacy_complete.tutorial.stage=="return_guild_first_combat" and legacy_complete.wallet_gold==9,"Verified old full clear resumes turn-in without extra kill or gold")
 var completed_migration=snap(legacy_complete)
 check(legacy_complete.load_saved() and snap(legacy_complete)==completed_migration,"Completed migration cannot repay or advance twice")
 for generation in 3:
  check(quest.record_spawn_defeats("south_meadow_slimes",[{"index":0,"generation":generation}],quest.combat,1000+generation*25),"Qualifying new life counts after acceptance")
  if generation==0:
   var old=quest.snapshot(); old.version=12; old.progression={"version":1,"base_level":1,"kills":quest.progression.kills.duplicate(true)}
   write_json(quest.path,old)
   check(quest.load_saved() and quest.progression.population.quest_kills.south_meadow_slimes==1,"Active legacy partial kill keeps its accepted quest credit")
   var migrated=snap(quest)
   check(quest.load_saved() and snap(quest)==migrated,"Partial migration is idempotent")
 check(quest.tutorial.stage=="return_guild_first_combat" and quest.encounter_is_complete("south_meadow_slimes"),"Three qualifying accepted kills complete assignment atomically")
 for generation in range(3,30):
  check(quest.record_spawn_defeats("south_meadow_slimes",[{"index":0,"generation":generation}],quest.combat,1000+generation*25),"Repeat world kills remain available after quest")
 check(quest.progression.kills.size()==1 and quest.progression.population.spawns.size()==5,"Thirty lives do not grow receipt storage")
 check(quest.wallet_gold==90 and quest.wallet_sigils==1 and quest.get_progression_summary().total_xp==300,"All thirty lives conserved without Sigil farm")
 check(quest.stats.level==3 and quest.get_stat_summary().unspent_points==10,"Repeated XP grants five points each earned level")
 for path in paths: DirAccess.remove_absolute(path)
 print("RESPAWN SAVE CHECKS: %d; failures: %d" % [checks,failures]); quit(1 if failures else 0)
