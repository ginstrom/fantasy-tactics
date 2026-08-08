# Step 7: Sync the design doc and dev docs

**Depends on:** Steps 1-6 merged (this step documents the shipped
behavior, so the behavior must exist first).

**Produces:** `docs/plans/first-playable-campaign/game-design.md` and
`docs/dev/running-the-game.md` updated to describe the rebalanced stats,
the Kobold/Hobgoblin monsters, the Ruined Fortress site, power-weighted
tier selection, and the new debug scenario — closing out Milestone 3's
"catalogue breadth" gap and unblocking Milestone 5.

This step has no automated tests (it's prose), so its "red/green" is
"the old text is still there" -> "the new text replaces it, and every
number in it matches the shipped constants."

## Setup

```bash
git checkout main && git pull
git checkout -b docs-sync-monster-tiers
```

## Steps

- [ ] **Step 1: Confirm the current doc text (RED, in the sense that these exact strings are what we're about to remove)**

  ```bash
  grep -n "3 base health\|has 3 health\|has 5\nhealth\|neither currently\nappears\|still just the Goblin Camp\|still waits on the catalogue gap\|Broaden the encounter catalogue" docs/plans/first-playable-campaign/game-design.md
  ```
  Expected: matches at the line numbers referenced below (line numbers may
  have drifted slightly if `docs/plans/first-playable-campaign/game-design.md`
  changed since this plan was written — search for the surrounding prose
  quoted in each edit below if so).

- [ ] **Step 2: Update the Vacancy-timed encounter section**

  In `docs/plans/first-playable-campaign/game-design.md`, replace (around
  line 109-118):

  ```markdown
  The map and the recruitment offer list no longer show every possible site or
  candidate at once. A campaign starts with two active encounters, the
  one-star Goblin Camp (difficulty 1) and the two-star Orc Outpost (difficulty
  2), and one active recruitment offer (a Warrior); each category still holds
  at most two active encounters or four active offers at a time. Clearing a
  site or hiring a recruit opens a vacancy; that vacancy's own 15 +/- 5 (encounter)
  or 30 +/- 5 (recruitment) World Map turn clock refills it with a new instance only
  if its category is still under its cap when the clock completes. A cleared
  site never reopens — a later spawn is a distinct new instance, though it may
  reuse a previously seen encounter template at a different map tile.
  ```

  with:

  ```markdown
  The map and the recruitment offer list no longer show every possible site or
  candidate at once. A campaign starts with two active encounters, the
  one-star Goblin Camp (difficulty 1) and the two-star Orc Outpost (difficulty
  2), and one active recruitment offer (a Warrior); each category still holds
  at most two active encounters or four active offers at a time. Clearing a
  site or hiring a recruit opens a vacancy; that vacancy's own 15 +/- 5 (encounter)
  or 30 +/- 5 (recruitment) World Map turn clock refills it with a new instance only
  if its category is still under its cap when the clock completes. A cleared
  site never reopens — a later spawn is a distinct new instance, though it may
  reuse a previously seen encounter template at a different map tile.

  A three-star Ruined Fortress template now exists alongside the Goblin Camp
  and Orc Outpost, but it is never one of the campaign's two starting sites.
  Which template an encounter vacancy's refill produces is chosen at random,
  weighted toward higher star tiers as the player's power (adventurer count
  plus Guild Hall level) grows, rather than deterministically cycling through
  every known template. At a fresh campaign's starting power, a refill is
  roughly 44% one-star, 44% two-star, and 11% three-star; by the time a
  player has recruited several adventurers and maxed the Guild Hall, those
  odds shift toward roughly 8% / 62% / 31%. No tier's odds ever reach zero.
  ```

  Replace (around line 122-125):

  ```markdown
  The World Map marks each active encounter with a difficulty-only star badge
  (one star for Goblin Camp, two for Orc Outpost) rather than a numeric label,
  so the player can compare expedition risk at a glance before committing a
  route.
  ```

  with:

  ```markdown
  The World Map marks each active encounter with a difficulty-only star badge
  (one star for Goblin Camp, two for Orc Outpost, three for the Ruined
  Fortress) rather than a numeric label, so the player can compare expedition
  risk at a glance before committing a route.
  ```

- [ ] **Step 3: Update the Full-party battles stat block**

  Replace (around line 143-152):

  ```markdown
  Each site's star rating drives a randomly resolved enemy composition: 
  the one-star Goblin Camp always fields one Goblin; the two-star Orc Outpost fields 
  two Goblins or one Orc, chosen at random each time the site is entered. 

  A Warrior has 3 base health and Attack 60 (a 60% base hit chance before armor); 
  its damage and defensive stats come from its equipped gear — see Trade,
  equipment, and loot below for how weapon and armor choice change a Warrior's
  damage range, effective hit chance, and damage taken. A Goblin has 3 health,
  a 30% hit chance, and deals 1-6 damage with its Short Sword; an Orc has 5
  health, a 50% hit chance, and deals 1-8 damage with its longsword. 
  Enemies take a visible, deterministic AI decision sequence after the 
  player ends the round.
  ```

  with:

  ```markdown
  Each site's star rating drives a randomly resolved enemy composition: the
  one-star Goblin Camp always fields one Goblin; the two-star Orc Outpost
  fields two Goblins or one Orc; the three-star Ruined Fortress fields 4-8
  Kobolds, 3-6 Goblins, 2-4 Orcs, or 1-3 Hobgoblins. Both which option and,
  for the Ruined Fortress, the exact count within its range are chosen at
  random each time the site is entered. The battlefield can field up to 8
  enemies at once (up from 3), so the Ruined Fortress's Kobold swarm is the
  first fight to use the board's full width.

  A Warrior has 10 base health and Attack 60 (a 60% base hit chance before
  armor); its damage and defensive stats come from its equipped gear — see
  Trade, equipment, and loot below for how weapon and armor choice change a
  Warrior's damage range, effective hit chance, and damage taken. Monster HP
  and damage are tuned around that 10 HP baseline so a level-1 Warrior is in
  a roughly even solo fight against a single Orc (see
  [docs/plans/2026-08-08-monster-tiers-and-weighted-encounters/index.md](../../2026-08-08-monster-tiers-and-weighted-encounters/index.md)
  for the expected-rounds-to-kill math this was tuned against):

  | Monster | Health | Hit chance | Damage | Weapon |
  |---|---|---|---|---|
  | Kobold | 6 | 25% | 1 | Rusty Dagger |
  | Goblin | 13 | 30% | 2 | Short Sword |
  | Orc | 22 | 50% | 3 | War Axe |
  | Hobgoblin | 30 | 60% | 4 | Two-Handed Sword |

  Enemies take a visible, deterministic AI decision sequence after the
  player ends the round.
  ```

- [ ] **Step 4: Update the loot table paragraph**

  Replace (around line 198-203):

  ```markdown
  A Goblin kill queues 1-6 gold, a tier-1 mana crystal, and a chance at an Iron Shortsword; 
  an Orc kill queues double gold (1-5, x2) and a tier-2 crystal and a chance at an Iron Longsword.

  Loot tables also exist for Kobolds and Hobgoblins, whose gear and crystal
  tiers are documented for a future content pass, but neither currently
  appears in any active encounter. All of it queues on victory and only banks
  ```

  with:

  ```markdown
  A Goblin kill queues 1-6 gold, a tier-1 mana crystal, and a chance at an Iron Shortsword; 
  an Orc kill queues double gold (1-5, x2) and a tier-2 crystal and a chance at an Iron Longsword.

  A Kobold kill (fought at the Ruined Fortress) queues 0-5 gold and a tier-1
  mana crystal, plus a chance at an Iron Dagger; a Hobgoblin kill there
  queues triple gold (1-4, x3) and a tier-2 crystal, plus a chance at an Iron
  Two-Handed Sword — the catalogue's top loot tier, matching its status as
  the toughest monster in the game. All of it queues on victory and only banks
  ```

- [ ] **Step 5: Update the "Next work" section**

  Replace (around line 249-267):

  ```markdown
  ## Next work

  The prototype now fields a full party against a full, star-tier-randomized
  enemy composition; the Guild Hall and the Trading Post give players their
  first two gold-funded tactical decisions (a larger party, and better gear);
  and loot (gold, mana crystals, gear) joins XP as expedition rewards. The next
  implementation work should focus on these unfinished outcomes, in order:

  1. Broaden the encounter catalogue beyond the Goblin Camp and Orc Outpost
     templates so expedition choice differs by more than star rating alone —
     Milestone 3's remaining gap. This is also what Milestone 5's "several
     expeditions" slice is still waiting on, now that a second building has
     landed.
  2. Add save/load now that the expedition, reward, and upgrade loop is
     repeatable; then enable the existing Continue and Load UI.
  3. Assemble Milestone 5's first campaign slice — onboarding and pacing —
     once the encounter catalogue has broadened.
  4. Add durable presentation assets only when their associated gameplay choices
     have been playtested, following the asset policy below.
  ```

  with:

  ```markdown
  ## Next work

  The prototype now fields a full party against a full, star-tier-randomized
  enemy composition, up to 8 enemies strong; the Guild Hall and the Trading
  Post give players their first two gold-funded tactical decisions (a larger
  party, and better gear); loot (gold, mana crystals, gear) joins XP as
  expedition rewards; and the encounter catalogue now spans three star tiers
  and four monster types (Goblin, Orc, Kobold, Hobgoblin), with a refill's
  tier chosen at random, weighted by the player's growing power. The next
  implementation work should focus on these unfinished outcomes, in order:

  1. Add save/load now that the expedition, reward, and upgrade loop is
     repeatable; then enable the existing Continue and Load UI.
  2. Assemble Milestone 5's first campaign slice — onboarding and pacing —
     now that both the encounter catalogue and the upgrade path have several
     options each.
  3. Add durable presentation assets only when their associated gameplay choices
     have been playtested, following the asset policy below.
  ```

- [ ] **Step 6: Update Milestone 3's status**

  Replace (around line 375-390):

  ```markdown
  ## Milestone 3: Expedition and reward loop

  **Status: reward, replacement, and full-party tactical loops shipped;
  catalogue breadth is incomplete.** Every expedition now pays out three
  reward types: gold and mana crystals (banked on return to Encampment),
  individual adventurer XP (awarded immediately per kill and per clear; see
  Adventurer progression above), and a chance of the killed enemy's own
  weapon as gear (see Trade, equipment, and loot above). Cleared sites are
  persistent but not permanent — each vacancy refills on its own 15-turn clock
  under a two-site cap, so the world map keeps changing within a campaign
  rather than only accumulating grey markers. Each site's star rating also now
  resolves to a randomized enemy composition (see Full-party battles and the
  Guild Hall above), so the two templates already produce more than one
  tactical setup. The encounter catalogue itself is still just the Goblin Camp
  and Orc Outpost templates; any travel-time or resource cost beyond World Map
  turns remains future work.
  ```

  with:

  ```markdown
  ## Milestone 3: Expedition and reward loop

  **Status: completed.** Every expedition now pays out three reward types:
  gold and mana crystals (banked on return to Encampment), individual
  adventurer XP (awarded immediately per kill and per clear; see Adventurer
  progression above), and a chance of the killed enemy's own weapon as gear
  (see Trade, equipment, and loot above). Cleared sites are persistent but
  not permanent — each vacancy refills on its own 15-turn clock under a
  two-site cap, so the world map keeps changing within a campaign rather
  than only accumulating grey markers. The encounter catalogue now spans
  three star tiers (Goblin Camp, Orc Outpost, Ruined Fortress) and four
  monster types, with both the enemy composition and, for the Ruined
  Fortress, the fielded count resolved at random each time a site is
  entered (see Full-party battles and the Guild Hall above); any
  travel-time or resource cost beyond World Map turns remains future work.
  ```

- [ ] **Step 7: Update Milestone 5's status**

  Replace (around line 534-541):

  ```markdown
  ## Milestone 5: First campaign slice

  **Status: not started.** The reward and upgrade loop now exists (gold, mana
  crystals, gear, XP, the Guild Hall, the Trading Post, and randomized site
  compositions), but this milestone still waits on the catalogue gap called
  out in Next work above — two encounter templates are not yet the "several
  expeditions" this milestone asks for, even though the "several upgrades"
  half is now satisfied by two buildings.
  ```

  with:

  ```markdown
  ## Milestone 5: First campaign slice

  **Status: not started, no longer blocked.** The reward and upgrade loop now
  exists (gold, mana crystals, gear, XP, the Guild Hall, the Trading Post,
  and randomized site compositions), and the encounter catalogue now spans
  three star tiers and four monster types — both halves of this milestone's
  "several expeditions, several upgrades" precondition (see Next work above)
  are satisfied. What remains is assembling and playtesting the slice itself.
  ```

- [ ] **Step 8: Update the dev docs' debug scenario table**

  In `docs/dev/running-the-game.md`, add a row to the scenario table (after
  the "Orc Outpost Battle" row, around line 63):

  ```markdown
  | Ruined Fortress Battle | Battlefield | Staffed party deployed directly onto, and battling, the Ruined Fortress encounter, forced to its maximum eight-Kobold composition |
  ```

- [ ] **Step 9: Verify the numbers in the doc match the shipped code**

  ```bash
  grep -n "max_health\|hit_chance\|attack_damage" scripts/autoload/game_session.gd
  ```
  Cross-check every number against the table written into Step 3 above (10
  Warrior HP is in `BASE_MAX_HEALTH`, not this file — check
  `config/game_config.json` for that one). Also run:
  ```bash
  make check
  ```
  Expected: PASS — this step touches no `.gd` files, so this just confirms
  the doc-only change didn't accidentally break anything (e.g. a stray
  edit outside the doc files).

- [ ] **Step 10: Commit**

  ```bash
  git add docs/plans/first-playable-campaign/game-design.md docs/dev/running-the-game.md
  git commit -m "docs: sync the design doc and dev docs with the monster tiers and weighted encounters plan"
  ```

## Merge back to main

Get the user's signoff that the doc reads accurately (a quick read-through,
no code to test), then:

```bash
git checkout main
git merge docs-sync-monster-tiers
git branch -d docs-sync-monster-tiers
```

This is the last step in the plan — once merged, delete this plan's
directory's relevance note is unnecessary (plans stay as historical
records; do not delete `docs/plans/2026-08-08-monster-tiers-and-weighted-encounters/`).
