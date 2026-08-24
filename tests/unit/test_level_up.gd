extends GutTest

## Task 3: the immediate, modal level-up overlay. LevelUp reads fresh
## GameSession data for exactly one adventurer id, spends attack points and
## chooses perks only through GameSession's validated mutation APIs, and
## never calls GameManager or changes scenes itself — it only emits a
## completion signal that its owner (Battlefield) reacts to.
##
## Step 2 (docs/plans/2026-08-21-stage-2-party-readiness/
## 02-class-progression-and-perks.md) replaced the single hard-coded
## ChooseBonusMoveButton with dynamic per-class perk option buttons -- one
## Button per GameSession.get_available_perks() entry, addressed by name
## ("PerkOption_<perk_id>") rather than a fixed node path, so these tests
## exercise the real .tscn signal wiring the same way a class-name switch or
## a second hard-coded button never could.

const LevelUpScene := preload("res://scenes/ui/level_up.tscn")


func before_each() -> void:
	GameSession.reset()
	GameSession.create_party()
	GameSession.assign_adventurer_to_selected_party(GameSession.WARRIOR_ID)


func _open_level_up(adventurer_id: String, health_before: int) -> Control:
	var level_up: Control = LevelUpScene.instantiate()
	add_child_autofree(level_up)
	level_up.show_for_adventurer(adventurer_id, health_before)
	return level_up


func _perk_option_button(level_up: Control, perk_id: String) -> Button:
	return level_up.perk_options_container.get_node_or_null("PerkOption_%s" % perk_id)


func test_shows_xp_level_health_gain_and_skill_gains_after_a_level_up() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 20.0)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 10)

	assert_eq(level_up.name_label.text, "Warrior")
	assert_eq(level_up.xp_label.text, tr("level_up.xp") % 20)
	assert_eq(level_up.level_label.text, tr("level_up.level") % 2)
	assert_eq(level_up.health_gain_label.text, tr("level_up.health_gain") % [20, 10])
	assert_true(level_up.skill_gains_label.text.contains("Gained Skills:"))
	assert_true(level_up.visible)


## Level 2 now earns its own pending perk slot (PERK_LEVEL_INTERVAL == 2), so
## this resolves it up front (a real player action, not a UI bypass) to
## reach a genuinely "nothing left pending" open -- the same shape as
## test_a_level_with_no_perks_left_to_offer_shows_no_perk_controls_and_never_
## blocks_continue below, just at a lower level.
func test_continue_is_free_on_an_ordinary_level_and_emits_resolved() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 20.0)
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.WARRIOR_JUGGERNAUT_PERK_ID)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 3)
	watch_signals(level_up)

	assert_false(level_up.continue_button.disabled, "Level 2's own perk slot is already resolved")
	level_up.continue_button.emit_signal("pressed")

	assert_signal_emitted(level_up, "resolved")
	assert_false(level_up.visible, "Continue should close the modal")


## At level 3, a Warrior has exactly two eligible options -- Juggernaut and
## Bulwark, in GameSession.CLASS_PERKS' own order -- rendered as real Button
## nodes rather than one fixed ChooseBonusMoveButton.
func test_a_pending_level_shows_exactly_the_warriors_own_two_perk_options() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 50.0)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 3)

	assert_true(level_up.perk_label.visible)
	assert_eq(level_up.perk_options_container.get_child_count(), 2)
	assert_not_null(_perk_option_button(level_up, GameSession.WARRIOR_JUGGERNAUT_PERK_ID))
	assert_not_null(_perk_option_button(level_up, GameSession.WARRIOR_BULWARK_PERK_ID))
	assert_eq(
		_perk_option_button(level_up, GameSession.WARRIOR_JUGGERNAUT_PERK_ID).text,
		"%s (%s)" % [
			GameSession.get_perk_display_name(GameSession.WARRIOR_JUGGERNAUT_PERK_ID),
			GameSession.get_perk_effect_description(GameSession.WARRIOR_JUGGERNAUT_PERK_ID),
		]
	)


func test_continue_stays_disabled_until_a_pending_level_three_perk_is_chosen() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 50.0)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 3)
	watch_signals(level_up)

	assert_true(level_up.continue_button.disabled)
	assert_true(level_up.perk_label.visible)

	level_up.continue_button.emit_signal("pressed")
	assert_signal_not_emitted(level_up, "resolved")
	assert_true(level_up.visible, "A required perk choice must block dismissal")

	_perk_option_button(level_up, GameSession.WARRIOR_JUGGERNAUT_PERK_ID).emit_signal("pressed")

	assert_true(
		GameSession.get_adventurer(GameSession.WARRIOR_ID).progression.perks.has(
			GameSession.WARRIOR_JUGGERNAUT_PERK_ID
		)
	)
	assert_false(level_up.continue_button.disabled)
	assert_false(level_up.perk_label.visible)

	level_up.continue_button.emit_signal("pressed")
	assert_signal_emitted(level_up, "resolved")


