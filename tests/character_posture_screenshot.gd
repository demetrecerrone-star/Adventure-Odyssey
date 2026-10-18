extends SceneTree
var actors: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 root.size=Vector2i(1440,900)
 DirAccess.make_dir_recursive_absolute("res://screenshots")
 for direction in [0,1,2,3]:
  var canvas=Control.new(); root.add_child(canvas)
  var bg=ColorRect.new(); bg.color=Color("e7dcc7"); bg.size=Vector2(1440,900); canvas.add_child(bg)
  actors=[]
  for row in range(4):
   for col in range(6):
    var selected_class=["Warrior","Ranger","Mage","Necromancer","Assassin","Paladin"][col]
    var base="male" if row<2 else "female"
    var actor=preload("res://src/layered_avatar.gd").new(); canvas.add_child(actor)
    actor.configure(base,selected_class,{"hair":base+"_hair_01","hair_color":"Brown","skin":"warm","eyes":"Green"})
    actor.set_equipped_weapon(preload("res://src/inventory_catalog.gd").starter_weapon(selected_class))
    actor.advance(direction,true,0.16)
    actor.position=Vector2(col*240+120,row*225+222)
    actor.scale=Vector2.ONE*0.90
    if row%2==0:
     actor.palette_material.set_shader_parameter("head_lift",0.0)
     actor.armor.material.set_shader_parameter("head_lift",0.0)
     for hair in [actor.hair_renderer.front,actor.hair_renderer.rear]: hair.position-=actor.head_offset()
    var label=Label.new(); label.text=base+" "+selected_class+(" before" if row%2==0 else " after");label.position=Vector2(col*240+8,row*225+4);label.add_theme_color_override("font_color",Color("30291e"));canvas.add_child(label)
    actors.append(actor)
  for tick in range(3): await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://screenshots/posture_direction_%d.png"%direction)
  canvas.queue_free(); await process_frame
 if "--motion" in OS.get_cmdline_user_args():
  root.size=Vector2i(1440,500)
  var canvas=Control.new();root.add_child(canvas)
  var bg=ColorRect.new();bg.color=Color("e7dcc7");bg.size=Vector2(1440,500);canvas.add_child(bg)
  actors=[]
  for row in range(2):
   for col in range(6):
    var cls=["Warrior","Ranger","Mage","Necromancer","Assassin","Paladin"][col]
    var base="male" if row==0 else "female"
    var actor=preload("res://src/layered_avatar.gd").new();canvas.add_child(actor)
    actor.configure(base,cls,{"hair":base+"_hair_01","hair_color":"Brown","skin":"warm","eyes":"Green"})
    actor.set_equipped_weapon(preload("res://src/inventory_catalog.gd").starter_weapon(cls))
    actor.position=Vector2(col*240+120,row*250+246)
    var label=Label.new();label.text=base+" "+cls;label.position=Vector2(col*240+8,row*250+4);label.add_theme_color_override("font_color",Color("30291e"));canvas.add_child(label)
    actors.append(actor)
  for frame in range(144):
   for actor in actors:actor.advance([0,1,3,2][frame/36],true,1.0/36.0)
   await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://screenshots/posture_motion_%03d.png"%frame)
 print("CHARACTER POSTURE SCREENSHOTS: four all-class comparison views")
 quit()
