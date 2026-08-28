# Running the Game

How to launch the game, jump straight to a specific scene or state for
manual testing, and capture a screenshot of every known scene/UI state.

## Prerequisites

- Everything in [README.md § Repository-wide prerequisites](README.md#repository-wide-prerequisites).
- For the screenshot tour only: a real or virtual display (it cannot run
  under `--headless`). On a display-less box, run it under `xvfb-run`.

## Launch the game

### Steps

1. From the repository root, run:
   ```
   make play
   ```
   This runs `godot --path .` — a debug build (`OS.is_debug_build()` is
   `true`), which matters for the debug menu below.

### Verification

- A window titled "Fantasy Tactics" opens at 1280×720 showing the Start
  Menu.

### Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `make: godot: Command not found` | `godot` isn't on `PATH` | Install Godot 4.7.1 and confirm with `godot --version` |
| Window opens then immediately closes | A script failed to compile | Run `make editor` instead and check the Output/Debugger panel for the error |
| Music, SFX, or Master volume/mute controls have no audible or logged effect | `project.godot`'s `[audio]` section (`buses/default_bus_layout="res://default_bus_layout.tres"`) is missing or wrong, so `AudioServer` never registers the Music/SFX buses `AudioManager` expects | Confirm the `[audio]` section in `project.godot` points at `res://default_bus_layout.tres`, then run `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_project_audio_contract.gd -gexit` — it reads `project.godot` and the layout resource directly and fails if either is wrong. Also check the Output panel at startup for `AudioManager: required audio bus '...' is missing from AudioServer` (emitted by `AudioManager.validate_buses()` in `_ready()`) naming the specific missing bus |

## Jump to a specific scene or state (debug menu)

The debug menu is a development-only overlay; it does not exist in a
non-debug export build. It renders its scenario buttons from a JSON
manifest, `config/debug_scenarios.json` — see
[Author a new debug scenario](#author-a-new-debug-scenario) below for that
file's schema and how to add to it.

### Steps

1. Launch the game with `make play` (see above).
2. From any campaign screen, press **FN + F9** to toggle the debug menu overlay.
3. Click one of the scenario buttons, grouped under a category header in the
   manifest's own order. Each one imports that scenario's complete
   `campaign_snapshot` fixture — the same all-or-nothing seam
   `GameSession.import_campaign_snapshot()` uses for loading a save — and
   then changes directly to its declared screen, closing the overlay on
   success:

   | Button | Category | Resulting screen | Session state |
   |---|---|---|---|
   | New Campaign | Campaign | Starting Settlement | Fresh session, no party |
   | Encampment | Campaign | Encampment | Fresh session, no party |
   | Party Manager | Campaign | Party Manager | Fresh session, no party |
   | Party Ready to Depart | Campaign | Encampment | One party, staffed with the default Warrior, not yet deployed — Deploy Party is enabled |
   | Party Awaiting a Member | Campaign | Encampment | One party created with no members |
   | Party on World Map | World | World Map | Staffed party deployed at a fixed World Map tile, away from the encounter sites |
   | Goblin Camp Battle | Battle | Battlefield | Staffed party deployed onto the Goblin Camp encounter, fielding its fixture's 1 Goblin |
   | Orc Outpost Battle | Battle | Battlefield | Staffed party (4 Warriors) deployed onto the Orc Outpost encounter, fielding its fixture's 2 Orcs |
   | Ruined Fortress Battle | Battle | Battlefield | Staffed party (3 Warriors) deployed onto the Ruined Fortress encounter, fielding its fixture's maximum 8 Kobolds |
   | Jump to Pre-Boss Encounter | Battle | World Map | Party standing on Pre-Boss Vanguard encounter tile; Tier 3 complete and all remaining battles (Pre-Boss encounters and Ogre Boss) pre-unlocked |
   | Stocked Shop + Stores | Shop | Stores | Staffed encamped party; Shop available; Stores pre-stocked with 2 tier-1 mana crystals and a banked Iron Shortsword; 500 gold — for exercising the Trade loop (Stores/Shop/Assign Equipment) without playing through a battle first |

   A battlefield launch never rerolls its enemy composition — the fixture's
   own `active_encounters` entry is exactly what gets fielded, every time
   (see [Author a new debug scenario](#author-a-new-debug-scenario) for why).

4. Two more buttons, in their own section below the scenario list, act on
   the *current* state rather than importing a fixture:
   - **Super Power** — maxes out the player unit's move range, attack
     damage, and hit chance. Only has an effect while a Battlefield is on
     screen; a no-op otherwise.
   - **Recruit Adventurer** — mints and adds a debug adventurer to the
     roster immediately, bypassing the gold cost and recruitment-offer flow.

5. **Reload** re-reads `config/debug_scenarios.json` from disk without
   restarting the game — see the next section for what happens on success
   and on failure.

### Verification

- After clicking a scenario button, the debug menu overlay closes and the
  screen listed in the table above is showing.

### Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| F9 does nothing | Running a non-debug/exported build | Use `make play` or `make editor`, not an exported binary |
| A scenario button does nothing and the menu stays open | The launch failed validation (unknown id, an unrecognized `launch.scene`, a battlefield fixture with no `selected_encounter`) or the embedded `campaign_snapshot` failed import | Press **Reload** to see the loader's diagnostics in the status line above the scenario list; check the Output panel for anything `import_campaign_snapshot` rejected |
| Reload shows an error and the menu looks unchanged | The edited manifest is invalid — see the failure rule below | Fix the reported error in `config/debug_scenarios.json` and press Reload again |

## Author a new debug scenario

`config/debug_scenarios.json` is a debug-only **manifest** — versioned
independently (`manifest_version`) from each entry's embedded
`campaign_snapshot`, which is a complete, JSON-safe dump of `GameSession`'s
own durable state (the same shape a real save file uses). Debug scenarios
are never a second, ad-hoc session-state format: applying one delegates
entirely to `GameSession.import_campaign_snapshot()`, so an invalid fixture
is rejected the same way a corrupt save would be.

### Manifest schema

```json
{
  "manifest_version": 1,
  "scenarios": [
    {
      "id": "party_ready",
      "name_key": "debug.party_ready",
      "category": "Campaign",
      "description": "One staffed party at the Encampment.",
      "launch": { "scene": "encampment" },
      "campaign_snapshot": { "version": 1, "...": "..." }
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `manifest_version` | Must equal `DebugScenarios.SUPPORTED_MANIFEST_VERSION` (currently `1`). |
| `scenarios[].id` | Stable, unique, non-empty. Referenced by `run_debug_scenario(id)` and this file's button-press tests. |
| `scenarios[].name_key` | A `translations/en.tres` key, shown as the button's label. Add the key there too — see `test_every_shipped_scenario_name_key_resolves_to_translated_text` in `tests/unit/test_debug_scenarios.gd`. |
| `scenarios[].category` | Plain display string (not a translation key). Scenarios sharing a category are grouped under one header, in the category's first-seen order. |
| `scenarios[].launch.scene` | One of `settlement`, `encampment`, `party_manager`, `parties`, `world_map`, `battlefield`, `stores` (`DebugScenarios.ALLOWED_LAUNCH_SCENES`). A `battlefield` launch additionally requires the fixture's own `selected_encounter` to be non-empty — the dispatcher never calls `GameSession.enter_encounter()` itself. |
| `scenarios[].campaign_snapshot` | A complete `CampaignSnapshot` document — see below for how to produce one. |

### Generate a fixture

1. Get the game into the exact state you want the scenario to reproduce
   (via normal play, or an existing debug scenario plus a few manual steps).
2. From the Godot editor's Remote/Debugger console, or a throwaway script,
   call `GameSession.export_campaign_snapshot()` and dump the result as
   JSON (`JSON.stringify(GameSession.export_campaign_snapshot(), "  ")`).
3. Paste that JSON as the new entry's `campaign_snapshot`, and fill in its
   `id`/`name_key`/`category`/`description`/`launch.scene`.

A battlefield fixture's enemy composition is whatever its
`active_encounters[].enemy` field says at the moment you captured it —
entering the battle never rerolls it (unlike normal gameplay's
`GameSession.enter_encounter()`), so a scenario meant to reliably field a
specific fight (e.g. Ruined Fortress's maximum eight Kobolds) needs its
snapshot captured at exactly that composition, not left to chance.

### The last-known-good failure rule

`DebugScenarios.load_scenarios()` parses and fully validates a manifest into
scratch values *before* replacing the active cache. A manifest that fails to
parse, fails `manifest_version`/schema validation, or contains even one
invalid scenario entry never touches the cache at all — the previously
loaded scenarios (and their buttons) remain exactly as they were, and the
loader's error list is all you see change (in the debug menu's status line,
or in `load_scenarios()`'s returned `{ "ok": false, "errors": [...] }`).
Deploying a bad edit can never silently blank the menu or corrupt an
in-progress debug session.

### Boundaries

- **Debug scenario fixtures are not save files.** Real campaign saves are
  written by `SaveRepository` (`scripts/save/save_repository.gd`), which
  owns its own atomic write and versioned-load contract; a debug manifest
  never performs disk I/O beyond reading itself.
- **Locations and encounter templates are authored game content**
  (`GameSession.EXPEDITIONS`), separate from this debug tooling. A live
  encounter *instance* referencing one of those templates is durable session
  state, which is exactly what a `campaign_snapshot`'s `active_encounters`
  field captures.
- **Custom enemy squads or hand-placed board positions are out of scope for
  this manifest.** A battlefield launch always uses the fixture's selected
  encounter through the game's standard battle construction
  (`BattleStateFactory`); a dedicated adapter built on `ScenarioContract` is
  the deferred path for fully custom battle setups, not a new field here.

## Battle controls

Once a battle is on screen (via normal play, or the debug menu's "Goblin
Camp Battle" / "Orc Outpost Battle" / "Ruined Fortress Battle" scenarios
above), the following controls drive combat. The layout is Baldur's Gate
1/2 inspired: a top title/round header, a left party-portrait column, the
tactical grid in the center, a right-hand dual unit-inspection panel, and a
full-width combat log above the bottom action bar. See
[code-map.md § The battle scene](code-map.md#the-battle-scene-two-grid-objects-not-one)
for the underlying `BattleController` logic.

| Control | Effect |
|---|---|
| `1`–`5` | Select the party member in that portrait slot. |
| Click a highlighted tile | Move the selected unit there. |
| Click a reachable enemy | Auto move-and-attack: if the enemy isn't already in weapon range, the unit first pathfinds to the nearest tile with range and line-of-sight, then attacks — deducting move AP and then attack AP in one action. |
| `W` / `A` / `S` / `D` | Direct-step the selected unit up/left/down/right by one tile. `A` always moves left; it is never a mode shortcut. |
| **Move** button | Switches to Move mode: clicking a highlighted tile moves the unit; clicking an enemy only inspects it (no attack). |
| **Attack** button | Switches to Attack mode: clicking an enemy attacks (with auto move-and-attack); clicking an empty tile does nothing. |
| `Esc` | Open the game menu. |

- The Move and Attack buttons have **no keyboard shortcuts** — only clicking
  them changes mode. Selecting a unit, ending a turn, or completing a
  move/attack resets the mode to Contextual, which is the original
  click behavior: an empty highlighted tile moves, an enemy attacks, and a
  friendly unit selects.
- **Green** range tiles are move-and-attack range — the unit can move there
  and still afford a basic attack. **Yellow** tiles are dash-only range —
  movement is affordable but no AP would remain to attack. **Red**
  highlights mark enemies attackable immediately; **orange** marks enemies
  only reachable via move-and-attack.
- The left portrait panel lists each party member with current HP overlaid
  on the portrait; clicking a portrait selects that unit.
- The right panel shows two sections at once: the hovered unit (name, wound
  status) on top, and the selected unit (name, class, level, HP, AP,
  equipped weapon) pinned below it, so both stay visible while you aim an
  attack.

## Capture a screenshot of every known scene/state

### Steps

1. From the repository root, run:
   ```
   make screenshots
   ```
   This runs `scripts/tools/screenshot_tour_main.gd` with a real (not
   headless) renderer, positioning the window off-screen at `(-3000, -3000)`
   so it doesn't steal focus.
2. On a machine with no display attached, prefix the command instead:
   ```
   xvfb-run make screenshots
   ```

### Verification

- `./screenshots/` contains one numbered PNG per step defined in
  `scripts/tools/screenshot_tour.gd` (e.g. `01_start_menu.png`,
  `02_starting_settlement.png`, ...).
- The terminal prints `[screenshot_tour] done: N screenshots in <dir>`.

### Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Godot exits immediately with a display/rendering error | No display available | Run under `xvfb-run` |
| A new scene/UI state you added isn't captured | `screenshot_tour.gd`'s step list wasn't updated | Add a `{"name": ..., "action": ...}` entry to `_build_steps()` in `scripts/tools/screenshot_tour.gd` — see that file's own header comment for the convention |

## Run the headless battle simulator

Plays N full battles with no human input — `BattleBot` controls the
player side, the game's existing enemy AI controls the enemy side — and
logs one JSON line per battle outcome. Useful for balance/AI-tuning data
(damage dealt, kills, gold earned, win rate per encounter), not for
correctness testing (see [testing.md](testing.md) for that).

### Steps

1. From the repository root, run:
   ```
   make simulate
   ```
   This plays 20 battles by default (10 Goblin Camp, 10 Orc Outpost,
   alternating) and appends results to `user://battle_sim.jsonl`.
2. Override the run count with `RUNS=N make simulate`.

### Verification

- The terminal prints one `[battle_sim] i/N <encounter_id> -> <outcome>`
  line per battle, ending with `[battle_sim] done: N battles logged to
  user://battle_sim.jsonl`.
- `user://` resolves to Godot's per-project user data directory — on
  Linux, `find ~/.local/share/godot -name battle_sim.jsonl`. Each line
  parses as JSON with keys `encounter_id`, `outcome` (`"victory"` /
  `"defeat"` / `"stalemate"`), `cleared`, `rounds`, `damage_dealt`,
  `kills`, `gold_earned`.

### Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `A line's outcome is "stalemate"` | The bot couldn't reach or defeat every enemy within the round cap | Rare for the shipped encounters under normal balance values; if it happens consistently after a balance change (`config/game_config.json`), the change likely made a fight unwinnable by the greedy bot policy — not necessarily a bug, but worth a second look |

## Run full headless campaigns

Plays entire campaigns start-to-Final-Boss with no human input --
`CampaignSim` drives recruitment, upgrades, gear, travel, and combat through
the same public `GameSession`/`BattleController`/`BattleBot` APIs the
headless battle simulator uses, one full campaign per seed. Useful for
campaign-level balance telemetry (gold velocity, level curve, upgrade
pacing) and for guarding the game's core completability. There are two
modes, and their evidence is intentionally labelled differently -- see
Verification below.

### Steps

- **Representative mode** (the default -- what `make campaign-sim` runs
  with no arguments): runs exactly the explicit, named seed list
  `CampaignSim.REPRESENTATIVE_VICTORY_SEEDS` (`4, 9, 10, 12, 14`), a
  small, hand-verified set every one of which is confirmed to reach
  Final Boss victory under the current bot/gear/upgrade policy.
  ```
  make campaign-sim
  ```
- **Sweep mode**: runs an arbitrary contiguous numeric sample of
  `CAMPAIGN_RUNS` seeds starting at `CAMPAIGN_SEED`, useful for probing
  a wider range but never a claim that the campaign is completable on
  every seed.
  ```
  CAMPAIGN_SEED=1 CAMPAIGN_RUNS=10 make campaign-sim-sweep
  ```
- Either mode also accepts `--report=` (via the underlying `godot -s`
  invocation) to change the JSON report's output path; representative mode
  additionally accepts an explicit `--seeds=4,9,10,12,14`-style list in
  place of the default. `--seeds=` cannot be combined with
  `CAMPAIGN_SEED`/`CAMPAIGN_RUNS` (sweep mode) -- the CLI rejects mixing
  the two rather than silently picking one.

### Verification

- The terminal prints one `[campaign_sim] i/N seed=<seed> -> <reason>
  (world_turns=..., battles=.../... won, wipes=...)` line per run, then a
  summary. **No unqualified "Victories: N (X%)" claim is ever printed** --
  the summary always names which mode produced the number:
  - Representative mode prints the exact seed list and
    `Representative seeds: 5/5 victories` -- a completability guarantee for
    that specific, named set, not a percentage extrapolated from an
    arbitrary sample.
  - Sweep mode prints its contiguous seed range (e.g. `Sweep seeds:
    1-10 (10 runs)`) and calls its percentage `Sample victory rate` --
    a labelled sample, never evidence that the campaign is completable on
    every seed.
  - Both modes list `Failed seeds` when any run didn't reach victory, now
    with each failure's own reason and headline stats (`seed=<n>
    reason=<...> (world_turns=..., battles=.../... won, wipes=...)`) --
    not just the bare seed number.
  - A `Per-objective world-turn span (min/mean/max), attempts, victories`
    block follows, one line per authored objective id actually attempted
    across the aggregated runs -- how much a single node's pacing varies
    run to run, not a single hidden-variance average.
- The terminal ends with `[campaign_sim] done: N campaigns logged, report
  written to <path>` (default `user://campaign_sim_report.json`, i.e.
  `find ~/.local/share/godot -name campaign_sim_report.json` on Linux). The
  JSON report includes `mode`, `seeds`, `failed_seeds` (now seed/reason/
  stats detail objects), and `per_objective_summary` alongside the existing
  aggregate telemetry (`victory_rate`, `mean_world_turns`, `gold`,
  `mean_party_level_curve`, `mean_upgrade_progression_turns`, ...).
  It also carries a `run_records` array (deliberately not named `runs` --
  `runs` is already the integer run *count* field above): every seed's own
  raw telemetry, each with an ordered `objective_records` list (one entry
  per objective actually fought -- `objective_id`, `outcome`,
  `world_turn_start`/`world_turn_end`, `party_losses`, `hp_recovered`/
  `mp_recovered` (rest recovered between objectives -- a member recruited
  mid-cycle never counts toward this; see `CampaignSim._vitals_recovered()`),
  `gold_before`/`gold_after`, `upgrades_purchased`, `party_composition`,
  `level_summary`). This is what makes one saved report self-sufficient for
  manual review: a reviewer can read a single seed's `objective_records` top
  to bottom and see exactly where a setback happened (`party_losses`
  non-empty), how much the party recovered before the next objective
  (`hp_recovered`/`mp_recovered` and the
  `world_turn_start`/`world_turn_end` gap), when an upgrade landed
  (`upgrades_purchased`), and the run's final outcome (`victory`/`reason`
  at that run's own top level) -- without reading any simulator source.
  Generated reports are local evidence and must not be committed.

### Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `[campaign_sim] --seeds= cannot be combined with --seed=/--runs=` (or the CLI errors on an unrecognized argument) | Mixing representative-mode's `--seeds=` with sweep-mode's `--seed=`/`--runs=`, or a typoed flag | Use `make campaign-sim` (optionally with `--seeds=`) for representative mode, or `make campaign-sim-sweep` (`CAMPAIGN_SEED=`/`CAMPAIGN_RUNS=`) for sweep mode -- not both at once |
| A representative-mode run reports fewer than 5/5 victories | A change to bot policy, recruitment, upgrades, or the underlying game balance broke a previously-guaranteed seed | Treat as a regression, not noise -- `test_campaign_sim.gd`'s `test_run_campaign_reaches_victory_on_the_representative_seed_set()` should already be failing in `make check`; bisect the change rather than re-running |

## Run reproducible battle scenarios

`make simulate` remains the scene-driven smoke client. For repeatable, scene-free policy experiments, run a declared scenario instead:

```
make scenario SCENARIO=scenarios/battle/baseline-party-viability.json SEED=20260810 ITERATIONS=20
```

The command writes a fresh directory under `user://battle-scenarios/` (or the exact `OUTPUT_DIR` supplied) with `records.jsonl` and `report.json`. Records are deterministic for a fixed scenario, seed, iteration count, and game configuration; generated results are local evidence and must not be committed.

## Run a Stage 4 play session

Records one complete fresh manual campaign against the protocol in
[campaign-loop.md § Stage 4 evidence and presentation contract](../designs/campaign-loop.md#stage-4-evidence-and-presentation-contract),
for comparison with a fixed `make campaign-sim` run.

### Steps

1. Copy [`stage-4-play-session-template.md`](stage-4-play-session-template.md)
   to a new file *outside this repository* (this repo has no gitignored
   scratch directory for session records), named with an anonymous session
   label, e.g. `stage-4-session-S1.md`.
2. Run `make play` and start a fresh campaign from the Start Menu — New
   Game only. Do not open the debug menu (`F9`) or use Super Power/Recruit
   Adventurer during the session; doing so invalidates the session as a
   fresh-campaign record (see the protocol's "Dev tools permitted" row).
3. Fill in the session header and one checkpoint row per required
   checkpoint as it happens, recording the player's stated expectation
   *before* being told the outcome.
4. Log any finding in the session's Findings table as it's noticed, using
   the field list in the template.
5. Keep the completed session file, and any screenshots it references,
   local — do not commit them.

### Verification

- The session file has a filled session header, a checkpoint row for every
  required checkpoint that occurred, and every finding numbered against the
  template's field list.

## Review a local campaign report

Compares a manual session against the fixed deterministic evidence.

### Steps

1. Run `make campaign-sim` (representative mode; no arguments) to produce
   `user://campaign_sim_report.json` — see
   [Run full headless campaigns](#run-full-headless-campaigns) above.
2. Open the report and the session file side by side. For each objective
   the manual session reached, compare its checkpoint row against that
   objective's entry in the report's `run_records[].objective_records`
   (`world_turn_start`/`world_turn_end`, `party_losses`, `hp_recovered`/
   `mp_recovered`, `gold_before`/`gold_after`, `upgrades_purchased`).
3. Note any manual-session finding that the deterministic report also
   shows (e.g. a pacing gap visible in `world_turn_start`/`world_turn_end`)
   as sim-corroborated in the session's Findings table — this counts toward
   "repeated" without needing a second manual session.
4. Keep the JSON report local — do not commit it.

### Verification

- Every objective checkpoint in the session file has been checked against
  the matching `objective_records` entry, and any corroborated finding is
  marked as such in the session file.

## Open the project in the editor

### Steps

```
make editor
```
Runs `godot --editor project.godot`.

### Verification

- The Godot editor opens with this project loaded.
