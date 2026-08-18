# Step 5: Authored 12-Battle Encounter Ladder and Final Boss Victory

**Date:** 2026-08-18
**Status:** proposed
**Branch:** `feat/authored-encounter-ladder`
**Part of:** [`docs/plans/2026-08-18-core-loop-and-engagement/index.md`](index.md)

---

## Summary

Build the complete 12-battle authored campaign progression ladder: three Tier 1 encounters (Goblins/Kobolds), three Tier 2 encounters (Orcs/Brutes), three Tier 3 encounters (Hobgoblin Command/Mixed Forces), a two-battle Pre-Boss sequence, and the climactic Final Boss (**Ogre**). Define exact compositions, prerequisites, rewards, tactical counterplay, and dynamic 1–5 star threat scaling. Implement the dedicated **Campaign Victory Screen** and seamless transition to repeatable post-campaign **Free Play Mode**.

---

## Technical Design

### 1. Authored 12-Battle Encounter Ladder Catalog (`scripts/autoload/game_session.gd`)
Define the complete set of 12 authored campaign nodes in `GameSession.EXPEDITIONS` with strict linear/branching campaign progression:

1. **Tier 1 — Fundamentals & Formation:**
   - `node_t1_1_goblin_outpost`: 1 Goblin Skirmisher, 2 Kobold Swarmers. Teaches basic melee positioning and facing.
   - `node_t1_2_kobold_warren`: 4 Kobold Swarmers, 1 Kobold Slinger. Teaches swarm control and rear flanking.
   - `node_t1_3_goblin_camp`: 2 Goblin Skirmishers, 1 Goblin Archer. Teaches line-of-sight closing and ranged pressure.
2. **Tier 2 — Armored Brutes & Counterplay:**
   - `node_t2_1_orc_patrol`: 1 Orc Bruiser (heavy armor/guard), 1 Goblin Archer. Tests armor penetration/crits and ranged focus.
   - `node_t2_2_orc_vanguard`: 2 Orc Bruisers. Tests frontline durability, kiting, and Cleric healing sustain.
   - `node_t2_3_orc_stronghold`: 2 Orc Bruisers, 2 Goblin Archers. Tests terrain positioning and potion usage.
3. **Tier 3 — Mixed Command & Target Priority:**
   - `node_t3_1_hobgoblin_scout_party`: 1 Hobgoblin Elite, 2 Kobold Slingers. Tests high single-target burst management.
   - `node_t3_2_mixed_garrison`: 1 Hobgoblin Elite, 1 Orc Bruiser, 1 Goblin Shaman/Archer. Tests target prioritization (eliminating support first).
   - `node_t3_3_siege_encampment`: 2 Hobgoblin Elites, 2 Orc Bruisers. Tests formed party synergy (level ~5 party with upgraded gear).
4. **Pre-Boss Sequence:**
   - `node_pb_1_gatehouse`: 2 Hobgoblin Elites, 2 Goblin Archers, 1 Kobold Swarmer.
   - `node_pb_2_honor_guard`: 3 Hobgoblin Champions, 1 Orc Warlord.
5. **Final Boss Encounter:**
   - `node_final_boss_ogre`: one **Ogre**, a stronger standard monster with no bespoke action, cleave, or phase mechanics. Tune its ordinary HP, hit chance, damage, guard, and resistance against a deterministic benchmark of approximately four level-1 Warriors.
   - Extend the authored encounter schema and BattleController hydration to accept an ordered mixed-unit formation. Do not overload the current single `enemy` + `count` template record.

### 2. Dynamic Threat Scaling & World Turn Pacing (`scripts/autoload/game_session.gd`)
- Calculate threat level (1 to 5 stars) based on world turns elapsed and active encounter difficulty:
  - `threat_stars = clampi(base_difficulty + int(world_turn / THREAT_TURN_INTERVAL), 1, 5)`.
- Render dynamic 1–5 star icons on World Map encounter badges.

### 3. Campaign Victory & Free Play Transition (`scripts/autoload/game_manager.gd`, `scenes/ui/victory_screen.tscn`, `scripts/ui/victory_screen.gd`)
- Upon victory against `node_final_boss_ogre`:
  - Record `is_campaign_completed = true` and `is_free_play_active = true` in `GameSession`.
  - Navigate to dedicated `scenes/ui/victory_screen.tscn` displaying total turns, battles won, casualties, gold banked, and upgrades completed.
  - "Continue in Free Play" button transitions the player back to the Encampment.
