extends SceneTree
const Catalog = preload("res://src/cosmetic_catalog.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
 checks += 1
 if not value:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var initial := Catalog.initial()
 check(initial.owned.size()==2,"Two free baseline looks")
 for id in Catalog.ITEMS:
  var item: Dictionary = Catalog.ITEMS[id]
  check(item.slot in Catalog.DEFAULTS,"Known slot")
  check(item.price >= 0 and item.price <= 4,"Bounded earned Sigil price")
  check(not item.has("stats") and not item.has("damage"),"Appearance cannot grant stats")
  check((Catalog.material(id)==null)==(item.price==0),"Default restores untouched source")
 for base in ["male","female"]:
  for selected_class in ["Warrior","Ranger","Mage","Necromancer","Assassin","Paladin"]:
   var avatar = preload("res://src/layered_avatar.gd").new()
   root.add_child(avatar)
   check(avatar.configure(base,selected_class),"All twelve outfits supported")
   for id in ["armor_moonweave","armor_emberweave","armor_original"]:
    var original_body_material = avatar.body.material
    avatar.set_cosmetic_dye(id)
    check(avatar.cosmetic_dye==id,"Dye selected independently")
    check(avatar.body.material==original_body_material,"Skin/eyes remain untouched")
    check(avatar.weapon_front.material==null and avatar.weapon_back.material==null,"Weapon untouched")
    for face in range(4):
     for frame in range(6):
      avatar.advance(face,true,1.0/9.0)
      check(avatar.artwork_ready,"Six-frame animation remains valid")
      check((avatar.armor.material==null)==(id=="armor_original"),"Dye persists across direction/frame")
    check(avatar.configure(base,selected_class),"Reconfigure remains safe")
    check((avatar.armor.material==null)==(id=="armor_original"),"Gear reconfigure preserves cosmetic")
   avatar.set_cosmetic_dye("bed_riverside")
   check(avatar.cosmetic_dye=="armor_original","Wrong-slot ID defaults safely")
   avatar.queue_free()
 print("Home cosmetics content: %d checks; failures: %d" % [checks,failures])
 quit(1 if failures else 0)
