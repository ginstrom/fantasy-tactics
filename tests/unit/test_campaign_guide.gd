extends GutTest

## Covers scripts/ui/campaign_guide.gd/scenes/ui/campaign_guide.tscn in
## isolation: it renders whatever GameSession.get_campaign_guide_state()
## currently says, updates on refresh(), records an explicit dismissal
## through GameSession.record_campaign_guide_dismissal() and nothing else,
## and every part of it except the Dismiss button ignores mouse input. See
## test_game_session.gd for the guide-state derivation itself and
## test_first_campaign_ui_flow.gd for the real-click-through-the-pipeline
## regression this scene's IGNORE filters exist to prevent.

const CampaignGuideScene := preload("res://scenes/ui/campaign_guide.tscn")


func before_each() -> void:
	GameSession.reset()


func test_a_fresh_campaign_shows_the_form_party_message_and_ignores_mouse_input() -> void:
	var guide: PanelContainer = CampaignGuideScene.instantiate()
	add_child_autofree(guide)

	assert_true(guide.visible)
	assert_eq(guide.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(
		guide.get_node("%MessageLabel").text,
		tr("campaign_guide.form_party.message")
	)
	assert_eq(
		guide.get_node("%TargetLabel").text,
		tr("campaign_guide.form_party.target")
	)
	assert_true(guide.get_node("%TargetLabel").visible)


## Every ancestor between the root and the Dismiss button must ignore mouse
## input, or the button itself would never receive a click.
func test_every_node_but_the_dismiss_button_ignores_mouse_input() -> void:
	var guide: PanelContainer = CampaignGuideScene.instantiate()
	add_child_autofree(guide)

	assert_eq(guide.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(guide.get_node("Margin").mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(guide.get_node("Margin/VBox").mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(guide.message_label.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(guide.target_label.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_ne(guide.dismiss_button.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_dismiss_button_records_the_dismissal_and_hides_the_banner() -> void:
	var guide: PanelContainer = CampaignGuideScene.instantiate()
	add_child_autofree(guide)
	assert_true(guide.visible)

	guide.dismiss_button.emit_signal("pressed")

	assert_true(GameSession.tutorial_progress.get(GameSession.CAMPAIGN_GUIDE_FORM_PARTY, false))
	assert_false(guide.visible)
	assert_eq(GameSession.get_campaign_guide_state(), "")


## Dismissal must be the only campaign-state effect the banner ever causes
## -- it never routes anywhere and never touches any field but
## tutorial_progress.
func test_dismiss_button_never_mutates_unrelated_campaign_state() -> void:
	var guide: PanelContainer = CampaignGuideScene.instantiate()
	add_child_autofree(guide)

	guide.dismiss_button.emit_signal("pressed")

	assert_eq(GameSession.parties.size(), 0)
	assert_eq(GameSession.gold, 0)
	assert_false(GameSession.has_deployed_party())


func test_refresh_reflects_a_new_guide_state_without_reinstancing_the_scene() -> void:
	var guide: PanelContainer = CampaignGuideScene.instantiate()
	add_child_autofree(guide)
	assert_eq(
		guide.get_node("%MessageLabel").text,
		tr("campaign_guide.form_party.message")
	)

	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)
	guide.refresh()

	assert_eq(
		guide.get_node("%MessageLabel").text,
		tr("campaign_guide.deploy.message")
	)


func test_guide_stays_hidden_once_no_message_is_due() -> void:
	GameSession.record_campaign_guide_dismissal(GameSession.CAMPAIGN_GUIDE_FORM_PARTY)
	var guide: PanelContainer = CampaignGuideScene.instantiate()
	add_child_autofree(guide)

	assert_false(guide.visible)
