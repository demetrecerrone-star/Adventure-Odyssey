extends SceneTree
# No quest-stage writes or player teleports: travel uses the retail collision
# controller and every quest transaction comes from the actual scene's buttons.
const Save = preload("res://src/bedroom_save.gd")
const Draft = preload("res://src/creator/character_draft.gd")
const Interior = preload("res://src/town_interior.gd")
var checks := 0
var failures := 0
var state
var scene
var graphs := {}
func _initialize(): call_deferred("run")
func check(ok:bool, why:String):
 checks += 1
 if not ok: failures += 1; push_error(why)
func settle():
 for i in 3: await process_frame
func mount():
 if is_instance_valid(scene): scene.free()
 var id:String = state.location.scene
 scene = load("res://src/starter_world.gd" if id == "starter_region" else ("res://src/town_interior.gd" if id.ends_with("_interior") else "res://src/bedroom.gd")).new()
 if id.ends_with("_interior"): scene.room_id = id
 scene.state = state; root.add_child(scene); scene.set_process(false)
 await settle()
func graph():
 var id:String = state.location.scene
 if graphs.has(id): return graphs[id]
 var grid := AStar2D.new()
 var dimensions := Vector2(4608,3072) if id == "starter_region" else Vector2(1536,1024)
 var pitch := 24
 var width := int(dimensions.x/pitch)+1
 for y in range(int(dimensions.y/pitch)+1):
  for x in range(width):
   var at := Vector2(x*pitch,y*pitch)
   if scene.can_stand(at): grid.add_point(y*width+x,at)
 for point_id in grid.get_point_ids():
  for offset in [1,width]:
   if grid.has_point(point_id+offset):
    var a := grid.get_point_position(point_id); var b := grid.get_point_position(point_id+offset)
    if a.distance_to(b) > pitch+1: continue
    if scene.can_stand(a.lerp(b,0.25)) and scene.can_stand(a.lerp(b,0.5)) and scene.can_stand(a.lerp(b,0.75)): grid.connect_points(point_id,point_id+offset)
 graphs[id] = grid
 return grid
func walk(target:Vector2, why:String):
 var grid:AStar2D = graph()
 var route := grid.get_point_path(grid.get_closest_point(scene.player),grid.get_closest_point(target))
 check(not route.is_empty(),"Route exists: "+why)
 route.append(target)
 for point in route:
  scene.move_player(point-scene.player)
  if scene.player.distance_to(point)>1:
   check(false,"Retail movement blocked: %s at %s toward %s"%[why,scene.player,point]); return
 scene._update_actor()
 check(scene.player.distance_to(target)<1,"Arrive by walking: "+why)
func choose(id:String):
 var button = scene.overlay.find_child("Choice_"+id,true,false)
 check(is_instance_valid(button),"Retail dialogue offers "+id)
 if not is_instance_valid(button): return
 # Make the same scrolling operation available to a phone player, then press.
 scene.overlay.scroll.ensure_control_visible(button)
 await settle()
 check(not button.disabled,"Action enabled: "+id)
 button.pressed.emit(); await settle()
 check(scene.overlay.notice_label.text.is_empty(),"Action saves: "+id+": "+scene.overlay.notice_label.text)
func close():
 scene._close_overlay(); await settle()
func visit(id:String):
 if is_instance_valid(scene.overlay): await close()
 if state.location.scene != "starter_region":
  walk(scene.anchors.door,"interior exit")
  scene.interact(); await settle()
  check(state.location.scene=="starter_region","Door transitions outside")
  await mount()
 walk(scene.anchors[Interior.ROOMS[id].entrance],"enter "+id)
 scene.interact(); await settle()
 check(state.location.scene==id,"Exterior door enters "+id)
 await mount()
 walk(scene.anchors[scene.room_data.npcs[0].id],"approach attendant "+id)
 scene.interact(); await settle()
 check(is_instance_valid(scene.overlay),"Attendant opens "+id)
func capture(label:String):
 if "--capture" not in OS.get_cmdline_user_args(): return
 await settle(); await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute("res://screenshots")
 check(root.get_texture().get_image().save_png("res://screenshots/retail_quest_%s_%d.png"%[label,root.size.x])==OK,"Capture retail scene")
