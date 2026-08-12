# Step 1 — Record the initial-party / onboarding decision

**Branch:** `onboarding-decision`
**Status:** pending
**Implements:** gap analysis §4 step 1 ("Decide the initial party/onboarding
target") and its "Current implementation notes" bullet: *"Treat the
difference as an explicit product decision before changing onboarding or
balance."*

## Why this step exists

The shipped campaign opens with **one Warrior and no party**; the player
creates and staffs the first party, guided by `CAMPAIGN_GUIDE_SEQUENCE`
(form party → deploy → route → enter site → return & bank → first
improvement). `docs/designs/vision.md` instead says the player *"starts with
a single party of 4 members."* The gap analysis requires this difference to
be an **explicit product decision** before any onboarding or balance change.
Part 4 of the roadmap (§2.1) then implements whatever the decision implies
for party scale; this step only decides and records.

## The decision (ask the user — this is a product call)

**Option A — Keep the shipped onboarding (recommended).**
One Warrior, player forms the first party.

Rationale:

- The guided first-playable loop already works and is covered end-to-end by
  `tests/unit/test_first_campaign_ui_flow.gd` and the campaign guide.
- The recruitment economy (vacancy-timed offers, gold costs, Guild Hall
  party-size cap 4 → 5) is built around *earning* the remaining members;
  gifting three starters would invalidate the early recruitment loop and the
  10-gold recruit pricing.
- The vision's four-member party is reachable in-campaign (Guild Hall level 1
  cap is 4) — the difference is pacing, not capability.
- Multi-party scale-up is roadmap part 4 work anyway; changing onboarding now
  would be re-worked there.

**Option B — Start with a four-member party.**
Ship the vision's opening literally: seed three additional starting
adventurers (and optionally a pre-formed party) in `reset()`. This is real
implementation work — scope sketch only, to be expanded into a step-1b file
in this directory if chosen:

- Decide the starting roster composition and who pays (e.g. two Warriors +
  two Scouts seeded free; or one Warrior plus three free hires).
- `reset()`/`start_new_game()` seeding + `CampaignSnapshot` round-trip tests.
- Campaign-guide consequence: `form_party` step changes if the party
  pre-exists; `test_campaign_guide.gd` and `test_first_campaign_ui_flow.gd`
  updates.
- Rebalance: Goblin Camp/Orc Outpost vs. a four-member level-1 party via
  `make scenario` (existing fights may become trivial).
- Recruitment-offer interaction: a roster of four already fills the level-1
  Guild Hall cap; decide what early recruitment offers are for.

**Default if the user has no preference: Option A.**

## Setup

```bash
git checkout main && git pull
git checkout -b onboarding-decision
make check   # green baseline
```

## Tasks (Option A path)

This path is documentation + verification; there is no behavior change, so
there is no red/green cycle beyond proving the suite stays green. (If Option
B is chosen, stop here and write `01b-four-member-starting-party.md` with a
full TDD task list before implementing.)

1. **Record the decision in the gap analysis.** Edit
   `docs/gap-analysis.md` → "Current implementation notes that constrain the
   roadmap": replace the first bullet's closing sentence (*"Treat the
   difference as an explicit product decision before changing onboarding or
   balance."*) with the recorded decision, e.g.:

   > **Decided (2026-08-13):** keep the shipped onboarding — one starting
   > Warrior, player forms the first party. The vision's four-member starting
   > party remains the long-term target for party-scale work (roadmap part 4,
   > §2.1); early balance stays tuned around earning members through
   > recruitment.

2. **Mirror the decision in this plan's index** (the "Step 1" row status and
   a one-line Decisions note), so the plan directory alone tells the story.

3. **No code changes.** If any are proposed, they are out of scope for this
   step.

## Verification

```bash
make check
```

Expected: full suite passes unchanged (`make check` is `make test` — GUT,
headless; output ends with `All tests passed!`).

## Manual verification (user sign-off)

Confirm the shipped opening still reads as intended, since the decision
explicitly endorses it:

1. `make play`.
2. Start Menu → New Campaign → Starting Settlement → Encampment.
3. Follow the campaign guide: create the party (Party Manager), assign the
   Warrior, note the recruit offer on the Recruitment screen (the intended
   path to a second member), then return to the Encampment.
4. Capture or eyeball: Starting Settlement screen, Party Manager with the
   created party, Recruitment screen showing the first offer.
5. Sign-off criterion: the opening is legible as "you start with one
   Warrior and grow the party" — no confusion about the missing vision
   party of four.

## Commit and merge

```bash
git add docs/gap-analysis.md docs/plans/2026-08-13-foundations-and-recovery/
git commit -m "docs: record initial-party onboarding decision (keep shipped opening)"
# after user sign-off:
git checkout main && git merge onboarding-decision && git branch -d onboarding-decision
```

## Milestone (concretely verifiable)

- `docs/gap-analysis.md` on `main` states the decision explicitly (grep for
  "**Decided**").
- `make check` green with zero code changes in the diff
  (`git diff main~1 main --stat` shows only docs).
- User has signed off on the manual new-campaign walkthrough.
