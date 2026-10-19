extends "res://tests/tutorial_save_test.gd"
func settle() -> void:
 for i in 5:await process_frame
func capture(name: String) -> void:
 if not OS.get_cmdline_user_args().has("--capture"):return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OS.get_environment("AO_CAPTURE_DIR")+"/"+name+".png")==OK,"Capture summon "+name)
func run() -> void:
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.size=Vector2i(844,390)
 var state=fixture("Necromancer")
 var weapon: String=Save.Inventory.starter_weapon("Necromancer")
 check(state.transfer(weapon,false) and state.equip(weapon),"Equip Necromancer")
 check(state.set_location("starter_region",Vector2(1160,2110)),"Enter meadow")
 var world=load("res://src/starter_world.gd").new();world.state=state;root.add_child(world);world.set_process(false);await settle()
 world.use_class_skill(0);world._sync_encounter_visuals();await settle()
 check(world.encounter.summon_timer>0 and world.summon_visual.visible,"Actual successful skill displays summon")
 if OS.get_cmdline_user_args().has("--motion"):
  world.set_process(true)
  for i in 150:await process_frame
  quit();return
 var visual=world.summon_visual
 check(visual.sprite.texture!=null and visual.poses.size()==24,"Directional walk and attack atlas")
 for pose in visual.poses:
  check(Rect2(Vector2.ZERO,visual.SHEET.get_size()).encloses(pose.region),"Every complete pose lies inside atlas")
  check(pose.region.size.x>100 and pose.region.size.y>150,"Full body and weapon region is present")
 for spec in [[Vector2.DOWN,0,false],[Vector2.LEFT,1,true],[Vector2.RIGHT,1,false],[Vector2.UP,2,false]]:
  world.encounter.summon_facing=spec[0];world.encounter.summon_moving=true;world.encounter.summon_attack_flash=0
  visual.phase=2;world._sync_encounter_visuals()
  check(visual.sprite.get_meta("pose").y==spec[1] and (visual.sprite.scale.x<0)==spec[2],"Distinct proper directional walking")
  check(visual.z_index==int(world.encounter.summon_position.y*0.4),"Summon feet own depth layer")
  await capture("summon_walk_%d"%visual.direction)
  world.encounter.summon_attack_flash=0.2;world._sync_encounter_visuals()
  check(visual.sprite.get_meta("pose").y==spec[1]+3 and visual.sprite.get_meta("pose").x==2,"Actual attack pose belongs to facing")
  await capture("summon_strike_%d"%visual.direction)
 world.encounter.summon_attack_flash=0
 var enemy:Dictionary=world.encounter.enemies[0]
 world.encounter.summon_position=enemy.position+Vector2(40,0);world.encounter.summon_cooldown=0
 var hp:int=enemy.hp
 world.encounter._tick_skills(0.01,enemy.position+Vector2(0,60),func(_p):return true)
 check(enemy.hp==hp-7 and world.encounter.summon_attack_flash>0,"Existing seven-damage attack drives visual strike")
 world._sync_encounter_visuals();await settle();await capture("summon_actual_meadow")
 var before:Dictionary=world.encounter.capture()
 visual._process(0.3);visual._process(0.3)
 check(world.encounter.capture()==before,"Rendering never applies damage or changes gameplay")
 world.encounter.summon_timer=0;world._sync_encounter_visuals();check(not visual.visible,"Summon expires visually")
 world.queue_free();await settle()
 for path in paths:DirAccess.remove_absolute(path)
 print("SUMMONED SKELETON: %d checks; failures: %d"%[checks,failures]);quit(1 if failures else 0)
