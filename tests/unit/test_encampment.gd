extends GutTest

const EncampmentScene := preload("res://scenes/ui/encampment.tscn")


func before_each() -> void:
	GameSession.reset()


func after_each() -> void:
	GameManager.close_game_menu()
	GameManager.create_party_on_open = false
	AudioManager.reset()



func test_encampment_contains_the_camp_nav() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_not_null(screen.get_node("Body/CampNav"))
	assert_null(screen.get_node_or_null("CampaignGuide"), "Campaign guidance belongs in the Journal, never as a floating Encampment panel")


func test_entering_encampment_publishes_current_campaign_guidance_to_the_journal() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	var entries := GameSession.get_journal_entries(GameSession.JOURNAL_SECTION_LOG)
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].kind, "campaign_guidance")
	assert_eq(entries[0].detail.guide_id, GameSession.CAMPAIGN_GUIDE_FORM_PARTY)


## Task 3: Music State Transitions (docs/plans/2026-08-18-core-loop-and-
## engagement/08-audio-system-and-soundscape.md) -- entering the Encampment
## requests its own track (scripts/ui/encampment.gd's _ready()).
## AudioManager.play_music() itself is exercised directly in
## tests/unit/test_audio_manager.gd -- this only proves Encampment calls it
## with the right track id, mirroring test_battlefield.gd's equivalent
## coverage for Battle/Victory/Defeat (Finding 3a, task-1-report.md).
func test_entering_the_encampment_requests_the_encampment_music() -> void:
	var screen: Control = EncampmentScene.instantiate()

	add_child_autofree(screen)

	assert_true(AudioManager.is_music_playing("music_encampment"))


func test_the_old_depart_and_manage_party_controls_are_absent() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_false(screen.has_node("Body/Center/VBox/DepartButton"))
	assert_false(screen.has_node("Body/Center/VBox/ManagePartyButton"))
	assert_false(screen.has_node("Body/Center/VBox/Status"))
	assert_false(
		screen.has_node("Body/Center/VBox/UnitsButton"),
		"Encampment's own content no longer has nav buttons -- they live in CampNav"
	)
	assert_false(screen.has_node("Body/Center/VBox/BuildingsButton"))
	assert_false(screen.has_node("Body/Center/VBox/TradeButton"))
	assert_false(screen.has_node("Body/Center/VBox/DeployPartyButton"))


func test_encampment_shows_population_parties_and_units_counts() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/PopulationLabel").text, tr("encampment.population") % 4)
	assert_eq(screen.get_node("Body/Center/VBox/PartiesLabel").text, tr("encampment.parties_count") % 1)
	assert_eq(screen.get_node("Body/Center/VBox/UnitsLabel").text, tr("encampment.units_count") % 4)


func test_units_count_excludes_members_of_a_deployed_party() -> void:
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party("warrior_001")
	GameSession.deploy_party(GameSession.FIRST_PARTY_ID)
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("Body/Center/VBox/PopulationLabel").text, tr("encampment.population") % 4)
	assert_eq(
		screen.get_node("Body/Center/VBox/UnitsLabel").text, tr("encampment.units_count") % 3,
		"One of the four adventurers is out with a deployed party"
	)


func test_refresh_updates_the_counts() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	assert_eq(screen.get_node("Body/Center/VBox/PartiesLabel").text, tr("encampment.parties_count") % 0)

	GameSession.create_party()
	screen.refresh()

	assert_eq(screen.get_node("Body/Center/VBox/PartiesLabel").text, tr("encampment.parties_count") % 1)


func test_first_party_dialog_dismisses_only_for_this_scene_visit() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	var dialog: Control = screen.get_node("FirstPartyDialog")
	assert_true(dialog.visible)
	dialog.get_node("Content/Buttons/DismissButton").emit_signal("pressed")
	assert_false(dialog.visible)
	screen.refresh()
	assert_false(dialog.visible)
	var returned: Control = EncampmentScene.instantiate()
	add_child_autofree(returned)
	assert_true(returned.get_node("FirstPartyDialog").visible)


func test_first_party_dialog_uses_the_exact_prompt_and_create_routes_to_parties() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	assert_eq(screen.get_node("FirstPartyDialog/Content/Title").text, tr("encampment.first_party.title"))
	assert_eq(screen.get_node("FirstPartyDialog/Content/Message").text, tr("encampment.first_party.message"))
	assert_eq(screen.get_node("FirstPartyDialog/Content/Buttons/CreateButton").text, tr("encampment.first_party.create"))
	assert_eq(screen.get_node("FirstPartyDialog/Content/Buttons/DismissButton").text, tr("encampment.first_party.dismiss"))
	screen.get_node("FirstPartyDialog/Content/Buttons/CreateButton").emit_signal("pressed")
	assert_eq(GameManager.route_context_id, "")
	assert_true(GameManager.create_party_on_open, "First party dialog create button must ask go_to_parties to create immediately")



func test_encampment_contains_the_information_panel_and_refreshes_its_gold_total() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("%InformationPanel")

	GameSession.gold = 25
	screen.refresh()

	assert_eq(panel.get_node("Content/Gold").text, tr("information.gold") % 25)


func test_encampment_never_shows_party_info_since_it_has_no_selection_concept() -> void:
	GameSession.create_party()
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	var panel: Control = screen.get_node("%InformationPanel")

	screen.refresh()

	assert_false(panel.get_node("Content/PartyName").visible)
	assert_false(panel.get_node("Content/PartyMembers").visible)
	assert_false(panel.get_node("Content/PartyViewButton").visible)


