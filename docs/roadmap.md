# Fantasy Tactics Roadmap

## Purpose and priority rule

This roadmap orders the work needed to realise the full experience described
in [`docs/designs/`](designs/). It is deliberately **campaign-first**: the
Borderlands campaign must be a complete, repeatable, enjoyable game before
the project takes on its broader strategic and endgame systems.

Items marked **decision gate** require written approval of their unresolved
rules before implementation planning begins. A later milestone must not pull
work forward merely because its prerequisite data or UI already exists.

## Current foundation

The game already has an authored twelve-objective campaign spine, tactical
combat foundations (movement, AP, facing, flanking, opportunity attacks,
missile targeting, fog of war, and enemy-turn playback), Warrior/Scout/Cleric
recruitment foundations, equipment/stores/workshops, persistence, and an
audio manager with music, SFX, and settings.

The current art and audio assets are functional placeholders: a small CC0
sprite set is rendered through `SpriteCatalog`, and the WAV tracks are
synthesised tones. They make the game playable, but are not the durable
presentation promised by the campaign design.

## Priority 1 — Release-quality Borderlands campaign baseline

**Objective:** a new player can complete the full 60–90 minute campaign,
recover from setbacks, save/resume, and understand every essential result
without developer tooling.

### Deliverables

- Audit the fresh-game route through party formation, deployment, twelve
  authored objectives, final victory, and clearly labelled post-victory free
  play.
- Verify the defeat, unit-loss, retreat, pending-reward, Encampment-return,
  and economy-floor contracts as one campaign loop rather than as isolated
  systems.
- Make the Journal/current objective/next unlock/final-victory condition
  visible and durable throughout the loop.
- Establish campaign pacing and difficulty baselines from full deterministic
  campaign simulations, then validate the same route manually with normal
  player inputs.
- Apply the D9 presentation/accessibility contract to every campaign-critical
  outcome: readable text or glyph support alongside colour and sound.

### Exit criteria

- A fresh save reaches final victory and optional free play with no debug
  route or direct state setup.
- Campaign simulation covers documented seeds plus a recorded sweep, with
  approved success/failure bands rather than a single lucky run.
- Save/load is tested at strategic, battle-entry, reward, defeat, and
  post-victory boundaries.
- A manual `make play` pass records the complete player route and all
  recovery paths.

### Dependencies and gates

- Preserve `GameSession` as durable-state/rules owner, `GameManager` as
  navigation owner, and UI scenes as presentation/intent owners.
- Do not migrate authored encounter ownership to `ContentCatalog` yet: the
  current design records no concrete blocked content feature.

## Priority 2 — Complete the campaign tactical roster and encounter roles

**Objective:** make the campaign's party composition and enemy counterplay
match the class, combat, and monster designs instead of relying on a Warrior
foundation with partial supporting systems.

### Ordered slices

1. **Scout to Ranger:** complete ranged pressure, scouting value, and its
   first two class perks; add protected ranged enemies and encounters where
   positioning—not raw stats—is the answer.
2. **Cleric to Healer:** complete MP-backed targeted healing, Bless/protection,
   duration feedback, and attrition encounters. Healing must improve recovery
   without making the party unkillable.
3. **Mage to Spellcaster:** add resource-limited offensive and control magic,
   resistance/counterplay, and swarm/control encounters that prove its role.
4. **Encounter and monster parity:** add only the documented monsters and
   variants whose required combat primitive has shipped; every addition needs
   art, localisation, loot, AI, automated scenario coverage, and balance
   comparison.
5. **Root specializations:** Knight, Archer, Battle Mage, and Paladin only
   after their prerequisite classes, Temple rules, and combat primitives are
   verified.

### Exit criteria

- Each root class has a distinct campaign decision role, two data-backed
  perks, a supported UI/readout, persistence coverage, and at least one
  encounter that rewards its role.
- Every new monster and ability has exact rules, counterplay, focused tests,
  deterministic battle/campaign evidence, and a manual battle check.
- Balance evidence records both the intended party and an adverse matchup;
  passing baseline tests alone does not constitute balance approval.

### Decision gates

- Cleric recruitment/Temple effects and upgrade rules.
- Scout intelligence values and the first Ranger information payoff.
- Exact Mage spell list, control durations, resistance interaction, and
  monster immunities.
- Any perk that needs unshipped mechanics such as dodge, parry, penetration,
  cooldowns, marks, or multi-target effects.

## Priority 3 — Durable playable graphics, sound, and battle feedback

**Objective:** replace functional placeholder presentation with a coherent,
readable, accessible game presentation before treating the campaign as ready
for players.

### Art and animation

- Set an approved visual direction, target resolution, palette, animation
  budget, asset licence/provenance rules, and import pipeline before buying,
  commissioning, or generating final assets.
- Replace placeholder battlefield/world-map unit and terrain sprites with
  readable class, monster, encounter, settlement, loot, and building art.
- Add only clarity-serving animation: movement, attack wind-up/impact,
  projectile travel, spell effects, damage/heal/guard/critical feedback,
  death, selection, and objective completion.