## Choosing one perk immediately re-renders the option list down to only the
## still-available one (dynamic, not a fixed two-button layout) -- a level 6
## Warrior who already resolved level 3's slot only ever sees the remaining
## perk, never a re-offer of the one already chosen.
func test_choosing_a_perk_removes_it_from_the_remaining_options() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 50.0)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 3)

	_perk_option_button(level_up, GameSession.WARRIOR_JUGGERNAUT_PERK_ID).emit_signal("pressed")

	assert_eq(level_up.perk_options_container.get_child_count(), 0, "The slot is resolved, so no options remain")
	assert_null(_perk_option_button(level_up, GameSession.WARRIOR_JUGGERNAUT_PERK_ID))


func test_choosing_the_perk_uses_game_sessions_choose_perk_api() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 50.0)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 3)

	_perk_option_button(level_up, GameSession.WARRIOR_BULWARK_PERK_ID).emit_signal("pressed")

	assert_eq(
		GameSession.get_adventurer(GameSession.WARRIOR_ID).progression.perks,
		[GameSession.WARRIOR_BULWARK_PERK_ID]
	)


## See test_continue_is_free_on_an_ordinary_level_and_emits_resolved's own
## doc comment: level 2's own perk slot must be resolved first now that
## PERK_LEVEL_INTERVAL == 2, or this would not actually be an "ordinary"
## (nothing pending) open.
func test_an_ordinary_level_never_shows_the_perk_controls() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 20.0)
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.WARRIOR_JUGGERNAUT_PERK_ID)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 3)

	assert_false(level_up.perk_label.visible)
	assert_eq(level_up.perk_options_container.get_child_count(), 0)


## Once both of a class's perks are already chosen, is_perk_choice_pending()
## is permanently false (docs/designs/class-system.md) -- no "no perks
## available" empty state is needed, and Continue is never blocked again.
func test_a_level_with_no_perks_left_to_offer_shows_no_perk_controls_and_never_blocks_continue() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 200.0)  # level 6: both slots earned
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.WARRIOR_JUGGERNAUT_PERK_ID)
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.WARRIOR_BULWARK_PERK_ID)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 3)

	assert_false(level_up.perk_label.visible)
	assert_eq(level_up.perk_options_container.get_child_count(), 0)
	assert_false(level_up.continue_button.disabled)


## Stage 6 Step 4 (task 5, G3): a Knight with a pending slot but Discipline
## not yet chosen sees Shield Bash/Chain Blow rendered as disabled, locked
## rows (not silently omitted) -- so the player can see the branch choice
## coming before it is actually reachable.
func test_a_knights_locked_branch_perks_render_as_disabled_rows_before_discipline_is_chosen() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 350.0)  # level 8: 4 total slots
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.WARRIOR_JUGGERNAUT_PERK_ID)
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.WARRIOR_BULWARK_PERK_ID)
	GameSession.promote_adventurer(GameSession.WARRIOR_ID, "knight")
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 3)

	var discipline_button := _perk_option_button(level_up, GameSession.KNIGHT_DISCIPLINE_PERK_ID)
	assert_not_null(discipline_button)
	assert_false(discipline_button.disabled, "Discipline is the real, currently choosable option")

	var shield_bash_row := _perk_option_button(level_up, GameSession.KNIGHT_SHIELD_BASH_PERK_ID)
	assert_not_null(shield_bash_row, "Shield Bash must still be shown -- as a locked row, not omitted")
	assert_true(shield_bash_row.disabled, "A locked perk must not be choosable yet")

	var chain_blow_row := _perk_option_button(level_up, GameSession.KNIGHT_CHAIN_BLOW_PERK_ID)
	assert_not_null(chain_blow_row)
	assert_true(chain_blow_row.disabled)


## Once Discipline is chosen, both branches become real choosable options --
## no locked rows remain for them.
func test_a_knights_branch_perks_become_choosable_once_discipline_is_chosen() -> void:
	GameSession.award_party_xp(GameSession.FIRST_PARTY_ID, 350.0)
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.WARRIOR_JUGGERNAUT_PERK_ID)
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.WARRIOR_BULWARK_PERK_ID)
	GameSession.promote_adventurer(GameSession.WARRIOR_ID, "knight")
	GameSession.choose_perk(GameSession.WARRIOR_ID, GameSession.KNIGHT_DISCIPLINE_PERK_ID)
	var level_up := _open_level_up(GameSession.WARRIOR_ID, 3)

	var shield_bash_button := _perk_option_button(level_up, GameSession.KNIGHT_SHIELD_BASH_PERK_ID)
	assert_not_null(shield_bash_button)
	assert_false(shield_bash_button.disabled)
	var chain_blow_button := _perk_option_button(level_up, GameSession.KNIGHT_CHAIN_BLOW_PERK_ID)
	assert_not_null(chain_blow_button)
	assert_false(chain_blow_button.disabled)

	shield_bash_button.emit_signal("pressed")

	assert_null(
		level_up.perk_options_container.get_node_or_null("PerkOption_%s" % GameSession.KNIGHT_CHAIN_BLOW_PERK_ID),
		"Once Shield Bash is chosen and no slot remains pending, the perk section shows nothing at all"
	)


func test_level_up_never_calls_game_manager_or_changes_scenes() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/level_up.gd")
	assert_false(source.contains("GameManager"))
	assert_false(source.contains("change_scene"))
