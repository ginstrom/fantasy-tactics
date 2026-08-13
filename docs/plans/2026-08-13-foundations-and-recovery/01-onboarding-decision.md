# Step 1 — Initial-party / onboarding decision and its implementation

**Branch:** `onboarding-decision`
**Status:** pending
**Implements:** gap analysis §4 step 1 ("Decide the initial party/onboarding
target"), the cap-plumbing part of §2.1 item 2 ("Add party-slot and
party-size unlocking rules"), index constraint 6 (generated instance
identity), and `docs/designs/vision.md` → "Party management".

## Why this step exists

The shipped campaign opens with **one Warrior and no party**; the player
creates and staffs the first party, guided by `CAMPAIGN_GUIDE_SEQUENCE`
(form party → deploy → route → enter site → return & bank → first
improvement). `docs/designs/vision.md` instead says the player *"starts with
a single party of 4 members."* The gap analysis required this difference to
be an **explicit product decision** before any onboarding or balance change.
The decision was recorded on 2026-08-13 (below); this step records it in the
gap analysis and implements it: generated instance identity, the starting
roster and recruitment offers, and enforced+displayed party caps.

## The decision (recorded 2026-08-13)

Start with 4 warriors in the roster and 4 recruitable units -- 3 warriors and 1
scout. Maximum party size is 4, and maximum party count is 1. Player will
create and man a party before deploying.

Recorded alongside it (see the index's Decisions section):

- The vision's four-member starting party is satisfied by the player manning
  the single party from the starting roster — four warriors fill it exactly.
- The Guild Hall level 1 → 2 upgrade raising the party-size cap from 4 to 5
  is existing behavior and stays.
- The Guild Hall level 2 → 3 upgrade raising the party-count cap from 1 to 2
  is a recorded progression rule, but its implementation is **deferred to
  roadmap part 4** (§2.1) together with second-party creation and
  multi-party World Map behavior.

## Design

### Instance identity — generated ids (index constraint 6)

Every unit and item instance is identified by a hidden, generated id —
never by display name and never by class-derived sequential numbering. This
step introduces the rule at every minting site:

- New `GameSession._new_instance_id() -> String`: one shared helper
  generating collision-free GUID-style ids (Godot has no built-in UUID —
  compose from `randi()` blocks mixed with a
  `Time.get_unix_time_from_system()` fragment). Follow the injectable-roll
  convention (`vacancy_delay_roll`, `recruitment_class_roll`) so tests can
  pin the entropy and assert deterministically.
- Display names stay purely cosmetic, minted from the per-class count at
  creation time ("Warrior 5" for the fifth warrior minted). A duplicated
  name carries no correctness risk. Ids never appear in the UI.
- Previously minted ids (`warrior_001` in the roster, template-derived ids
  in old saves, `blacksmith_item_%03d` instances) persist as opaque strings
  — no save-wide re-mint, no `FORMAT_VERSION` bump.

### Starting roster — four warriors

`reset()` currently seeds one adventurer (`get_default_warrior()` →
`warrior_001`). Seed three more warriors alongside it.

- Parameterize `get_default_warrior()` with an id and name, exactly like
  `get_default_scout()` already is; `warrior_001` keeps its `WARRIOR_ID`
  constant and the name "Warrior".
- The three additional warriors get generated ids from `_new_instance_id()`
  and cosmetic names "Warrior 2".."Warrior 4". No collision rules are
  needed — generated ids cannot collide with the recruitment templates or
  with each other, which is the point of constraint 6.
- All four start at level 1 with class baseline stats and default gear, as
  free roster members (not recruits).

### Starting recruitment offers — 3 warriors + 1 scout

`reset()` currently seeds only `RECRUITMENT_CANDIDATE_TEMPLATES[0]`
(`warrior_002`). Seed **all four** templates instead — the pool already
matches the decided composition (3 warriors, 1 scout, each at the existing
10-gold price), and `RECRUITMENT_OFFER_CAP` is already 4. Their identity
model changes at the same time:

- A spawned offer is a fresh record with a generated `id` plus a
  `template_id` field when it claims a fixed-pool template (overflow offers
  carry none). A candidate's identity is no longer the template's identity.
  Its display name comes from the same per-class cosmetic counter — not
  from the template's `name` field — so seeded offers cannot collide with
  the seeded roster's names.
- Template claiming moves from id-collision inference to the explicit field:
  a template is claimed iff any roster adventurer or live offer carries its
  `template_id`. `_spawn_next_recruitment_offer()` uses that check instead
  of `_is_recruitment_id_taken(template.id)`, and mints overflow offers with
  generated ids directly (delete the `%s_%03d` scan loop).
- `purchase_recruit()` / `purchase_recruit_for_party()` keep their
  signatures — purchasing is still by candidate id; ids are opaque. Drop
  their `_has_adventurer(candidate_id)` collision guards (a generated
  candidate id can never collide with a roster id), and delete
  `_is_recruitment_id_taken()` entirely along with the scan loop in the
  debug-only `recruit_adventurer()` (that path mints a generated id and a
  cosmetic name too).
- Vacancy-timed refill behavior is otherwise unchanged: purchases start
  their clocks, and refills spawn the next offer when a slot is free.

### Save compatibility (identity part)

`CampaignSnapshot` keeps every id verbatim. One addition to the nested
per-adventurer normalization pass this step introduces (step 2 extends it,
step 3 completes it): a record without a `template_id` field infers it when
the record's id matches a `RECRUITMENT_CANDIDATE_TEMPLATES` id (legacy
purchased recruits like `warrior_002`); otherwise the field stays absent.
This preserves refill behavior exactly for old saves — claimed templates
stay claimed.

