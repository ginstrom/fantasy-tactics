extends GutTest
## Step 3 (docs/plans/2026-08-19-core-loop-verification-remediation/
## 03-audio-bus-contract.md), Task 1: structural regression test proving
## project.godot ITSELF declares the Music/SFX bus layout, and that the
## layout it declares actually routes Music/SFX to Master.
##
## This must read project.godot as a file (ConfigFile.load(), which parses
## the on-disk .godot config text -- not ProjectSettings.get_setting()) and
## must load default_bus_layout.tres as a Resource and inspect its own
## bus/N/* properties -- not query AudioServer's live bus list. Godot's
## engine-level built-in default for the audio/buses/default_bus_layout
## setting happens to be the literal string "res://default_bus_layout.tres",
## so any test that queries the *resolved* runtime ProjectSettings value or
## the current AudioServer bus state would keep passing even if project.godot's
## own [audio] section were deleted entirely -- exactly the regression an
## earlier commit introduced. Only reading project.godot's own text, and the
## layout resource's own data, proves project.godot is the source of the
## contract rather than an engine fallback silently masking its absence.

const EXPECTED_LAYOUT_PATH := "res://default_bus_layout.tres"
const REQUIRED_ROUTED_BUSES := ["Music", "SFX"]


func test_project_godot_declares_the_default_bus_layout() -> void:
	var config := ConfigFile.new()
	var err := config.load("res://project.godot")
	assert_eq(err, OK, "project.godot must parse as a valid config file")
	assert_true(
		config.has_section("audio"),
		"project.godot must have an [audio] section naming the bus layout resource"
	)
	assert_true(
		config.has_section_key("audio", "buses/default_bus_layout"),
		"project.godot's [audio] section must set buses/default_bus_layout"
	)
	var declared_path: String = config.get_value("audio", "buses/default_bus_layout", "")
	assert_eq(
		declared_path,
		EXPECTED_LAYOUT_PATH,
		"project.godot must point buses/default_bus_layout at %s" % EXPECTED_LAYOUT_PATH
	)


func test_default_bus_layout_routes_music_and_sfx_to_master() -> void:
	var layout: AudioBusLayout = load(EXPECTED_LAYOUT_PATH)
	assert_not_null(layout, "%s must exist and load as an AudioBusLayout" % EXPECTED_LAYOUT_PATH)
	if layout == null:
		return

	# AudioBusLayout does not expose a "bus_count" property or bus-lookup
	# methods -- its bus/N/* fields are dynamic properties surfaced through
	# get_property_list(), the same mechanism the .tres text format itself
	# uses (see the file's own `bus/1/name = &"Music"` entries).
	var index_by_name := {}
	for prop in layout.get_property_list():
		var prop_name: String = prop["name"]
		if prop_name.ends_with("/name"):
			var bus_index := int(prop_name.split("/")[1])
			index_by_name[String(layout.get(prop_name))] = bus_index

	for bus_name in REQUIRED_ROUTED_BUSES:
		assert_true(
			index_by_name.has(bus_name),
			"%s must define a %s bus" % [EXPECTED_LAYOUT_PATH, bus_name]
		)
		if not index_by_name.has(bus_name):
			continue
		var send: String = layout.get("bus/%d/send" % index_by_name[bus_name])
		assert_eq(
			send,
			"Master",
			"%s bus must send to Master" % bus_name
		)
