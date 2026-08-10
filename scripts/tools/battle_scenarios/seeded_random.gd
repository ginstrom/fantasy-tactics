class_name SeededRandom
extends RefCounted

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int) -> void:
	_rng.seed = seed_value


func next_float() -> float:
	return _rng.randf()


func next_int(min_value: int, max_value: int) -> int:
	return _rng.randi_range(min_value, max_value)
