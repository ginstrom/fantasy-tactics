# Step 3: Party Creation and Direct-to-Party Recruitment

> **Branch:** `feat/party-creation-and-direct-recruitment` (off updated local `main`)

## Setup

```bash
git checkout main && git pull
git checkout -b feat/party-creation-and-direct-recruitment
```

## Goal

Make first-party creation continuous, and make Party Details → Recruit purchase
and assign a recruit to that exact eligible party in one atomic operation.

## Files

- Modify: `scripts/ui/encampment.gd`, `scenes/ui/encampment.tscn`, `scripts/ui/parties.gd`
- Modify: `scripts/autoload/game_session.gd`, `scripts/autoload/game_manager.gd`, `scripts/ui/party_details.gd`, `scenes/ui/party_details.tscn`
- Test: `tests/unit/test_encampment.gd`, `tests/unit/test_parties.gd`, `tests/unit/test_party_details.gd`, `tests/unit/test_game_session.gd`, `tests/unit/test_game_manager.gd`

## Contract and TDD

1. Add a first-party dialog with exact design text. Its dismissed state is
   controller-local: Dismiss suppresses it for the current Encampment scene
   visit; returning with no party presents it again. Test Create, Dismiss,
   refresh-after-dismiss, and return-after-dismiss.
2. Test party-name confirmation routes only after `GameManager.create_party()`
   returns `OK`, using the created party's id; failed creation leaves the form
   intact and does not route.
3. Replace Add Member with `Add from Roster` and `Recruit`. Use existing
   `GameSession.get_available_adventurers()` and
   `GameSession.get_recruitment_candidates()`; both disable at party cap and
   hide for a deployed party.
4. Add `GameSession.purchase_recruit_for_party(candidate_id, party_id)` (or an
   equivalently named single operation). Validate offer, funds, id collision,
   encamped target, and capacity before changing anything. On success deduct
   once, remove offer, seed/add adventurer, assign it, and start vacancy.
   Test every failed guard leaves gold, candidates, roster, membership, and
   vacancy state unchanged.
5. Add GameManager transient recruitment target context and a targeted
   recruitment route. Validate it before route and purchase; an invalid/stale
   context becomes a normal non-targeted Recruitment route instead of silently
   assigning elsewhere.
6. Run focused red/green GUT tests, editor refresh, `make check`, and
   `git diff --check`; manually verify the full Create → Party Details →
   Recruit → selected party flow, obtain signoff, locally merge, delete branch.
