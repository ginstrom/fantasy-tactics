class_name BattleScenarioPolicy
extends RefCounted
## A named runner policy returns only public battle actions. It never owns
## campaign state or creates scenes.


func take_turn(_controller, _rng) -> Dictionary:
	return {"ok": false, "error": {"code": "policy_unimplemented"}}