### Item instance identity

Item instances already store their own `"id"` plus a `base_item_id`
back-reference; only the minting changes:

- The `_new_blacksmith_item_instance_id()` sequential scan is replaced by
  `_new_instance_id()` (sharpening-completion path).
- `materialize_banked_item_instance(base_item_id, instance_id)` becomes
  `materialize_banked_item_instance(base_item_id) -> String`: it mints the
  instance id itself and returns it ("" on rejection) instead of taking a
  caller-supplied id. Its only callers today are tests
  (`test_game_session.gd`, `test_runic_workshop.gd`,
  `test_scout_class_and_permissions.gd`), so the signature change is cheap;
  update those call sites to capture the returned id.
- Equipment references (`equipment.weapon` / `equipment.armor`) already hold
  instance-or-catalog ids resolved through `get_item_definition()` — no
  change.

### Party caps — explicit, enforced, displayed

- **Size.** `get_max_party_size()` (Guild Hall level 1 → 4, level 2 → 5) is
  already enforced by `assign_adventurer_to_party()` and friends. Keep it
  and lock the level 1 → 2 unlock with a regression test.
- **Count.** Today this is hardcoded: `create_party()` rejects once any
  party exists, and `scripts/ui/parties.gd` disables Create while the list
  is non-empty. Make the cap explicit: `get_max_party_count() -> int`
  (returns 1), checked by `create_party()` and derived from by the UI
  (`rows.size() >= get_max_party_count()`). Do **not** add Guild Hall
  level 3 or second-party creation here (deferred, see above).
- **Indicator.** Add a caps label to the Parties screen
  (`scripts/ui/parties.gd`), sourced from the two getters — e.g.
  "Party size: 4 · Parties: 1/1". New translation keys per the README
  localization process; update `tests/unit/test_localization.gd`.

### Record the decision in the gap analysis

Edit `docs/gap-analysis.md` → "Current implementation notes that constrain
the roadmap": replace the first bullet's closing sentence (*"Treat the
difference as an explicit product decision before changing onboarding or
balance."*) with:

> **Decided (2026-08-13):** start with a roster of 4 warriors plus 4
> recruitable units (3 warriors, 1 scout); maximum party size 4 and maximum
> party count 1, both enforced and displayed. The Guild Hall level 2
> party-size unlock (4 → 5) is shipped; the level 3 party-count unlock
> (1 → 2) is deferred to roadmap part 4 (§2.1) with multi-party play.

## Setup

```bash
git checkout main && git pull
git checkout -b onboarding-decision
make check   # green baseline
```

## TDD task list (red → green, in this order)

Write each failing test first, run it to confirm the failure, then
implement. Finish each task group with `make check`.

1. **Instance-id helper** (`tests/unit/test_game_session.gd`):
   `_new_instance_id()` returns non-empty ids that stay unique across a large
   draw batch and never equal a recruitment template id; the entropy is
   pinnable for deterministic tests.
2. **Starting roster** (`tests/unit/test_game_session.gd`): after `reset()`,
   the roster is four level-1 warriors — `warrior_001` plus three generated
   ids — with class baseline stats.
3. **Recruitment identity and starting offers**
   (`tests/unit/test_game_session.gd` and `tests/unit/test_recruitment.gd`):
   after `reset()`, `recruitment_candidates` holds four offers (3 warriors,
   1 scout), each with a generated id and its `template_id`; a claimed
   template never spawns again (refill skips it); overflow offers mint with
   generated ids; `purchase_recruit()` works by candidate id with the
   collision guards gone. `test_recruitment.gd` currently pins the old
   one-offer start and hardcodes `"warrior_002"` — rework those expectations
   to discover candidates by lookup, keep the refill/clock tests.
