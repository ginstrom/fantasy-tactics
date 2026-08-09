# Step 1: Party Details — Gold and Loot

> REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this task-by-task.

**Branch:** `party-details-gold-and-loot`

**Goal:** Party Details (`scenes/ui/party_details.tscn`) shows the
player's gold and banked loot (mana crystals + gear), so viewing a party
answers "what have we got" without leaving the screen. Navigation
(Back/View) is untouched — it already works.

**Files:**
- Modify: `scenes/ui/party_details.tscn`
- Modify: `scripts/ui/party_details.gd`
- Modify: `translations/en.tres`
- Modify: `tests/unit/test_party_details.gd`
- Modify: `tests/unit/test_localization.gd`

**Context you need:**
- `GameSession.gold: int` — the player's banked gold (single-party
  campaign, so this is unambiguously "the party's gold").
- `GameSession.mana_crystals: Dictionary` — `{tier: count}`, banked mana
  crystals.
- `GameSession.banked_gear: Dictionary` — `{item_id: count}`, banked gear.
  Note this is a **Dictionary of counts**, not an Array — summing it needs
  `for item_id in banked_gear: total += banked_gear[item_id]`, not
  `.size()` (that would undercount stacked items).
- `scripts/ui/information_panel.gd`'s `_refresh_carried_loot()` shows the
  same *shape* of loot line, but for **unbanked** (`pending_*`) loot — not
  reusable here since the underlying fields have different types
  (`pending_gear` is an `Array`, `banked_gear` is a `Dictionary`). Don't
  try to share code between them; write Party Details' own small helper.

## Step 1a: Add the gold and loot labels to the scene

- [ ] **Write the failing test**

Add to `tests/unit/test_party_details.gd` (after
`test_reads_the_party_id_from_route_context`, so it sits with the other
"screen contents" tests):

```gdscript
func test_party_details_shows_gold_and_banked_loot() -> void:
	GameSession.create_party()
	GameSession.gold = 250
	GameSession.mana_crystals = {1: 2, 2: 1}
	GameSession.banked_gear = {"dagger_iron": 1, "leather_armor": 2}
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	assert_eq(screen.get_node("Body/Center/VBox/GoldLabel").text, tr("party_details.gold") % 250)
	assert_eq(
		screen.get_node("Body/Center/VBox/LootLabel").text,
		tr("party_details.loot") % [3, 3],
		"3 mana crystals (2 tier-1 + 1 tier-2) and 3 gear pieces (1 dagger + 2 armor)"
	)


func test_party_details_shows_zero_gold_and_loot_on_a_fresh_session() -> void:
	GameSession.create_party()
	var screen := _open_party_details(GameSession.FIRST_PARTY_ID)

	assert_eq(screen.get_node("Body/Center/VBox/GoldLabel").text, tr("party_details.gold") % 0)
	assert_eq(screen.get_node("Body/Center/VBox/LootLabel").text, tr("party_details.loot") % [0, 0])
```

- [ ] **Run to verify it fails**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_party_details.gd -gunit_test_name=gold -gexit
```
Expected: FAIL — `GoldLabel`/`LootLabel` don't exist (node not found), and
the `party_details.gold`/`party_details.loot` translation keys don't
resolve yet (they'll `tr()` back to their own key name, which is harmless
for now since the node lookup fails first).

- [ ] **Add the translation keys**

In `translations/en.tres`, in the `party_details.*` block (after
`"party_details.title": "Party Details",`, before
`"party_details.members": "Members",`):

```
"party_details.gold": "Gold: %d",
"party_details.loot": "Loot: %d mana crystals, %d gear",
```

- [ ] **Add the localization regression test**

In `tests/unit/test_localization.gd`, find the `party_details.*`
assertions (search for `"party_details.title"`) and add immediately after
them:

```gdscript
	assert_eq(tr("party_details.gold") % 250, "Gold: 250")
	assert_eq(tr("party_details.loot") % [3, 2], "Loot: 3 mana crystals, 2 gear")
```

- [ ] **Add the two labels to the scene**

In `scenes/ui/party_details.tscn`, insert two `Label` nodes between
`PartyNameLabel` and `MembersLabel`:

```
[node name="GoldLabel" type="Label" parent="Body/Center/VBox"]
layout_mode = 2
horizontal_alignment = 1

[node name="LootLabel" type="Label" parent="Body/Center/VBox"]
layout_mode = 2
horizontal_alignment = 1
```

(Matches `PartyNameLabel`'s `horizontal_alignment = 1` centering — keep
the VBox's centered look consistent.)

- [ ] **Wire the labels in the script**

In `scripts/ui/party_details.gd`, add the two `@onready` fields next to
the existing ones:

```gdscript
@onready var gold_label: Label = $Body/Center/VBox/GoldLabel
@onready var loot_label: Label = $Body/Center/VBox/LootLabel
```

Add the population call inside `refresh()`, right after
`party_name_label.text = ...`:

```gdscript
func refresh() -> void:
	var party := GameSession.get_party(party_id)
	party_name_label.text = "" if party.is_empty() else party.name
	gold_label.text = tr("party_details.gold") % GameSession.gold
	loot_label.text = tr("party_details.loot") % [_banked_mana_crystal_count(), _banked_gear_count()]
	var rows := _build_rows(party)
	...
```

Add the two small helpers near the bottom of the file (after
`_build_rows`):

```gdscript
func _banked_mana_crystal_count() -> int:
	var total := 0
	for tier in GameSession.mana_crystals:
		total += GameSession.mana_crystals[tier]
	return total


func _banked_gear_count() -> int:
	var total := 0
	for item_id in GameSession.banked_gear:
		total += GameSession.banked_gear[item_id]
	return total
```

- [ ] **Run to verify it passes**

```
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_party_details.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_localization.gd -gexit
```
Expected: PASS, no other test in either file regresses (the new labels
sit between two existing nodes — `MemberTable`'s path and every other
`Body/Center/VBox/...` path used by other tests is unaffected since
`GoldLabel`/`LootLabel` are new siblings, not renames).

- [ ] **Commit**

```bash
git add scenes/ui/party_details.tscn scripts/ui/party_details.gd translations/en.tres tests/unit/test_party_details.gd tests/unit/test_localization.gd
git commit -m "feat: show gold and banked loot on Party Details"
```

## Manual verification

1. `make play`
2. From the Start Menu, press **FN+F9** to open the debug menu, click
   **Stocked Stores** (this stages an encamped party and sets
   `GameSession.mana_crystals = {1: 2}`, `GameSession.banked_gear =
   {"shortsword_iron": 1}` — non-zero values so the new labels are visibly
   populated, not just showing zero).
3. Navigate to Parties → the party row → View (or however this build's
   nav reaches Party Details for an encamped party).
4. Confirm you see `Gold: 0` (Stocked Stores doesn't set gold) and
   `Loot: 2 mana crystals, 1 gear`, positioned between the party name and
   the member table.
5. Click Back — confirm it still returns to Parties exactly as before
   (this step touches no navigation code, but confirm nothing broke).

## Full run and merge

```bash
make check
```
Expected: `N/N passed.` / `---- All tests passed! ----`, exit 0.

```bash
git checkout main
git merge party-details-gold-and-loot
git branch -d party-details-gold-and-loot
```
