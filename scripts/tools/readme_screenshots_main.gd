extends SceneTree
## Entry point for `make readme-screenshots`.
##
## The exhaustive screenshot tour is stateful, so this runner executes every
## tour action in order and asks it to save only the representative README
## frames. Stable filenames keep README image links unchanged when the tour's
## full numbered sequence gains or loses steps.

const SCREENSHOT_TOUR_SCRIPT := "res://scripts/tools/screenshot_tour.gd"
const DEFAULT_OUT_DIR := "docs/images/readme"
const OUT_DIR_ARG_PREFIX := "--outdir="
const README_CAPTURES := {
	"start_menu": "start-menu.png",
	"encampment_ready_to_depart": "encampment.png",
	"world_map": "world-map.png",
	"battlefield": "battlefield.png",
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var tour: Node = load(SCREENSHOT_TOUR_SCRIPT).new()
	root.add_child(tour)
	await tour.run(_resolve_out_dir(), README_CAPTURES)


func _resolve_out_dir() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(OUT_DIR_ARG_PREFIX):
			return arg.substr(OUT_DIR_ARG_PREFIX.length())
	return ProjectSettings.globalize_path("res://").path_join(DEFAULT_OUT_DIR)