func test_encampment_displays_the_active_campaign_objective() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	var banner: Control = screen.get_node("%CampaignObjectiveBanner")

	assert_eq(banner.get_node("Content/TitleLabel").text, tr("campaign.obj.tier1_1.title"))
	assert_eq(banner.get_node("Content/DescLabel").text, tr("campaign.obj.tier1_1.desc"))


## Step 1 task list item 5: the banner self-subscribes to GameSession.
## campaign_progress_changed (see campaign_objective_banner.gd), so it must
## reflect a completed objective immediately -- with no manual screen.refresh()
## call in between.
func test_encampment_campaign_objective_banner_updates_immediately_when_the_objective_advances() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	var banner: Control = screen.get_node("%CampaignObjectiveBanner")
	var title_label: Label = banner.get_node("Content/TitleLabel")
	assert_eq(title_label.text, tr("campaign.obj.tier1_1.title"))

	GameSession.complete_campaign_objective("obj_tier1_1_goblin_outpost")

	assert_eq(title_label.text, tr("campaign.obj.tier1_2.title"))


func test_encampment_campaign_objective_banner_shows_free_play_after_victory() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	var banner: Control = screen.get_node("%CampaignObjectiveBanner")

	GameSession.set_campaign_victory()

	assert_false(banner.get_node("Content/TitleLabel").visible)
	assert_true(banner.get_node("Content/FreePlayLabel").visible)
	assert_eq(banner.get_node("Content/FreePlayLabel").text, tr("campaign.free_play.active_label"))


func test_escape_marks_input_handled_and_opens_the_game_menu() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)
	var escape_event := InputEventAction.new()
	escape_event.action = "ui_cancel"
	escape_event.pressed = true

	screen._unhandled_input(escape_event)

	assert_true(screen.get_viewport().is_input_handled())
	assert_true(GameManager.is_game_menu_open())
	assert_true(get_tree().paused)


## --- Building Card Visual States (Technical Design §5, docs/plans/
## 2026-08-18-core-loop-and-engagement/
## 07-visual-perspective-and-tactical-polish.md) --- purely presentational:
## these tests never assert on what a building's level unlocks (already
## covered by test_guild_hall.gd/test_temple.gd/test_stores.gd), only on how
## its card looks at that level.

func test_guild_hall_card_shows_tier_one_art_and_name_at_the_default_level() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_eq(screen.get_node("%GuildHallArt").color, screen.GUILD_HALL_TIER_COLORS[1])
	assert_eq(screen.get_node("%GuildHallName").text, tr("encampment.building.guild_hall.tier1"))
	assert_eq(screen.get_node("%GuildHallLevel").text, tr("encampment.building.level") % 1)


func test_guild_hall_card_updates_to_tier_two_art_and_name_after_refresh() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	GameSession.guild_hall_level = 2
	screen.refresh()

	assert_eq(screen.get_node("%GuildHallArt").color, screen.GUILD_HALL_TIER_COLORS[2])
	assert_eq(screen.get_node("%GuildHallName").text, tr("encampment.building.guild_hall.tier2"))
	assert_eq(screen.get_node("%GuildHallLevel").text, tr("encampment.building.level") % 2)


func test_guild_hall_card_updates_to_tier_three_art_and_name_after_refresh() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	GameSession.guild_hall_level = 3
	screen.refresh()

	assert_eq(screen.get_node("%GuildHallArt").color, screen.GUILD_HALL_TIER_COLORS[3])
	assert_eq(screen.get_node("%GuildHallName").text, tr("encampment.building.guild_hall.tier3"))


func test_temple_card_is_hidden_until_the_temple_is_built() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_false(screen.get_node("%TempleCard").visible)


func test_temple_card_shows_tier_one_art_and_name_once_built() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	GameSession.temple_level = 1
	screen.refresh()

	assert_true(screen.get_node("%TempleCard").visible)
	assert_eq(screen.get_node("%TempleArt").color, screen.TEMPLE_TIER_COLORS[1])
	assert_eq(screen.get_node("%TempleName").text, tr("encampment.building.temple.tier1"))
	assert_eq(screen.get_node("%TempleLevel").text, tr("encampment.building.level") % 1)


func test_shop_card_shows_tier_one_art_and_name_at_the_default_level() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	assert_true(screen.get_node("%ShopCard").visible)
	assert_eq(screen.get_node("%ShopArt").color, screen.SHOP_TIER_COLORS[1])
	assert_eq(screen.get_node("%ShopName").text, tr("encampment.building.shop.tier1"))


func test_shop_card_updates_through_every_tier_after_refresh() -> void:
	var screen: Control = EncampmentScene.instantiate()
	add_child_autofree(screen)

	GameSession.shop_level = 2
	screen.refresh()
	assert_eq(screen.get_node("%ShopArt").color, screen.SHOP_TIER_COLORS[2])
	assert_eq(screen.get_node("%ShopName").text, tr("encampment.building.shop.tier2"))

	GameSession.shop_level = 3
	screen.refresh()
	assert_eq(screen.get_node("%ShopArt").color, screen.SHOP_TIER_COLORS[3])
	assert_eq(screen.get_node("%ShopName").text, tr("encampment.building.shop.tier3"))