func run():
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED; root.size=Vector2i(844,390)
 for legacy in [false,true]:
  root.size=Vector2i(640,360) if legacy else Vector2i(844,390)
  state=Save.new(); state.path="user://retail_route_%d_%s.json"%[Time.get_ticks_usec(),legacy]
  var d=Draft.new(); d.set_base("male"); d.character_class="Warrior"; d.username="RouteTester"
  if legacy:
   var bag=Save.Inventory.empty_inventory(); var chest=Save.Inventory.empty_inventory()
   # Exact release0.10 schema5 shape, before tutorial/ledger systems existed.
   for item in bag.keys():
    if item not in Save.Inventory.LEGACY_ITEMS: bag.erase(item); chest.erase(item)
   chest.warrior_01_weapon=1; chest.healing_potion=5
   var old={"version":5,"tutorial_chest_seeded":true,"character":d.payload(),"bag":bag,"chest":chest,"equipped_weapon":"","equipped_armor":"warrior_01_armor","awake":true,"location":{"scene":"guild_interior","position":[1110.0,750.0]}}
   var entry:=Interior.entry_point("guild_interior"); old.location.position=[entry.x,entry.y]
   var file=FileAccess.open(state.path,FileAccess.WRITE); file.store_string(JSON.stringify(old)); file.close()
   check(state.load_saved(),"Migrate real0.10 schema: "+state.error)
  else: check(state.create(d.payload()),"Create fresh character")
  await mount()
  if legacy:
   walk(scene.anchors[scene.room_data.npcs[0].id],"migrated guild attendant")
   scene.interact(); await settle()
   check(scene.overlay._view.body.contains("envelope") and scene.overlay._view.choices.filter(func(choice): return choice.kind == "action").is_empty(),"Migrated guild visitor receives prerequisite direction")
   await close(); walk(scene.anchors.door,"migrated guild exit"); scene.interact(); await settle(); await mount()
   walk(scene.HOME,"return home for starter weapon"); scene.interact(); await settle(); await mount()
  walk(scene.anchors.chest,"home starter chest"); scene.interact(); await settle()
  # Find the only enabled Equip row after withdrawing all starter supplies.
  for n in range(8):
   var take:Button
   for b in scene.overlay.find_children("*","Button",true,false):
    if b.text=="Take one" and not b.disabled: take=b; break
   if not is_instance_valid(take): break
   take.pressed.emit(); await settle()
  for b in scene.overlay.find_children("*","Button",true,false):
   if b.text=="Equip" and not b.disabled: b.pressed.emit(); break
  await settle(); check(state.equipped_weapon=="warrior_01_weapon","Starter weapon equipped through storage UI")
  await close(); walk(scene.anchors.door,"home door"); scene.interact(); await settle(); await mount()
  walk(scene.ENVELOPE,"doorstep letter"); scene.interact(); await settle(); await choose("read_envelope"); await close()
  await visit("guild_interior"); await choose("guild_assign_blacksmith")
  await visit("blacksmith_interior"); await choose("blacksmith_claim_starter"); await choose("tutorial_upgrade")
  scene.overlay.select_button.pressed.emit(); scene.overlay.confirm_button.pressed.emit(); await settle()
  check(state.tutorial.stage=="return_guild_blacksmith","Complete upgrade through actual controls")
  await visit("guild_interior"); await choose("guild_after_blacksmith")
  await visit("apothecary_interior"); await choose("apothecary_claim_gift")
  await visit("guild_interior"); await choose("guild_after_apothecary")
  await visit("general_store_interior"); await choose("general_store_claim_keepsake")
  await visit("guild_interior"); await choose("guild_after_general_store")
  var accept=scene.overlay.find_child("Choice_guild_assign_first_combat",true,false)
  check(scene.overlay.scroll.get_global_rect().encloses(accept.get_global_rect()),"First assignment acceptance visible without scrolling")
  await capture("accept")
  await choose("guild_assign_first_combat")
  check(state.tutorial.stage=="first_combat_active","Assignment accepted without stage injection")
  await close(); walk(scene.anchors.door,"guild exit"); scene.interact(); await settle(); await mount()
  # Follow the same marked road a player sees, without off-road shortcuts.
  for waypoint in preload("res://src/quest_trail.gd").road(state.tutorial.stage):
   scene.move_player(waypoint-scene.player)
   check(scene.player.distance_to(waypoint)<1,"Gold trail uses collision-clear retail road")
  scene._update_actor(); scene._process_encounter(0)
  await capture("meadow")
  for enemy in scene.encounter.enemies:
   walk(enemy.position+Vector2(0,60),"walk to slime")
   scene._process_encounter(0)
   check(scene._combat_active() and not scene.hud.attack_button.disabled,"Slime reachable and attack enabled")
  check(state.load_saved() and state.tutorial.stage=="first_combat_active","Normal route persists accepted assignment")
  scene.free(); scene=null; DirAccess.remove_absolute(state.path)
 print("RETAIL QUEST ROUTE: %d checks; failures: %d"%[checks,failures]); quit(1 if failures else 0)
