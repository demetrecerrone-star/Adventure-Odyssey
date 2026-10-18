extends "res://tests/tutorial_save_test.gd"
func run() -> void:
 for selected_class in ["Warrior","Ranger","Mage","Necromancer","Assassin","Paladin"]:
  var state=fixture(selected_class)
  var weapon: String=Save.Inventory.starter_weapon(selected_class)
  check(state.transfer(weapon,false) and state.equip(weapon),"Collect starter for tutorial")
  for action in ["read_envelope","guild_assign_blacksmith","blacksmith_claim_starter","upgrade","guild_after_blacksmith","apothecary_claim_gift","guild_after_apothecary","general_store_claim_keepsake","guild_after_general_store","guild_assign_first_combat"]: take_step(state,action)
  check(state.set_location("starter_region",Save.Relic.point(state.hidden_relic)) and state.claim_hidden_stick(state.hidden_relic.tree_id),"Discover after normal quest progression")
  check(state.unequip() and state.equip(Save.Relic.ITEM),"Swap upgraded starter for relic")
  check(state.set_location("starter_region",Vector2(1000,2020)),"Walk to accepted meadow")
  var world=preload("res://src/starter_world.gd").new(); world.state=state
  root.add_child(world); world.set_process(false); await process_frame
  check(world.encounter.power_bonus==988,"Live controller uses relic damage")
  check(world.actor.relic_sprite.visible and not world.actor.weapon_front.visible and not world.actor.weapon_back.visible,"Renderer holds twig rather than class weapon")
  world.player=world.encounter.enemies[0].position+Vector2(0,50)
  world._update_actor()
  world.attack_nearby()
  check(world.encounter.enemies[0].hp==0,"One genuine strike defeats full-health slime")
  world._process_encounter(0)
  check(state.enemy_is_defeated("south_meadow_slimes",0) and state.wallet_gold==3 and state.wallet_sigils==1,"Actual kill awards existing economy once")
  check(state.unequip() and state.equip(weapon),"Swap back to normal starter")
  world.actor.set_equipped_weapon(weapon)
  world._process_encounter(0)
  check(world.encounter.power_bonus==1 and not world.actor.relic_sprite.visible,"Unequip removes OP effect and twig renderer")
  world.queue_free(); await process_frame
 for path in paths: DirAccess.remove_absolute(path)
 print("HIDDEN STICK COMBAT CHECKS: %d; failures: %d" % [checks,failures])
 quit(1 if failures else 0)
