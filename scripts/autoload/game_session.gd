extends Node

const DEFAULT_PARTY: Array[String] = ["hero"]
const DEFAULT_LOCATION := "starting_village"

var party: Array[String] = []
var current_location: String = ""


func _init() -> void:
	reset()


func start_new_game() -> void:
	reset()


func reset() -> void:
	# Duplicate so mutating a session's party never mutates the shared constant.
	party = DEFAULT_PARTY.duplicate()
	current_location = DEFAULT_LOCATION
