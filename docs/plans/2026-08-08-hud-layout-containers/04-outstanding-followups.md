# Outstanding follow-ups

Not a task in this plan — these are gaps and loose ends noticed while
delivering Tasks 1-3 (the Battlefield/World Map HUD refactor) and while
fixing the Guild Hall CampNav bug that came up right after. None of them
block what's already merged. Recorded here so they aren't lost; no
commitment yet on whether/when to act on any of them.

## 1. `InformationPanel` is corner-anchored, not container-driven, across ~9 Encampment-family screens

`InformationPanel` is instanced as a sibling of `Body` (not a child of it) in
`encampment.tscn`, `units.tscn`, `roster.tscn`, `parties.tscn`,
`party_details.tscn`, `deploy_party.tscn`, `add_member.tscn`,
`recruitment.tscn`, and `unit_details.tscn`, positioned via:

```
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -240.0
offset_top = 16.0
...
```

This is a fixed-width, corner-anchored panel — softer than the raw
top-left-origin offsets the Battlefield/World Map HUDs used to have (this
plan's Tasks 1-2), but it's still positioning driven by hardcoded numbers
rather than a container, and it's identical in spirit to what the World Map
HUD's `TurnLabel`/`EndTurnButton`/`InformationPanel` stack used to do before
Task 2 pulled them into `Body`'s container tree.

Open question, not yet decided: is a persistent corner-pinned info panel a
legitimate Rule 6 "floating window" exception (it never blocks the screen,
never needs to move), or should it become a third child of `Body`
(alongside `CampNav` and `Center`) like the World Map's `TopRight` stack is?
The nine screens are at least internally consistent with each other, so
this is a design call, not a bug.

## 2. `debug_menu.tscn`'s `Panel` uses raw offsets with no anchor

```
[node name="Panel" type="PanelContainer" parent="."]
offset_left = 24.0
offset_top = 24.0
offset_right = 324.0
offset_bottom = 462.0
```

No anchor at all — this is the "Avoid: Hardcoded pixel positions" case the
design doc calls out literally. Low priority: it's a developer-only debug
overlay (`F1`-style tool window, not player-facing), and arguably already
covered by the Rule 6 "floating windows" exception. Flagging for
completeness since it was noticed during the CanvasLayer survey for this
plan, not because it's causing a problem.

## 3. Leftover dead-weight `size_flags_horizontal = 8` on `battlefield.tscn`'s `TopRight`

Task 2 found and fixed a real bug in `world_map.tscn`: `size_flags_horizontal
= 8` (`SHRINK_END`) on a lone child of an `HBoxContainer` does nothing,
because shrink flags only affect the *cross* axis, not the axis an
`HBoxContainer` arranges children along. The World Map's `TopRight` had no
sibling to expand and consume the leftover space, so it rendered at the far
left instead of the right — fixed by setting `TopRow.alignment = 2`
(`ALIGNMENT_END`) instead.

`battlefield.tscn`'s `TopRight` (`scenes/battle/battlefield.tscn`, inside
`HUD/Margin/VBox/TopRow`) still carries that same inert
`size_flags_horizontal = 8` property from Task 1. It happens to render
correctly today only because its sibling `TopLeft` has
`size_flags_horizontal = 3` (`EXPAND_FILL`), which consumes the row's
leftover space and pushes `TopRight` to the end regardless of `TopRight`'s
own flag. The property is misleading (it looks load-bearing; it isn't) and
would silently break the same way World Map's did if `TopLeft` were ever
removed, hidden, or stopped expanding. Low risk, but worth either deleting
the dead flag or switching to `TopRow.alignment = 2` for consistency with
World Map's fix — a few minutes of cleanup, not investigated further here.

## 4. Guild Hall is missing from the screenshot tour

`scripts/tools/screenshot_tour.gd` has a step for every other top-level and
sub camp screen (Encampment, Units, Roster, Recruitment, Parties, Party
Details, Add Member, Unit Details, Deploy Party, World Map, Battlefield,
Debug Menu, Game Menu overlay) but none for Guild Hall
(`scenes/ui/guild_hall.tscn`). This meant the just-fixed missing-CampNav bug
couldn't have been caught by `make screenshots` diffing — only by the new
`test_guild_hall_contains_the_camp_nav` regression test (structural, not
visual) or a human looking at the actual screen. Adding a `guild_hall` step
(`GameManager.go_to_guild_hall()`, reached from Buildings) would close that
blind spot for future layout changes.
