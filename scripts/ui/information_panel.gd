extends PanelContainer

## Raised when the party View button is pressed. The panel never navigates
## itself; the owning screen (via GameManager) decides what happens next.
signal party_selected(party_id: String)

## Raised when the adventurer View button is pressed, for the same reason.
signal adventurer_selected(adventurer_id: String)

## Raised when the Recruit button is pressed. Like the two signals above,
## the panel never purchases by itself; the owning screen (via GameManager)
## decides what happens next (see recruitment.gd).
signal recruit_selected(candidate_id: String)

## Raised when the Send Party button is pressed (Stage 5 D5, docs/designs/
## world-map-and-encounters.md's "Future multi-party model"). Like every
## other signal above, the panel never opens the Send Party modal itself --
## world_map.gd owns that -- it only forwards which encounter was chosen.
signal send_party_requested(encounter_id: String)

@onready var player_name_label: Label = $Content/PlayerName
@onready var gold_label: Label = $Content/Gold
@onready var party_name_label: Label = $Content/PartyName
@onready var party_members_label: Label = $Content/PartyMembers
@onready var party_gold_label: Label = $Content/PartyGold
@onready var party_destination_label: Label = $Content/PartyDestination
@onready var party_view_button: Button = $Content/PartyViewButton
@onready var adventurer_name_label: Label = $Content/AdventurerName
@onready var adventurer_class_label: Label = $Content/AdventurerClass
@onready var adventurer_level_label: Label = $Content/AdventurerLevel
@onready var adventurer_view_button: Button = $Content/AdventurerViewButton
@onready var recruitment_name_label: Label = $Content/RecruitmentName
@onready var recruitment_class_label: Label = $Content/RecruitmentClass
@onready var recruitment_level_label: Label = $Content/RecruitmentLevel
@onready var recruitment_cost_label: Label = $Content/RecruitmentCost
@onready var recruit_button: Button = $Content/RecruitButton
@onready var encounter_danger_label: Label = $Content/EncounterDanger
@onready var encounter_enemies_label: Label = $Content/EncounterEnemies
## Intelligence system rows (Stage 5 Step 2, docs/designs/intelligence.md).
## Deliberately separate nodes from encounter_danger_label/encounter_enemies_
## label above rather than a shared rendering path: those two stay reserved
## for the pre-existing Scout-in-range reveal (GameSession.get_party_
## scouting_intel(), docs/plans/2026-08-18-core-loop-and-engagement/
## 04-cleric-class-and-scout-reconnaissance.md's locked decision) with its
## own dedicated test coverage this step does not touch. The two rendering
## paths stay separate calls, but they are mutually exclusive *per fact*:
## once the new encounter_intel record knows a fact, its own row is the sole
## place that fact renders and refresh_encounter() suppresses the matching
## legacy row -- see refresh_encounter()'s and refresh_encounter_intel()'s
## own doc comments for the exact per-row threshold.
@onready var intel_tier_label: Label = $Content/EncounterIntelTier
@onready var intel_enemies_label: Label = $Content/EncounterIntelEnemies
@onready var intel_quest_label: Label = $Content/EncounterIntelQuest
## Stage 5 D5 (Step 6): the "turns until next threat star" counter and the
## Send Party button -- see refresh_encounter_intel()'s own doc comment for
## the escalation counter, and refresh_encounter_send_party()'s for why Send
## Party is a separate, additive call rather than folded into either
## existing refresh_encounter()/refresh_encounter_intel() method.
@onready var escalation_label: Label = $Content/EncounterEscalation
@onready var send_party_button: Button = $Content/SendPartyButton

var _selected_party_id: String = ""
var _selected_adventurer_id: String = ""
var _selected_recruitment_candidate_id: String = ""
var _selected_encounter_id: String = ""


func _ready() -> void:
	party_view_button.pressed.connect(_on_party_view_button_pressed)
	adventurer_view_button.pressed.connect(_on_adventurer_view_button_pressed)
	recruit_button.pressed.connect(_on_recruit_button_pressed)
	send_party_button.pressed.connect(_on_send_party_button_pressed)
	refresh()


## Renders only the permanent player/gold rows and hides any optional party,
## adventurer, or recruitment summary. Screens with no row selection (e.g.
## Encampment) call this directly.
func refresh() -> void:
	_refresh_permanent_rows()
	_clear_party_section()
	_clear_adventurer_section()
	_clear_recruitment_section()
	_clear_encounter_section()


