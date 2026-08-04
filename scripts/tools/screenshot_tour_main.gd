extends SceneTree
## Entry point for `make screenshots`, run via `godot -s`.
##
## A plain scene can't drive this tour: GameManager.go_to_start_menu() (and
## every other navigation call) replaces the current scene, which frees it
## and aborts any script still running on it. Running as the SceneTree's
## main-loop script instead, and adding the tour as a direct child of `root`
## (never as `current_scene`), keeps it alive across every scene change.

const SCREENSHOT_TOUR_SCRIPT := "res://scripts/tools/screenshot_tour.gd"

const DEFAULT_OUT_DIR := "screenshots"
const OUT_DIR_ARG_PREFIX := "--outdir="


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	# load(), not preload(): preloading would compile screenshot_tour.gd while
	# this bootstrap script itself is still being compiled, before autoloads
	# (GameManager, GameSession) are registered, so its references to them
	# would fail to resolve.
	var tour: Node = load(SCREENSHOT_TOUR_SCRIPT).new()
	root.add_child(tour)
	await tour.run(_resolve_out_dir())


func _resolve_out_dir() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(OUT_DIR_ARG_PREFIX):
			return arg.substr(OUT_DIR_ARG_PREFIX.length())
	return ProjectSettings.globalize_path("res://").path_join(DEFAULT_OUT_DIR)
