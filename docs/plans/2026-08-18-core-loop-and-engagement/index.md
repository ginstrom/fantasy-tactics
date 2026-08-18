# Core Loop Completion and Engagement — Implementation Plan

**Date:** 2026-08-18
**Status:** proposed
**Implements:** [`docs/core-loop-and-engagement-roadmap.md`](../../core-loop-and-engagement-roadmap.md) & [`docs/designs/campaign-loop.md`](../../designs/campaign-loop.md)

---

## Executive Summary

This plan executes the complete implementation of the **Core Loop Completion and Engagement Roadmap**. The objective is to deliver a compact, completable 60–90 minute Borderlands campaign consisting of twelve required authored battles across three tiers, a pre-boss sequence, and a final boss. The campaign features meaningful Encampment progression, high-stakes unit permadeath and tactical retreat, an anti-soft-lock economy floor, the three-root class triad (Warrior, Scout, Cleric), deterministic headless campaign verification, and an iterative placeholder-asset presentation pass.

---

## Roadmap Alignment & Sequencing

Per [`docs/core-loop-and-engagement-roadmap.md`](../../core-loop-and-engagement-roadmap.md)'s **Sequencing Rule**, all mechanical progression, economy safety floors, permadeath/recovery loops, class features, and authored encounters are built and deterministically verified before broad graphics or audio production passes begin.

The plan is decomposed into eight self-contained, sequentially executable steps:

| # | Step Document | Summary | Branch | Depends on |
|---|---|---|---|---|
| 1 | [01-campaign-state-and-onboarding.md](01-campaign-state-and-onboarding.md) | Single-party scope, durable campaign progression state, objective graph, save snapshot versioning, and streamlined onboarding flow | `feat/campaign-state-and-onboarding` | Baseline `main` |
| 2 | [02-permadeath-retreat-and-economy-floor.md](02-permadeath-retreat-and-economy-floor.md) | Unit permadeath cleanup & item transfer, tactical retreat action & distance penalties, party wipe handling, and passive economy floor | `feat/permadeath-retreat-and-economy` | Step 1 merged |
| 3 | [03-encampment-buildings-and-tier-model.md](03-encampment-buildings-and-tier-model.md) | Guild Hall deployment (3→4→5), roster/offer caps (10/4, 15/8, 20/10), Cleric-recruiting Temple, and Shop tier passive income | `feat/encampment-building-tiers` | Step 2 merged |
| 4 | [04-cleric-class-and-scout-reconnaissance.md](04-cleric-class-and-scout-reconnaissance.md) | Cleric with 3 MP, Heal and Bless, proximity-based Scout reconnaissance, and automatic stat growth | `feat/cleric-and-scout-recon` | Step 3 merged |
| 5 | [05-authored-encounters-and-final-boss.md](05-authored-encounters-and-final-boss.md) | 12-battle authored ladder (Tiers 1–3, Pre-Boss, Ogre boss), dynamic threat stars, victory screen, and post-game free play | `feat/authored-encounter-ladder` | Step 4 merged |
| 6 | [06-campaign-simulation-and-balance-harness.md](06-campaign-simulation-and-balance-harness.md) | Headless campaign-level simulation harness, gold velocity & level curve analysis, and zero-gold wipe rebuilding verification | `feat/campaign-simulation-harness` | Step 5 merged |
| 7 | [07-visual-perspective-and-tactical-polish.md](07-visual-perspective-and-tactical-polish.md) | Standardized 3/4 top-down perspective, floating combat text (hits/crits/misses/damage/heals), wound indicators, and visual overlays | `feat/visual-perspective-and-polish` | Step 6 merged |
| 8 | [08-audio-system-and-soundscape.md](08-audio-system-and-soundscape.md) | Audio manager with Master/Music/SFX buses, tactical combat SFX, environmental ambience & music states, and 100% visual mute parity | `feat/audio-system-and-soundscape` | Step 7 merged |

---

## Architectural Grounding & Core Invariants

1. **Autoload Separation of Concerns ([`docs/dev/code-map.md`](../../dev/code-map.md)):**
   - `GameConfig` (`scripts/autoload/game_config.gd`): Read-only, typed configuration parsed once from `config/game_config.json`. Mirrors built-in `DEFAULTS` locked by unit tests.
   - `GameManager` (`scripts/autoload/game_manager.gd`): UI navigation and scene transition routing. Never stores durable game state.
   - `GameSession` (`scripts/autoload/game_session.gd`): Sole owner of durable game state, rules, parties, rosters, buildings, and progression. Never references the scene tree.

2. **Durable State & Save Migration (`scripts/save/campaign_snapshot.gd`):**
   - All campaign milestone progression, objective tracking, completed nodes, and free-play flags are managed through `CampaignSnapshot`.
   - Snapshot serialization is versioned, deep-copy safe, and validated before mutation. Legacy save imports normalize safely without partially assigning state.

3. **Permadeath & Item Preservation Invariant:**
   - Units reaching 0 HP are permanently deleted at battle resolution.
   - Equipped and carried items/gear instances are atomically transferred to the pending party loot pool, returning to the Encampment bank upon successful retreat or victory.
   - Slain unit IDs are purged from `adventurers`, `party.member_ids`, and item ownership lists.

4. **Deterministic Simulation & Testability:**
   - All random rolls (loot, compositions, combat RNG, retreat outcomes, level-up stats) use injectable Callables seeded from PRNG instances. Authored battle coverage is expressed through `ScenarioContract` and hydrated by `BattleStateFactory` with a per-iteration seed.
   - Scene-free and headless simulation tools guarantee reproducibility without dependency on the graphical SceneTree.

5. **Localization & UI Invariants:**
   - Every user-facing string is localized through `tr()` using keys in `translations/en.tres` and validated by `tests/unit/test_localization.gd`.
   - All interactive controls respect container mouse filtering and standard navigation layouts.

6. **Resolved feature decisions:**
   - An encounter always displays only its location until the deployed party contains a Scout within three World Map squares (Manhattan distance). At that distance, show its tier and exact enemy count/type; reveal neither rewards nor enemy placement.
   - A Cleric begins every battle with 3 MP. Heal costs 1 MP and heals one living allied unit for an injectable 2–8 HP roll. Bless costs 1 MP and gives one living allied unit +10 percentage points to final hit chance and +10% final damage for that battle. MP does not refresh during battle. Temple blessings are out of scope; the Temple unlocks Cleric recruitment only.
   - The final boss is an Ogre with no bespoke mechanics. Its tuned baseline is approximately the combat power of four level-1 Warriors. Victory shows the campaign summary once; after acknowledgement, repeatable free-play vacancies may spawn without reopening objectives.
   - The presentation pass retains the existing logical square grids and input geometry. Placeholder assets must read as a 3/4 top-down view; owner screenshot review is the acceptance gate. No custom final art or audio production is in scope.

---

## Shared Definition of Done for Every Step

- **TDD:** Red-to-green workflow with comprehensive failing unit tests written and verified before implementation.
- **Automated Verification:** focused tests, `make check`, `git diff --check`, and an editor scan pass. Treat the suite's known orphan warnings according to `docs/dev/testing.md`; do not require a zero-warning count that the baseline does not satisfy.
- **Deterministic Parity:** Scenario runs and snapshots maintain byte-identical reproducible records.
- **Manual Verification:** Human sign-off via `make play` following the exact steps in the step document.
- **Branch Hygiene:** Explicit staged file lists (`git add <file1> <file2>`), no `git add -A`, clean merge to `main`, and deletion of the feature branch.