## Shows the permanent rows plus the named party's name, member count, and a
## View action. An unknown party_id clears the optional section instead of
## raising an error, so a stale selection never leaves the panel broken.
## carried_gold is the caller's unbanked GameSession.get_party_carry(party_id)
## .gold for this party (World Map is the only caller that has one to show);
## it renders as an extra row only when positive, and stays hidden otherwise.
func refresh_party(party_id: String, carried_gold: int = 0) -> void:
	_refresh_permanent_rows()
	_clear_adventurer_section()
	_clear_recruitment_section()
	_clear_encounter_section()

	var party := GameSession.get_party(party_id)
	if party.is_empty():
		_clear_party_section()
		return

	_selected_party_id = party_id
	party_name_label.text = tr("information.party") % party["name"]
	party_members_label.text = tr("information.members") % party["member_ids"].size()
	party_view_button.text = tr("information.view_party")
	party_name_label.visible = true
	party_members_label.visible = true
	party_view_button.visible = true
	party_gold_label.visible = carried_gold > 0
	if carried_gold > 0:
		party_gold_label.text = tr("information.party_gold") % carried_gold

	# Stage 5 D5, docs/designs/world-map-and-encounters.md's "Future
	# multi-party model": "Selecting a party shows its destination and
	# remaining travel time." Only meaningful for a deployed party with a
	# committed route -- an encamped or route-less party shows nothing here.
	var route: Array = party.get("travel_route", [])
	party_destination_label.visible = bool(party.get("deployed", false)) and not route.is_empty()
	if party_destination_label.visible:
		var destination: Vector2i = route[route.size() - 1]
		party_destination_label.text = tr("information.party_destination") % [
			_destination_name_for_position(destination), route.size()
		]


## Shows the permanent rows plus the named adventurer's name, class, level,
## and a View action. An unknown adventurer_id clears the optional section
## safely.
func refresh_adventurer(adventurer_id: String) -> void:
	_refresh_permanent_rows()
	_clear_party_section()
	_clear_recruitment_section()
	_clear_encounter_section()

	var adventurer := GameSession.get_adventurer(adventurer_id)
	if adventurer.is_empty():
		_clear_adventurer_section()
		return

	_selected_adventurer_id = adventurer_id
	adventurer_name_label.text = adventurer["name"]
	adventurer_class_label.text = tr("information.class") % adventurer["class"]
	adventurer_level_label.text = tr("information.level") % adventurer["level"]
	adventurer_name_label.visible = true
	adventurer_class_label.visible = true
	adventurer_level_label.visible = true
	adventurer_view_button.visible = true


## Shows the permanent rows plus the named recruitment candidate's name,
## class, level, cost, and a Recruit action. An unknown candidate_id (already
## purchased, or otherwise stale) clears the optional section safely, same
## as refresh_party()/refresh_adventurer(). The Recruit action is re-derived
## from GameSession.gold on every call, so re-selecting the same candidate
## after gold changed always reflects the current affordability rather than
## an earlier refresh's state.
func refresh_recruitment_candidate(candidate_id: String) -> void:
	_refresh_permanent_rows()
	_clear_party_section()
	_clear_adventurer_section()
	_clear_encounter_section()

	var candidate := _find_recruitment_candidate(candidate_id)
	if candidate.is_empty():
		_clear_recruitment_section()
		return

	_selected_recruitment_candidate_id = candidate_id
	recruitment_name_label.text = candidate["name"]
	recruitment_class_label.text = tr("information.class") % candidate["class"]
	recruitment_level_label.text = tr("information.level") % candidate["level"]
	# information.recruitment_cost is substituted as the label VALUE here, not
	# used as the format string like every other row above/below (e.g.
	# tr("information.class") % ...). Keep its translation a plain label word
	# with no %d/%s of its own — the numeric placeholder already lives in
	# this line's "%s %d" template.
	recruitment_cost_label.text = "%s %d" % [tr(&"information.recruitment_cost"), candidate["cost"]]
	recruitment_name_label.visible = true
	recruitment_class_label.visible = true
	recruitment_level_label.visible = true
	recruitment_cost_label.visible = true
	recruit_button.visible = true
	recruit_button.disabled = GameSession.gold < int(candidate["cost"])


