# Step 3: Encampment Building Progression and Tier Model

**Date:** 2026-08-18
**Status:** proposed
**Branch:** `feat/encampment-building-tiers`
**Part of:** [`docs/plans/2026-08-18-core-loop-and-engagement/index.md`](index.md)

---

## Summary

Implement the structured Encampment building upgrade model across the core hubs (Guild Hall, Temple, Shop & Stores, and Workshops). Expand Guild Hall to support tier-based deployment scaling (3 → 4 → 5 deployable party slots), roster/offer caps (10/4, 15/8, 20/10), and FIFO candidate replacement on pool overflow. Add the **Temple** building hub for Cleric recruitment only. Integrate Shop progression (supplying 2/5/10 gold/turn and unlocking tier 3 healing potions for 20 gold). Surface clear upgrade requirements and unlocks in the Encampment UI.

---

## Technical Design

### 1. Guild Hall Progression & Roster Scaling (`scripts/autoload/game_session.gd`)
- Put Guild Hall and Shop caps, costs, and income in `config/game_config.json`, mirrored by `GameConfig.DEFAULTS`; `GameSession` remains the rules owner.
- `guild_hall_level`: integer `1 <= level <= 3`.
- **Deployment Capacity (`get_max_party_size()`):**
  - Level 1: 3 deployable slots.
  - Level 2: 4 deployable slots.
  - Level 3: 5 deployable slots.
- **Roster & Offer Caps (`get_roster_cap()`, `get_recruitment_offer_cap()`):**
  - Level 1: max 10 roster members, max 4 recruitment candidate offers.
  - Level 2: max 15 roster members, max 8 recruitment candidate offers.
  - Level 3: max 20 roster members, max 10 recruitment candidate offers.
- **Recruitment Offer Overflow Policy:**
  - When `_refill_recruitment_vacancy()` adds a new candidate while `recruitment_candidates.size() >= get_recruitment_offer_cap()`, remove the oldest candidate offer (FIFO queue) to make room for the new candidate.

### 2. Temple Building Hub (`scripts/autoload/game_session.gd`, `scenes/ui/temple.tscn`, `scripts/ui/temple.gd`)
- Add `temple_level: int = 0` (0 = unbuilt, 1 = consecrated, 2 = sanctified) to `GameSession` and `CampaignSnapshot`.
- **Temple Capabilities:**
  - Level 1 (Build Cost: 100 gold, stored in configuration and calibrated by the campaign harness): unlocks Cleric recruitment candidate generation.
  - Blessings, Temple level 2, and their state fields are explicitly out of scope for this plan.
- Create `scenes/ui/temple.tscn` with `CampNav` and Cleric recruitment preview; it must not create an Encampment blessing UI.

### 3. Shop & Stores Progression (`scripts/autoload/game_session.gd` & `scripts/ui/stores.gd`)
- `shop_level`: integer `1 <= level <= 3`.
- **Shop Tiers & Inventory:**
  - Tier 1 (Cost: 0, default): 2 gold/turn passive income, basic Iron weapons and Leather armors.
  - Tier 2 (Upgrade Cost: 150 gold): 5 gold/turn passive income, Steel weapons and Mail armors.
  - Tier 3 (Upgrade Cost: 300 gold): 10 gold/turn passive income, Enhanced gear, and purchasable **Minor Healing Potions** (restores 2–8 HP, costs 20 gold).

### 4. Encampment UI Card Integration (`scenes/ui/encampment.tscn`, `scripts/ui/encampment.gd`, `scenes/ui/buildings.tscn`)
- Present each building hub as a clear strategic card with:
  - Current level & tier status.
  - Upgrade cost and prerequisite requirements.
  - Unlocked benefits and next-tier unlocks.
- Wire `CampNav` to include the **Temple** route.

---

## Setup

```bash
git checkout main && git pull
git checkout -b feat/encampment-building-tiers
make check   # confirm clean baseline before changes
```

---

## TDD Task List (Red → Green)

Write failing unit tests first, verify failure, implement changes, and confirm `make check` passes.

