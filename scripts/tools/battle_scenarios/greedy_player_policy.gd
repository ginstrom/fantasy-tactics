class_name GreedyPlayerPolicy
extends "res://scripts/tools/battle_scenarios/policy.gd"

const BattleBot := preload("res://scripts/tools/battle_bot.gd")


func take_turn(controller, _rng) -> Dictionary:
	return {"ok": true, "steps": BattleBot.take_player_turn(controller)}
