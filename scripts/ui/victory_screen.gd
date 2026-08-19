extends Control

## Dedicated Campaign Victory screen (docs/plans/2026-08-18-core-loop-and-
## engagement/05-authored-encounters-and-final-boss.md), routed to exactly
## once per campaign by Battlefield._finish_victory() the moment defeating
## the final boss flips GameSession.is_campaign_completed true. Unlike
## battle_result.gd's transient GameManager.battle_result_summary payload,
## every stat here is durable GameSession state already current by the time
## this screen opens (see GameSession.get_campaign_victory_summary()), so
## _ready() reads it directly rather than through a routing payload.
##
## By the time this screen is visible, GameSession.is_free_play_active is
## already true (set_campaign_victory() flips both flags atomically) --
## [Continue] only navigates home; it does not itself toggle Free Play.

@onready var turns_label: Label = $Center/VBox/TurnsLabel
@onready var battles_label: Label = $Center/VBox/BattlesLabel
@onready var casualties_label: Label = $Center/VBox/CasualtiesLabel
@onready var gold_label: Label = $Center/VBox/GoldLabel
@onready var upgrades_label: Label = $Center/VBox/UpgradesLabel
@onready var continue_button: Button = $Center/VBox/ContinueButton


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	var summary := GameSession.get_campaign_victory_summary()
	turns_label.text = tr("victory.stat.turns") % int(summary.get("world_turns", 0))
	battles_label.text = tr("victory.stat.battles_won") % int(summary.get("battles_won", 0))
	casualties_label.text = tr("victory.stat.casualties") % int(summary.get("casualties", 0))
	gold_label.text = tr("victory.stat.gold_banked") % int(summary.get("gold_banked", 0))
	upgrades_label.text = tr("victory.stat.upgrades") % int(summary.get("upgrades_completed", 0))


func _on_continue_pressed() -> void:
	GameManager.go_to_encampment()
