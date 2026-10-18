extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
 root.size = Vector2i(1280,720)
 var background := ColorRect.new()
 background.color = Color("202834")
 background.size = root.size
 root.add_child(background)
 var avatars := []
 for row in range(2):
  var classes := ["Warrior","Ranger","Mage","Necromancer","Assassin","Paladin"]
  for col in range(6):
   var a = preload("res://src/layered_avatar.gd").new()
   root.add_child(a)
   var draft = preload("res://src/creator/character_draft.gd").new()
   draft.set_base("male" if row==0 else "female")
   draft.character_class=classes[col]
   a.configure(draft.base,classes[col],draft.payload())
   a.position=Vector2(105+col*214,310+row*345)
   a.scale=Vector2.ONE*0.95
   avatars.append(a)
   var label := Label.new()
   label.text=classes[col]+" • "+draft.base
   label.position=Vector2(col*214+20,325+row*345)
   root.add_child(label)
 for id in ["armor_original","armor_moonweave","armor_emberweave"]:
  for avatar in avatars: avatar.set_cosmetic_dye(id)
  await process_frame
  await process_frame
  await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png("res://screenshots/cosmetic_all_classes_"+id+".png")==OK)
 print("All twelve class/base palettes captured")
 quit()
