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

Start with 4 warriors in the roster and 4 recruitable units -- 3 warriors and 1
scout. Maximum party size is 4, and maximum party count is 1. Player will
create and man a party before deploying.

## Setup

```bash
git checkout main && git pull
git checkout -b onboarding-decision
make check   # green baseline
```

## Tasks (Option A path)

Ensure implementation of maximum party size and maximum party count. Give a
visual indicator in the UI on the Parties screen.

The first upgrade to the Guild Hall (level 1 -> 2) enables party size to be
increased from 4 to 5.

The second upgrade to the Guild Hall (level 2 -> 3) increases the maximum
number of parties from 1 to 2.

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
