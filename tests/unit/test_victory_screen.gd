extends GutTest
## Covers scripts/ui/victory_screen.gd / scenes/ui/victory_screen.tscn --
## the dedicated Campaign Victory screen (docs/plans/2026-08-18-core-loop-
## and-engagement/05-authored-encounters-and-final-boss.md). Unlike
## battle_result.gd's transient GameManager.battle_result_summary payload,
## every stat here comes straight from durable GameSession state (see
## GameSession.get_campaign_victory_summary()), so each test sets up that
## state directly rather than injecting a summary Dictionary.

const VictoryScreenScene := preload("res://scenes/ui/victory_screen.tscn")


func before_each() -> void:
	GameSession.reset()


func _open_victory_screen() -> Control:
	var screen: Control = VictoryScreenScene.instantiate()
	add_child_autofree(screen)
	return screen


func test_displays_campaign_summary_stats() -> void:
	GameSession.world_turn = 42
	GameSession.completed_encounters = ["obj_tier1_1_goblin_outpost", "obj_tier1_2_kobold_warren"]
	GameSession.total_casualties = 1
	GameSession.gold = 350
	GameSession.guild_hall_level = 3
	GameSession.shop_level = 3
	GameSession.temple_level = 1

	var screen := _open_victory_screen()

	assert_eq(screen.get_node("Center/VBox/TurnsLabel").text, tr("victory.stat.turns") % 42)
	assert_eq(screen.get_node("Center/VBox/BattlesLabel").text, tr("victory.stat.battles_won") % 2)
	assert_eq(screen.get_node("Center/VBox/CasualtiesLabel").text, tr("victory.stat.casualties") % 1)
	assert_eq(screen.get_node("Center/VBox/GoldLabel").text, tr("victory.stat.gold_banked") % 350)
	# guild_hall (3 - 1) + temple (1) + shop (3 - 1) = 5 upgrades completed.
	assert_eq(screen.get_node("Center/VBox/UpgradesLabel").text, tr("victory.stat.upgrades") % 5)


func test_provides_a_continue_button() -> void:
	var screen := _open_victory_screen()

	assert_not_null(screen.get_node("Center/VBox/ContinueButton"))


func test_continue_button_returns_to_the_encampment() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/victory_screen.gd")

	assert_string_contains(source, "GameManager.go_to_encampment()")


func test_continue_button_does_not_reset_completed_objectives_or_free_play() -> void:
	GameSession.set_campaign_victory()
	GameSession.completed_objectives.assign(GameSession.CAMPAIGN_OBJECTIVES.keys())
	var screen := _open_victory_screen()

	screen.get_node("Center/VBox/ContinueButton").emit_signal("pressed")

	assert_eq(GameSession.completed_objectives.size(), 12)
	assert_true(GameSession.is_free_play_active)
	assert_true(GameSession.is_campaign_completed)