## Shows the permanent rows plus a World Map encounter's Scout intel (see
## GameSession.get_party_scouting_intel(), docs/plans/2026-08-18-core-loop-
## and-engagement/04-cleric-class-and-scout-reconnaissance.md). Per index.md's
## locked decision, BOTH the danger-tier row and the enemy-composition row
## only appear once get_party_scouting_intel() reports has_intel (a deployed
## party with a Scout within range) -- an encounter outside Scout range shows
## neither, matching World Map's own marker (see world_map.gd's
## _draw_markers(), which gates its star label the same way). Never shows
## reward/loot or in-battle positions. An unknown party or encounter id
## clears the section safely, same as the other refresh_*() methods.
##
## The danger row renders GameSession.get_threat_stars(encounter_id) -- the
## same dynamic 1-5 rating world_map.gd's own marker label renders (see
## _get_marker_star_text()) -- rather than intel.danger_tier, which is
## static at the encounter's base difficulty forever. Reading the static
## field here would let this panel and the World Map marker disagree the
## moment world_turn crosses a THREAT_TURN_INTERVAL boundary (Step 5 review
## Finding 4).
##
## The enemy row renders every group in intel.enemy_types/enemy_counts (see
## get_party_scouting_intel()'s doc comment) rather than just the first
## group's type paired with the summed enemy_count -- a mixed authored
## formation (e.g. the pre-boss Gatehouse's 2 Hobgoblin Elite/2 Goblin
## Archer/1 Kobold Swarmer) would otherwise misreport as one type times the
## total (Step 5 review Finding 5).
##
## Mutual exclusion with the Intelligence system (Stage 5 Step 2 review
## finding): a deployed Scout's binary in-range reveal and the new
## accumulating encounter_intel record are independent systems that can both
## be true for the same encounter at once (e.g. a Watchtower or a Guild Hall
## quest already taught the new system what the Scout also currently sees).
## Rendering both would show the same fact ("Danger: X" / "Enemies: Y")
## twice in one panel. Once encounter_intel has learned a fact, its own row
## in refresh_encounter_intel() becomes that fact's single source of truth,
## so this method suppresses the matching legacy row rather than showing it
## a second time: the danger row is suppressed once known_tier reaches
## INTEL_TIER_LEVEL (the same threshold that unlocks intel_tier_label), and
## the enemy row is suppressed once known_tier reaches INTEL_TIER_MAIN_
## MONSTER (the same threshold that unlocks intel_enemies_label). An
## encounter with no Stage 5 intel yet (known_tier == INTEL_TIER_NONE) is
## unaffected -- the legacy row is this method's only source for it, exactly
## as before this fix.
func refresh_encounter(party_id: String, encounter_id: String) -> void:
	_refresh_permanent_rows()
	_clear_party_section()
	_clear_adventurer_section()
	_clear_recruitment_section()

	var intel := GameSession.get_party_scouting_intel(party_id, encounter_id)
	if intel.is_empty() or not bool(intel.has_intel):
		_clear_encounter_section()
		return

	_selected_encounter_id = encounter_id
	var known_tier: int = int(GameSession.get_encounter_intel(encounter_id).get("known_tier", GameSession.INTEL_TIER_NONE))

	encounter_danger_label.visible = known_tier < GameSession.INTEL_TIER_LEVEL
	if encounter_danger_label.visible:
		var stars := "★".repeat(clampi(GameSession.get_threat_stars(encounter_id), 1, 5))
		encounter_danger_label.text = tr("information.encounter_danger") % stars

	encounter_enemies_label.visible = known_tier < GameSession.INTEL_TIER_MAIN_MONSTER
	if not encounter_enemies_label.visible:
		return

	var enemy_types: Array = intel.get("enemy_types", [])
	var enemy_counts: Array = intel.get("enemy_counts", [])
	var breakdown: Array[String] = []
	for i in enemy_types.size():
		var count: int = int(enemy_counts[i]) if i < enemy_counts.size() else int(intel.enemy_count)
		breakdown.append(tr("information.encounter_enemies") % [String(enemy_types[i]), count])
	encounter_enemies_label.text = ", ".join(breakdown)