4. **Save normalization** (`tests/unit/test_campaign_snapshot.gd`): a legacy
   adventurer whose id matches a template id loads with `template_id`
   inferred; a legacy id that matches nothing loads without the field; a
   current-format round-trip preserves generated ids and `template_id`
   exactly.
5. **Item instances** (`tests/unit/test_game_session.gd`,
   `test_runic_workshop.gd`, `test_scout_class_and_permissions.gd`):
   sharpening completion mints a generated instance id;
   `materialize_banked_item_instance(base_item_id)` returns the minted id,
   rejects when the bank is empty, and callers (the three test files) use
   the returned id.
6. **Party-count cap** (`tests/unit/test_game_session.gd`):
   `get_max_party_count()` returns 1; `create_party()` succeeds once and
   fails at the cap via the getter. Replace the current "second create
   fails" coverage so it exercises the explicit cap.
7. **Party-size cap regression** (`tests/unit/test_game_session.gd`):
   assignment is rejected at `get_max_party_size()`, and upgrading the Guild
   Hall level 1 → 2 raises the cap from 4 to 5.
8. **Parties screen** (`tests/unit/test_parties.gd`): the caps label shows
   the size cap and the party count ("1/1"); the Create button's disabled
   state follows `get_max_party_count()`.
9. **Other start-state tests.** Update every remaining test pinned to the
   old opening. Known: `test_campaign_guide.gd` and
   `test_first_campaign_ui_flow.gd` (roster/recruitment assumptions — verify
   the guide sequence still fires unchanged), `test_unit_details.gd` (uses
   `recruit_adventurer()` id-collision assumptions around warrior_002).
   Audit — do not assume this list is complete.
10. **Translations:** new Parties-screen caps keys; update
    `tests/unit/test_localization.gd`.
11. **Gap analysis note** (docs-only task above) and the index status row
    for this step.

## Verification

```bash
make check
```

Expected: full suite green (`make check` is `make test` — GUT, headless;
output ends with `All tests passed!`). Sim/scenario balance outputs are
**not** expected to change — they build units from `battle_state_factory`,
not from the campaign roster, and this step touches no combat path. Capture
them anyway as the pre-big-party evidence for the future encounter
re-tuning pass (index, Out of scope):

```bash
make scenario SCENARIO=scenarios/battle/baseline-party-viability.json SEED=20260810 ITERATIONS=20
```

## Manual verification (user sign-off)

Confirm the new opening reads as decided (ids are hidden throughout — the
player only ever sees display names):

1. `make play` → New Campaign → Starting Settlement → Encampment.
2. Units screen: roster of four Warriors (screenshot).
3. Recruitment screen: four offers — 3 warriors and 1 scout (screenshot).
4. Parties screen: the caps indicator shows the size cap (4) and parties
   1/1; create the first party; Create is then unavailable while the party
   exists (screenshot).
5. Party Details: assign all four warriors; a fifth assignment is rejected.
6. Follow the campaign guide: deploy, take one route step — the guide still
   advances (form party → deploy → …) and the opening stays legible as
   "create your party from the starting roster, then grow through
   recruitment".
7. Optional: buy one recruit (10 gold) — the vacancy clock and the next
   offer behave exactly as before; in the save file the recruit's id is a
   generated string, not `warrior_%03d`:
   ```bash
   SAVE="$(find ~/.local/share/godot -name campaign-save.json | head -1)"
   grep -o '"id":[^,]*' "$SAVE" | head -12
   ```

## Commit and merge

```bash
git add -A && git status   # confirm only intended paths are staged
git commit -m "feat: implement onboarding decision — generated ids, starting roster, offers, party caps"
# after user sign-off:
git checkout main && git merge onboarding-decision && git branch -d onboarding-decision
```

## Milestone (concretely verifiable)

- `docs/gap-analysis.md` on `main` states the decision (grep for
  "**Decided**").
- `grep -rn "_is_recruitment_id_taken" scripts/ tests/` returns **nothing**;
  the only sequential `%03d` id minting left in `game_session.gd` is the
  encounter-instance path (deferred — index, Out of scope).
- A new campaign starts with four warriors, four recruitment offers
  (generated ids + `template_id`), and enforced+displayed party caps
  (party size 4, party count 1); second-party creation is unavailable.
- `make check` green.
- Signed-off screenshots: Units, Recruitment, and Parties screens.
