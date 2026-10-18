extends "res://tests/tutorial_flow_test.gd"
func run() -> void:
 root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 root.size=Vector2i(844,390)
 var view=Dialogue.new();root.add_child(view)
 view.action_requested.connect(func(_id):action_count+=1)
 view.service_requested.connect(func(_id):service_count+=1)
 view.dismissed.connect(func():close_count+=1)
 for index in range(Progress.STAGES.size()):
  var progress=state_at(index)
  for npc in ["guild_receptionist","blacksmith","apothecary","shopkeeper"]:
   var before=progress.duplicate(true)
   view.configure(npc,progress,"Warrior")
   var original=Dialogue.describe(npc,progress,"Warrior")
   var ask:Dictionary=view._view.choices.filter(func(c):return c.id=="personal_question")[0]
   view._choose(ask);view._choose(ask)
   check(view.body_label.text==Dialogue.personal_reply(npc),"Personal response belongs to speaker")
   check(view._view.choices.filter(func(c):return c.id=="resume_conversation").size()==1,"Repeated questions add just one return choice")
   check(action_count==0 and service_count==0 and progress==before,"Optional dialogue never changes progress or emits transactions")
   view._choose(view._view.choices.filter(func(c):return c.id=="resume_conversation")[0])
   check(view.body_label.text==original.body and view._view==original,"Back restores exact pending briefing")
   var defer:Dictionary=view._view.choices.filter(func(c):return c.id=="not_now")[0]
   var count=close_count
   view._choose(defer);view._choose(defer)
   check(close_count==count+1 and action_count==0,"Defer closes once without accepting anything")
   view.configure(npc,progress,"Warrior")
   check(view._view==original and progress==before,"Reopening resumes same stage without a lost gift")
 if "--capture" in OS.get_cmdline_user_args():
  DirAccess.make_dir_recursive_absolute("res://screenshots")
  for size in [Vector2i(640,360),Vector2i(844,390)]:
   root.size=size
   for spec in [["guild_receptionist",1],["blacksmith",2],["apothecary",5],["shopkeeper",7],["guild_receptionist",9]]:
    view.configure(spec[0],state_at(spec[1]),"Warrior")
    for tick in range(3):await process_frame
    await RenderingServer.frame_post_draw
    check(root.get_texture().get_image().save_png("res://screenshots/personal_%s_%d_%d.png"%[spec[0],spec[1],size.x])==OK,"Native dialogue capture")
   view._choose(view._view.choices.filter(func(c):return c.id=="personal_question")[0])
   for tick in range(3):await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://screenshots/personal_reassurance_%d.png"%size.x)
 view.queue_free();await process_frame
 print("PERSONAL DIALOGUE: %d checks; failures: %d"%[checks,failures])
 quit(1 if failures else 0)