## Shows the Intelligence system's own progressively-revealed rows for a
## World Map encounter (docs/designs/intelligence.md, Stage 5 Step 2) --
## deliberately a separate call from refresh_encounter() above rather than a
## merged rendering path, so the pre-existing Scout-in-range reveal (and its
## own dedicated test coverage) is never touched by this step. A caller that
## wants both systems' available information calls refresh_encounter() first
## and this second, in that order -- see world_map.gd's
## _refresh_information_panel(). Renders three independent rows, exactly
## matching the design's own ordered tiers:
## - Tier level (stars): visible once known_tier reaches INTEL_TIER_LEVEL.
## - Enemies: visible once known_tier reaches INTEL_TIER_MAIN_MONSTER, first
##   as a type-only list (Main monster/All monsters tiers), then with counts
##   once INTEL_TIER_MONSTER_COUNTS is reached.
## - Quest: visible only when the encounter carries a quest (posted,
##   accepted, or expired) -- an accepted quest's "Tier level + Main
##   monster only" reveal falls naturally out of accept_quest() setting
##   known_tier to INTEL_TIER_MAIN_MONSTER, not out of any special-casing
##   here.
## An undiscovered (or unknown) encounter_id clears the whole section, same
## as every other refresh_*() method's not-found convention.
func refresh_encounter_intel(encounter_id: String) -> void:
	var intel := GameSession.get_encounter_intel(encounter_id)
	if not bool(intel.get("discovered", false)):
		_clear_encounter_intel_section()
		return

	_selected_encounter_id = encounter_id
	var known_tier: int = int(intel.get("known_tier", 0))

	intel_tier_label.visible = known_tier >= GameSession.INTEL_TIER_LEVEL
	if intel_tier_label.visible:
		var stars := "★".repeat(clampi(GameSession.get_threat_stars(encounter_id), 1, 5))
		intel_tier_label.text = tr("information.encounter_danger") % stars

	# Stage 5 D5 (decision-ledger.md): the bounded time-escalation counter,
	# shown alongside the tier-stars row it explains -- only once the tier is
	# actually known (matching intel_tier_label's own visibility threshold),
	# and only while GameSession.get_turns_until_next_threat_star() reports
	# further escalation is possible (its own -1 "already capped at five
	# stars" sentinel hides this row rather than showing a misleading count).
	var turns_until_next_star := GameSession.get_turns_until_next_threat_star(encounter_id)
	escalation_label.visible = intel_tier_label.visible and turns_until_next_star >= 0
	if escalation_label.visible:
		escalation_label.text = tr("information.turns_until_next_threat_star") % turns_until_next_star

	var intel_enemy_types: Array = intel.get("enemy_types", [])
	var intel_enemy_counts: Array = intel.get("enemy_counts", [])
	intel_enemies_label.visible = not intel_enemy_types.is_empty()
	if intel_enemies_label.visible:
		var counts_known: bool = known_tier >= GameSession.INTEL_TIER_MONSTER_COUNTS
		var intel_breakdown: Array[String] = []
		for i in intel_enemy_types.size():
			if counts_known:
				intel_breakdown.append(tr("information.encounter_enemies") % [String(intel_enemy_types[i]), int(intel_enemy_counts[i])])
			else:
				intel_breakdown.append(tr("information.encounter_enemy_type_only") % String(intel_enemy_types[i]))
		intel_enemies_label.text = ", ".join(intel_breakdown)

	var quest_id := String(intel.get("quest_id", ""))
	var quest := GameSession.get_quest(quest_id) if quest_id != "" else {}
	intel_quest_label.visible = not quest.is_empty()
	if intel_quest_label.visible:
		intel_quest_label.text = tr("information.encounter_quest") % [
			tr("guild_hall.quests.status.%s" % String(quest.status)), int(quest.reward_gold)
		]


## Send Party (Stage 5 D5, docs/designs/world-map-and-encounters.md's "Future
## multi-party model"): "If there are eligible parties, the right panel
## offers Send Party." A strictly additive third call alongside refresh_
## encounter()/refresh_encounter_intel() -- the same "own call, own doc
## comment" pattern refresh_encounter_intel() already established relative to
## refresh_encounter() -- because Send Party's own eligibility (any deployed
## party exists at all) is independent of Scout intel: refresh_encounter()'s
## own "no intel" branch clears the whole encounter section, which would
## otherwise wrongly hide Send Party for an encounter outside every deployed
## party's Scout range. Never opens the modal itself -- see send_party_
## requested, forwarded to world_map.gd via _on_send_party_button_pressed().
func refresh_encounter_send_party(encounter_id: String) -> void:
	_selected_encounter_id = encounter_id
	send_party_button.visible = not GameSession.get_deployed_parties().is_empty()