- **Free Play Contract:**
  - Repeatable sandbox vacancies refill on the World Map.
  - Authored campaign objectives remain locked in completed state; victory screen does not trigger again.
  - Encampment and World Map headers display `[Free Play Mode]`.

---

## Setup

```bash
git checkout main && git pull
git checkout -b feat/authored-encounter-ladder
make check   # confirm clean baseline before changes
```

---

## TDD Task List (Red → Green)

Write failing unit tests first, verify failure, implement changes, and confirm `make check` passes.

1. **12 Authored Encounter Definitions ([`tests/unit/test_game_session.gd`](../../../tests/unit/test_game_session.gd)):**
   - Test all 12 authored encounter nodes exist in the Step-1 catalog with correct enemy compositions, positions, rewards, and prerequisites; test that only the currently unlocked authored node can spawn.
   - Test progression prerequisite chain from Tier 1-1 up to Final Boss.
   - Create `config/campaign_scenarios.json` with one `ScenarioContract` fixture per tier, both pre-boss nodes, and the Ogre. Hydrate each through `BattleStateFactory` and record its per-iteration seed.

2. **Final Boss Stats & Combat Behavior ([`tests/unit/test_battle_controller.gd`](../../../tests/unit/test_battle_controller.gd)):**
   - Test the Ogre uses only standard monster action resolution and its seeded benchmark falls within the agreed four-level-1-Warrior power band.
   - Test defeating the Ogre triggers `campaign_victory` once.

3. **Dynamic Threat Star Calculation ([`tests/unit/test_world_map.gd`](../../../tests/unit/test_world_map.gd) & [`tests/unit/test_game_session.gd`](../../../tests/unit/test_game_session.gd)):**
   - Test threat star rating scales from 1 to 5 based on difficulty and world turn progression.
   - Test World Map renders exact star count (★ to ★★★★★).

4. **Campaign Victory Screen & Free Play Mode ([`tests/unit/test_victory_screen.gd`](../../../tests/unit/test_victory_screen.gd) & [`tests/unit/test_game_manager.gd`](../../../tests/unit/test_game_manager.gd)):**
   - Test defeating final boss routes to `scenes/ui/victory_screen.tscn`.
   - Test victory screen displays campaign stats and provides Continue button.
   - Test clicking Continue activates Free Play mode without resetting completed objectives.

5. **Localization Strings ([`tests/unit/test_localization.gd`](../../../tests/unit/test_localization.gd)):**
   - Test encounter names, boss titles, and victory text keys resolve in `translations/en.tres`.

---

## Verification

```bash
make check
```

Expected output: All unit tests pass with zero errors, zero orphans, and zero warnings.

---

## Manual Verification (User Sign-off)

1. Launch `make play`.
2. Press **FN+F9** (Debug Menu) and select **Jump to Pre-Boss Encounter**.
3. Clear the pre-boss battles and advance to the **Ogre Final Boss**.
4. Engage the Ogre encounter:
   - Observe a stronger standard monster with no bespoke boss action.
   - Defeat the Ogre.
5. **Verify Victory Screen:**
   - Confirm the dedicated **Campaign Victory** screen appears with campaign summary stats (turns, gold earned, upgrades completed).
6. **Verify Free Play Mode:**
   - Click **Enter Free Play**.
   - Confirm the game returns to the Encampment with `[Free Play Mode]` indicator.
   - Travel to the World Map and confirm repeatable encounter vacancies populate for sandbox play.

---

## Commit and Merge

```bash
git status --short
git add config/campaign_scenarios.json scripts/autoload/game_session.gd scripts/autoload/game_manager.gd scripts/battle/battle_controller.gd scripts/ui/victory_screen.gd scenes/ui/victory_screen.tscn scripts/world/world_map.gd scripts/tools/battle_scenarios/scenario_contract.gd scripts/tools/battle_scenarios/battle_state_factory.gd translations/en.tres tests/unit/test_game_session.gd tests/unit/test_battle_controller.gd tests/unit/test_battle_state_factory.gd tests/unit/test_world_map.gd tests/unit/test_victory_screen.gd tests/unit/test_game_manager.gd tests/unit/test_localization.gd
git diff --cached --check
git commit -m "feat(campaign): implement 12-battle authored ladder, final boss, victory screen, and free play mode"

# After user sign-off:
git checkout main
git merge feat/authored-encounter-ladder
git branch -d feat/authored-encounter-ladder
```

---

## Milestone (Concretely Verifiable)

- 12 authored campaign encounters from Tier 1 through Final Boss are fully implemented and gated.
- Defeating the Final Boss triggers the victory screen and seamlessly transitions to Free Play.
- `make check` passes 100% green.
