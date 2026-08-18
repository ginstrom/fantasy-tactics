extends PanelContainer

## Persistent campaign-objective indicator, instanced identically into
## Encampment and World Map (see docs/plans/2026-08-18-core-loop-and-
## engagement/01-campaign-state-and-onboarding.md). Unlike CampaignGuide (a
## one-shot tutorial nudge queue that retires each message as it's shown),
## this banner is always visible and simply reflects GameSession's durable
## campaign objective state -- it never mutates it. Self-subscribes to
## GameSession.campaign_progress_changed so it updates the moment an
## objective completes or the campaign is won, even if the owning screen
## never calls refresh() itself.

@onready var objective_label: Label = $Content/ObjectiveLabel
@onready var title_label: Label = $Content/TitleLabel
@onready var desc_label: Label = $Content/DescLabel
@onready var progress_bar: ProgressBar = $Content/ProgressBar
@onready var goal_label: Label = $Content/GoalLabel
@onready var free_play_label: Label = $Content/FreePlayLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameSession.campaign_progress_changed.connect(refresh)
	refresh()


## Safe to call as often as the owning screen likes -- reading GameSession's
## campaign state is free and this never mutates it.
func refresh() -> void:
	var free_play := GameSession.is_free_play_active
	objective_label.visible = not free_play
	title_label.visible = not free_play
	desc_label.visible = not free_play
	progress_bar.visible = not free_play
	goal_label.visible = not free_play
	free_play_label.visible = free_play

	if free_play:
		free_play_label.text = tr("campaign.free_play.active_label")
		return

	objective_label.text = tr("campaign.objective.label")
	var objective := GameSession.get_current_campaign_objective()
	title_label.text = tr(objective.get("title_key", ""))
	desc_label.text = tr(objective.get("desc_key", ""))
	goal_label.text = tr("campaign.victory.goal_label")
	progress_bar.max_value = GameSession.CAMPAIGN_OBJECTIVES.size()
	progress_bar.value = GameSession.completed_objectives.size()
