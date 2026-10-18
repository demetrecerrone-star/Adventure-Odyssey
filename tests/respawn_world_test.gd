extends "res://tests/tutorial_save_test.gd"
func settle() -> void:
 for i in 4: await process_frame
func capture(world, name: String) -> void:
 if not OS.get_cmdline_user_args().has("--capture"): return
 world._update_actor(); world._sync_encounter_visuals(); world._update_combat_hud(); await settle()
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png((OS.get_environment("AO_CAPTURE_DIR") if not OS.get_environment("AO_CAPTURE_DIR").is_empty() else "res://screenshots")+"/"+name+".png")==OK,"Native group capture")
func run() -> void:
 DirAccess.make_dir_recursive_absolute(OS.get_environment("AO_CAPTURE_DIR") if not OS.get_environment("AO_CAPTURE_DIR").is_empty() else "res://screenshots")
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 root.size=Vector2i(844,390)
 for selected_class in ["Warrior","Ranger","Mage","Necromancer","Assassin","Paladin"]:
  var state=fixture(selected_class)
  check(state.set_location("starter_region",Save.Relic.point(state.hidden_relic)) and state.claim_hidden_stick(state.hidden_relic.tree_id) and state.equip(Save.Relic.ITEM),"Find and equip real relic")
  check(state.set_location("starter_region",Vector2(1000,2020)),"Enter meadow before assignment")
  var world=load("res://src/starter_world.gd").new(); world.state=state
  var now: int=int(Time.get_unix_time_from_system())
  world.population_clock=func(): return now
  root.add_child(world); world.set_process(false); await settle()
  check(world.populations.size()==2 and world.populations.south_meadow_slimes.living_count()==3 and world.populations.west_forest_patrol.living_count()==2,"Both groups exist independently of quest")
  check(world._combat_active(),"Fresh pre-quest player can fight")
  for route in world.world_layout.routes:
   for point in route.points: check(not world._combat_can_stand(Vector2(point[0],point[1])),"Main route stays outside combat territory")
  if selected_class=="Warrior":
   world.player=Vector2(1110,2280)
   await capture(world,"independent_slime_group")
   world.player=Vector2(1000,2020)
   await capture(world,"slime_road_sign")
  var hp: int=world.encounter.hp
  world.player=Vector2(1000,2020)
  for tick in 160: world._process_encounter(0.05)
  check(world.encounter.hp==hp,"Safe approach path protected from attacks")
  world.player=world.encounter.enemies[0].position+Vector2(0,50); world._update_actor(); world.attack_nearby()
  check(state.wallet_gold==3 and state.wallet_sigils==1,"Real pre-quest attack receives first-life rewards")
  check(state.progression.population.quest_kills.south_meadow_slimes==0,"Kill never starts or advances unaccepted assignment")
  check(world.encounter.enemies[0].hp==0,"Killed life stays dead")
  world._refresh_population(now+44)
  check(world.encounter.enemies[0].hp==0,"Still dead before persisted deadline")
  now+=45
  world.population_clock=func(): return now
  world._refresh_population(now)
  check(world.encounter.enemies[0].hp==world.encounter.enemy_hp,"New incarnation respawns at full health")
  check(world.encounter.enemies[0].generation==1,"New life has next monotonic identity")
  world.encounter.attack_cooldown=0; world.player=world.encounter.enemies[0].position+Vector2(0,50); world.attack_nearby()
  check(state.wallet_gold==6 and state.wallet_sigils==1 and state.get_progression_summary().total_xp==20,"Real repeat attack rewards only gold/XP")
  world.player=Vector2(850,1230); world._process_encounter(0)
  check(world.encounter.encounter_id=="west_forest_patrol" and world.encounter.living_count()==2,"Walking north selects existing wolf group without quest")
  var forest_hp: int=world.encounter.hp
  world.player=Vector2(650,1130)
  for tick in 160: world._process_encounter(0.05)
  check(world.encounter.hp==forest_hp,"Forest through-road is safe beside wolf territory")
  for enemy in world.encounter.enemies: check(world._combat_can_stand(enemy.position),"Wolves stay off protected road")
  if selected_class=="Warrior":
   world.player=Vector2(740,1060)
   world.control_preferences.left_handed=true; world._apply_control_layout()
   await capture(world,"independent_wolf_group_left")
  world.player=world.encounter.enemies[0].position+Vector2(0,50); world.encounter.attack_cooldown=0; world.attack_nearby()
  check(state.wallet_gold==14 and state.wallet_sigils==3,"Wolf group pays its own first-life reward")
  check(state.progression.population.spawns.size()==5,"World retains bounded five spawn records")
  world.queue_free(); await settle()
 for path in paths: DirAccess.remove_absolute(path)
 print("RESPAWN WORLD CHECKS: %d; failures: %d" % [checks,failures]); quit(1 if failures else 0)