## Resolves a World Map tile position to a display name for refresh_party()'s
## destination row: the Encampment, a live sandbox encounter instance, or the
## current authored campaign objective's own node -- the same three position
## sources world_map.gd's own marker-drawing code already reads from
## (GameSession.get_active_encounters()/get_current_campaign_objective()).
## Falls back to a generic "unknown" label rather than crashing on a position
## that matches none of them (should not happen in practice, since a route's
## final tile is always one a player actually clicked to commit).
func _destination_name_for_position(position: Vector2i) -> String:
	if position == GameSession.STARTING_SETTLEMENT_WORLD_POSITION:
		return tr("encampment.title")
	for record in GameSession.get_active_encounters():
		if record.position == position:
			return tr(str(record.get("name_key", "")))
	var objective := GameSession.get_current_campaign_objective()
	var encounter_id: String = objective.get("encounter_id", "")
	if encounter_id != "":
		var expedition := GameSession.get_expedition(encounter_id)
		if expedition.get("position") == position:
			return tr(str(expedition.get("name_key", "")))
	return tr("information.party_destination_unknown")


## Candidates are resolved fresh from GameSession.get_recruitment_candidates()
## rather than trusting anything cached locally, matching how refresh_party()/
## refresh_adventurer() always re-resolve their own ids.
func _find_recruitment_candidate(candidate_id: String) -> Dictionary:
	for candidate in GameSession.get_recruitment_candidates():
		if candidate.id == candidate_id:
			return candidate
	return {}


func _refresh_permanent_rows() -> void:
	player_name_label.text = tr("information.player") % GameSession.player_name
	gold_label.text = tr("information.gold") % GameSession.gold


func _clear_party_section() -> void:
	_selected_party_id = ""
	party_name_label.visible = false
	party_members_label.visible = false
	party_view_button.visible = false
	party_gold_label.visible = false
	party_destination_label.visible = false


func _clear_adventurer_section() -> void:
	_selected_adventurer_id = ""
	adventurer_name_label.visible = false
	adventurer_class_label.visible = false
	adventurer_level_label.visible = false
	adventurer_view_button.visible = false


## Disabled here in addition to hidden, so the Recruit action always starts
## (or falls back to) disabled-by-default rather than merely invisible.
func _clear_recruitment_section() -> void:
	_selected_recruitment_candidate_id = ""
	recruitment_name_label.visible = false
	recruitment_class_label.visible = false
	recruitment_level_label.visible = false
	recruitment_cost_label.visible = false
	recruit_button.visible = false
	recruit_button.disabled = true


func _clear_encounter_section() -> void:
	_selected_encounter_id = ""
	encounter_danger_label.visible = false
	encounter_enemies_label.visible = false
	_clear_encounter_intel_section()
	_clear_send_party_section()


## Intelligence system rows (see intel_tier_label's own doc comment) --
## factored out of _clear_encounter_section() so refresh_encounter_intel()
## can also call it directly without touching the unrelated legacy fields.
func _clear_encounter_intel_section() -> void:
	intel_tier_label.visible = false
	intel_enemies_label.visible = false
	intel_quest_label.visible = false
	escalation_label.visible = false


## Send Party's own row (see refresh_encounter_send_party()'s doc comment) --
## factored out the same way _clear_encounter_intel_section() is, so a caller
## that only wants to clear Send Party's affordance can do so without
## touching the unrelated legacy/intel rows.
func _clear_send_party_section() -> void:
	send_party_button.visible = false


func _on_party_view_button_pressed() -> void:
	party_selected.emit(_selected_party_id)


func _on_adventurer_view_button_pressed() -> void:
	adventurer_selected.emit(_selected_adventurer_id)


func _on_recruit_button_pressed() -> void:
	recruit_selected.emit(_selected_recruitment_candidate_id)


func _on_send_party_button_pressed() -> void:
	send_party_requested.emit(_selected_encounter_id)
