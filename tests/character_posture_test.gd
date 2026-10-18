extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok: failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func run()->void:
 for base in ["male","female"]:
  for cls in preload("res://src/creator/catalog.gd").CLASSES:
   var actor=preload("res://src/layered_avatar.gd").new();root.add_child(actor)
   check(actor.configure(base,cls,{"hair":base+"_hair_15","skin":"deep","eyes":"Green"}),"Reviewed outfit loads")
   actor.set_equipped_weapon(preload("res://src/inventory_catalog.gd").starter_weapon(cls))
   for dye in ["armor_original","armor_moonweave","armor_emberweave"]:
    actor.set_cosmetic_dye(dye)
    for facing in range(4):
     for frame in range(24):
      actor.advance(facing,true,1.0/36.0)
      check(actor.head_lift>=3.199 and actor.head_lift<=4.801,"Head movement stays below one source pixel around four-pixel neck extension")
      check(is_equal_approx(float(actor.palette_material.get_shader_parameter("head_lift")),actor.head_lift),"Body uses current local lift")
      check(is_equal_approx(float(actor.armor.material.get_shader_parameter("head_lift")),actor.head_lift),"Body and armor cutouts stay registered")
      check(actor.body.frame==actor.armor.frame and actor.body.hframes==6,"Six authored drawings stay synchronized")
      check(actor.position==Vector2.ZERO and actor.body.position==Vector2.ZERO and actor.armor.position==Vector2.ZERO,"No whole-body bounce or translation")
      check(float(actor.palette_material.get_shader_parameter("sheet_frames"))==6.0 and float(actor.armor.material.get_shader_parameter("sheet_frames"))==6.0,"Deformation is local to the selected atlas cell")
     actor.advance(facing,false,0)
     check(actor.head_lift==4.0 and actor.hair_renderer.front.position==actor.head_offset(),"Idle returns to stable neck and clears stride offsets")
     check(actor.body.frame==facing and actor.armor.frame==facing,"Idle directional cell is unchanged")
   actor.palette_material=null
   actor.advance(0,true,0.1)
   check(actor.head_lift==0.0 and float(actor.armor.material.get_shader_parameter("head_lift"))==0.0,"Missing palette disables adjustment on both paired layers")
   actor.queue_free();await process_frame
 print("CHARACTER POSTURE: %d checks; failures: %d"%[checks,failures]);quit(1 if failures else 0)