1. **Guild Hall Tier Scaling & Capacity ([`tests/unit/test_guild_hall.gd`](../../../tests/unit/test_guild_hall.gd) & [`tests/unit/test_game_session.gd`](../../../tests/unit/test_game_session.gd)):**
   - Test deployment party size: 3 at Level 1, 4 at Level 2, 5 at Level 3.
   - Test roster/offer caps: 10/4 at Level 1, 15/8 at Level 2, and 20/10 at Level 3.
   - Test candidate overflow removes oldest offer when new offer arrives.

2. **Temple Hub and Cleric Recruitment ([`tests/unit/test_temple.gd`](../../../tests/unit/test_temple.gd) & [`tests/unit/test_game_session.gd`](../../../tests/unit/test_game_session.gd)):**
   - Test building Temple unlocks Cleric recruitment.
   - Test the Temple has no blessing action or persisted blessing state in this slice.

3. **Shop Tier Upgrades & Healing Potion Stock ([`tests/unit/test_stores.gd`](../../../tests/unit/test_stores.gd) & [`tests/unit/test_game_session.gd`](../../../tests/unit/test_game_session.gd)):**
   - Test upgrading Shop to Level 2 and Level 3 checks prerequisite gold and updates shop level.
   - Test Shop Level 3 enables purchasing healing potions (20 gold each).
   - Test passive gold generation scales to 2, 5, 10 gold per turn respectively.

4. **Snapshot Serialization & Migration ([`tests/unit/test_campaign_snapshot.gd`](../../../tests/unit/test_campaign_snapshot.gd)):**
   - Test `temple_level` serializes and deserializes properly in `CampaignSnapshot`; assert that no blessing state is introduced.

5. **Encampment & Buildings UI ([`tests/unit/test_buildings.gd`](../../../tests/unit/test_buildings.gd) & [`tests/unit/test_camp_nav.gd`](../../../tests/unit/test_camp_nav.gd)):**
   - Test Buildings screen displays all hubs (Guild Hall, Temple, Blacksmith, Workshops, Shop).
   - Test CampNav contains Temple navigation button.

---

## Verification

```bash
make check
```

Expected output: All unit tests pass with zero errors, zero orphans, and zero warnings.

---

## Manual Verification (User Sign-off)

1. Launch `make play`.
2. In the **Encampment**, click **Buildings**.
3. Inspect the building hub cards:
   - Verify Guild Hall shows current capacity (3 party slots, 10 roster) and upgrade cost to Tier 2.
   - Verify Temple card is present with option to construct.
   - Verify Shop shows current passive income rate (+2 gold/turn).
4. Construct the **Temple**:
   - Verify Temple opens from CampNav.
   - Confirm the Temple previews Cleric recruitment and contains no blessing purchase action.
5. Upgrade the **Guild Hall** to Tier 2:
   - Navigate to **Parties** / **Add Member**.
   - Verify a 4th adventurer can now be assigned to `party_001`.
6. Upgrade the **Shop** to Tier 3:
   - Navigate to **Stores**.
   - Verify Healing Potions are available for purchase at 20 gold each.
   - Pass a turn and verify gold increases by +10.

---

## Commit and Merge

```bash
git status --short
git add config/game_config.json scripts/autoload/game_config.gd scripts/autoload/game_session.gd scripts/save/campaign_snapshot.gd scripts/ui/guild_hall.gd scripts/ui/stores.gd scripts/ui/buildings.gd scripts/ui/camp_nav.gd scripts/ui/temple.gd scenes/ui/temple.tscn scenes/ui/buildings.tscn scenes/ui/camp_nav.tscn translations/en.tres tests/unit/test_game_config.gd tests/unit/test_game_session.gd tests/unit/test_guild_hall.gd tests/unit/test_stores.gd tests/unit/test_temple.gd tests/unit/test_buildings.gd tests/unit/test_campaign_snapshot.gd tests/unit/test_camp_nav.gd
git diff --cached --check
git commit -m "feat(encampment): implement building progression, guild hall party scaling, temple hub, and shop tiers"

# After user sign-off:
git checkout main
git merge feat/encampment-building-tiers
git branch -d feat/encampment-building-tiers
```

---

## Milestone (Concretely Verifiable)

- Guild Hall upgrades scale party deployment capacity from 3 to 4 to 5.
- Temple hub is built and functional with Cleric recruitment; Encampment blessings remain deferred.
- Shop tiers generate 2/5/10 gold/turn and offer Tier 3 healing potions.
- `make check` passes 100% green.