- Make battle information legible at a glance: health/AP/MP, facing,
  targetability, fog/stale information, range, status effects, rewards, and
  retreat consequences. Follow the container-driven UI rules rather than
  embedding layout calculations in gameplay controllers.

### Sound and music

- Replace synthesised placeholder tracks and effects with licensed/owned,
  loop-safe music and readable SFX while retaining the existing stable
  `AudioManager` IDs and volume/mute settings contract.
- Cover the required state transitions: Encampment, World Map, ordinary
  battle, boss battle, victory, defeat, and the distinct action results for
  hit, miss, critical, guard, heal, spell, death, retreat, UI activation,
  building upgrade, gold banking, and level-up.
- Mix and test crossfades, simultaneous SFX, mute/slider persistence, and
  repeated scene transitions. Sound supplements visible feedback; it is never
  the sole signal of a gameplay-critical result.

### Exit criteria

- A player can identify each unit class, monster role, terrain state, and
  combat result at normal play scale without consulting debug labels.
- A manual playthrough confirms every listed music transition and SFX event
  is audible, non-disruptive, and respects settings.
- Screenshot/video evidence covers Encampment, World Map, ordinary battle,
  boss battle, victory, defeat, and accessibility-critical states.
- Automated tests protect asset lookup fallbacks, audio IDs, settings
  persistence, and the presentation state machine; manual review judges
  readability and feel.

### Decision gates

- Art direction and source strategy (commissioned, internally created,
  licensed packs, or a documented hybrid).
- Final palette/contrast and animation scope after testing with the complete
  tactical roster—not before its information needs are known.

## Priority 4 — Campaign content, progression, and economy depth

**Objective:** deepen the finished campaign without destabilising its proven
core loop.

### Deliverables

- Add the selected authored encounters and their complete narrative/reward
  presentation. If a specific new authored node is approved, first execute
  the bounded catalog-owned-authored-encounters migration as its own plan.
- Finish normal equipment progression, then add Alchemy and Runic Workshop
  layers only when potion action costs, conditions, cleansing, trigger
  timing, and AI treatment are supported.
- Expand building cards, crafting, stores, and trade feedback around visible
  costs, unlocks, and campaign-relevant choices.
- Tune objective rewards, loot, recruitment, healing, and income using
  campaign-level evidence; preserve the no-soft-lock recovery economy.

### Exit criteria

- Every campaign upgrade or item has a readable purpose, a working UI path,
  correct save behaviour, and an encounter or strategic decision that makes
  it relevant.
- Runes/status items ship only with generic status infrastructure, stack and
  immunity rules, visual/audio feedback, AI treatment, and focused tests.
- The final campaign has documented pacing, economy, and replayability
  evidence from simulation and manual play.

### Decision gates

- A concrete new authored-content feature before the catalog migration.
- Potion AP costs, status-effect rules, rune sockets/displacement, and
  scrapping/material economy.

## Priority 5 — Full-experience strategic expansion

**Objective:** extend the completed campaign into the broader strategy game
without making the first campaign dependent on expansion work.

### Ordered slices

1. **Intelligence:** encounter discovery, scouting tiers, Watchtowers, and
   Guild Hall quests after approving their cadence, escalation, and rewards.
2. **Multiple parties:** independent party positions, destinations, routing,
   selection, battle locks, and coordination UI; all mutations must remain
   party-scoped rather than rely on `selected_party_id` helpers.
3. **Dungeon exploration:** party formation movement, encounter triggers,
   tactical handoff, and return/recovery loops.
4. **Advanced combat:** conditions, wounds, dodge/parry, penetration,
   reactions, cooldowns, marks, multi-target effects, advanced perks, and
   corresponding monster roles.
5. **Post-victory expansion:** repeatable encounters, deeper town/trade
   systems, specialisation breadth, and any later campaign content.

### Exit criteria

- Each expansion is independently playable, persisted, and regression-tested
  without weakening the completed single-campaign route.
- Multi-party work proves displayed-party correctness under concurrent routes,
  battles, recalls, and UI detail views.
- Intelligence and dungeon systems have measurable discovery/pacing evidence,
  not only design prose.

## Delivery rules for every milestone

- Convert the next approved roadmap item into a dated folderized plan under
  `docs/plans/`, with an `index.md`, self-contained serial steps, explicit
  dependencies, red/green tests, manual verification, independent review,
  and user signoff before merge.
- Use `GameConfig` for balance values; keep `GameSession`/`GameManager`/UI
  ownership boundaries intact.
- Run focused GUT tests, `make check`, headless editor parsing, and
  `git diff --check`; use campaign simulation sweeps when mechanics or
  balance change.
- Keep customer/demo data out of Git. Do not push or open a pull request
  unless explicitly requested.

## Roadmap completion

The design is fully implemented only when Priorities 1–4 are complete and
Priority 5's systems either ship with their approved contracts or remain
explicitly deferred by a revised, user-approved design. No document label or
passing unit suite alone is proof: completion requires source evidence,
automated verification, manual playable checks, and the approved graphics and
sound presentation.
