extends GutTest

const ScreenshotTourScript := preload("res://scripts/tools/screenshot_tour.gd")
const ReadmeScreenshotMainScript := preload("res://scripts/tools/readme_screenshots_main.gd")


func test_readme_capture_manifest_uses_existing_tour_steps_and_stable_filenames() -> void:
	var tour: Node = ScreenshotTourScript.new()
	autofree(tour)
	var tour_step_names: Array[String] = []
	for step in tour._build_steps():
		tour_step_names.append(step.name)

	assert_eq(
		ReadmeScreenshotMainScript.README_CAPTURES,
		{
			"start_menu": "start-menu.png",
			"encampment_ready_to_depart": "encampment.png",
			"world_map": "world-map.png",
			"battlefield": "battlefield.png",
		}
	)
	for step_name in ReadmeScreenshotMainScript.README_CAPTURES:
		assert_true(tour_step_names.has(step_name), "%s must be an existing tour step" % step_name)


func test_capture_filename_uses_manifest_name_or_numbered_tour_name() -> void:
	var tour: Node = ScreenshotTourScript.new()
	autofree(tour)

	assert_eq(tour._capture_filename(0, "start_menu", {}), "01_start_menu.png")
	assert_eq(
		tour._capture_filename(18, "encampment_ready_to_depart", {"encampment_ready_to_depart": "encampment.png"}),
		"encampment.png"
	)
