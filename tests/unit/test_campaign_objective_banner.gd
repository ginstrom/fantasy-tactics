extends GutTest

## D9 presentation-standard gap fix (docs/designs/campaign-loop.md): the
## banner shows the current objective's title/description/progress but never
## states what unlocks next, even though GameSession.CAMPAIGN_OBJECTIVES
## already carries a forward-linked next_objective_id on every node. This
## file is the banner's own dedicated scene test -- prior coverage
## (test_encampment.gd, test_world_map.gd, test_first_campaign_ui_flow.gd)
## only asserts on the pre-existing title/desc/free-play fields through the
## screens that host the banner.

const CampaignObjectiveBannerScene := preload("res://scenes/ui/campaign_objective_banner.tscn")


func before_each() -> void:
	GameSession.reset()


func test_shows_the_next_objectives_title_when_a_next_objective_exists() -> void:
	var banner: Control = CampaignObjectiveBannerScene.instantiate()
	add_child_autofree(banner)

	# Fresh campaign: current objective is obj_tier1_1_goblin_outpost, whose
	# next_objective_id is obj_tier1_2_kobold_warren.
	assert_eq(GameSession.campaign_objective_id, "obj_tier1_1_goblin_outpost")
	var next_objective_label: Label = banner.get_node("Content/NextObjectiveLabel")

	assert_true(next_objective_label.visible)
	assert_eq(
		next_objective_label.text,
		tr("campaign.objective.next_label") % tr("campaign.obj.tier1_2.title")
	)


func test_shows_a_final_objective_state_when_the_current_objective_has_no_successor() -> void:
	var banner: Control = CampaignObjectiveBannerScene.instantiate()
	add_child_autofree(banner)
	var next_objective_label: Label = banner.get_node("Content/NextObjectiveLabel")

	# obj_boss_borderlands_ogre is the final authored node -- its
	# next_objective_id is "" (see GameSession.CAMPAIGN_OBJECTIVES).
	GameSession.campaign_objective_id = "obj_boss_borderlands_ogre"
	banner.refresh()

	assert_true(next_objective_label.visible)
	assert_eq(next_objective_label.text, tr("campaign.objective.final_label"))


func test_next_objective_label_updates_when_the_objective_advances() -> void:
	var banner: Control = CampaignObjectiveBannerScene.instantiate()
	add_child_autofree(banner)
	var next_objective_label: Label = banner.get_node("Content/NextObjectiveLabel")
	assert_eq(
		next_objective_label.text,
		tr("campaign.objective.next_label") % tr("campaign.obj.tier1_2.title")
	)

	GameSession.complete_campaign_objective("obj_tier1_1_goblin_outpost")

	assert_eq(
		next_objective_label.text,
		tr("campaign.objective.next_label") % tr("campaign.obj.tier1_3.title")
	)


func test_next_objective_label_hidden_during_free_play() -> void:
	var banner: Control = CampaignObjectiveBannerScene.instantiate()
	add_child_autofree(banner)
	var next_objective_label: Label = banner.get_node("Content/NextObjectiveLabel")

	GameSession.set_campaign_victory()

	assert_false(next_objective_label.visible)


## The banner is presentation-only (docs/dev/code-map.md: "scenes only
## render state, never create it") -- refresh() must be a pure read of
## GameSession.CAMPAIGN_OBJECTIVES/campaign_objective_id, never mutate them.
func test_refresh_does_not_mutate_game_session_state() -> void:
	var banner: Control = CampaignObjectiveBannerScene.instantiate()
	add_child_autofree(banner)
	var objective_id_before := GameSession.campaign_objective_id
	var completed_before := GameSession.completed_objectives.duplicate()

	banner.refresh()

	assert_eq(GameSession.campaign_objective_id, objective_id_before)
	assert_eq(GameSession.completed_objectives, completed_before)
