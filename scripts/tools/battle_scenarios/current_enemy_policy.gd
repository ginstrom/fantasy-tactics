class_name CurrentEnemyPolicy
extends "res://scripts/tools/battle_scenarios/policy.gd"


func take_turn(controller, _rng) -> Dictionary:
	# BattleController owns the shipped enemy behavior. Keeping this an
	# adapter means scenario results exercise that code path verbatim.
	return {"ok": true, "steps": controller.run_enemy_turn()}
