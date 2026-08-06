# UI Follow-Up: Game-Loop Reachability, Testing Gaps, and Deferred Fixes

## Purpose

This branch (`feat/encampment-roster-recruitment`) passed its own scoped
reviews and a final whole-branch review — 439/439 automated tests, clean
editor scan, clean diff — but none of that verification actually drove the
game through its real, click-by-click UI. When asked directly how the full
loop had been verified end to end, the honest answer was: it hadn't been.
Investigating that question surfaced a genuine, pre-existing blocker in the
base game (not introduced by this branch), plus a structural reason the
existing test suite and review process could never have caught it.

This document records, in priority order: the game-loop blocker, why testing
missed it, and every fix already flagged during this branch's reviews that
remains open.

## P0 — A real player cannot create a party, at all, ever

**A fresh game has no in-UI path to create the first (or any) party.** Every
other step of the core loop — deploy, travel, fight, return, bank reward — is
genuinely wired to real clicks and works once a party exists. This one step
has no button anywhere.

### What's actually there

- `scripts/ui/party_manager.gd:1-16` is a redirect stub: `_ready()` calls
  `GameManager.go_to_parties()` on the next idle frame. Its own comment says
  why: *"Party management now lives in Parties (reached from Units). This
  scene is kept only as a testable redirect."*
- `scripts/ui/parties.gd` / `scenes/ui/parties.tscn` only list and view
  existing parties (Title / `PartyTable` / EmptyLabel / Back). No create
  action exists in the scene or the script.
- `translations/en.tres:21-23` still carries `party.create` ("Create Party"),
  `party.add_warrior`, `party.remove_warrior` — but grepping the entire
  non-test codebase, the only remaining reference to any of them is
  `tests/unit/test_localization.gd:79-81`, which just asserts the strings
  resolve. No `.gd`/`.tscn` file calls `tr()` on them or wires them to a
  handler. They are dead.
- `GameSession.create_party()` (`scripts/autoload/game_session.gd:126-128`)
  is also hard-capped at one party ever: `if not parties.is_empty(): return
  false`.
- Every real call site for `create_party()` outside of tests is: the F9 debug
  menu (`scripts/debug/debug_scenarios.gd:30,42`, gated behind
  `OS.is_debug_build()` at `game_manager.gd:53,243`) and the dev-only
  screenshot tour (`scripts/tools/screenshot_tour.gd:49`). Every other call
  site — dozens — is test setup.

### This is a known regression, not new scope

`docs/plans/first-playable-campaign/game-design.md` (the standing roadmap for
this game) says so directly:

> "Party creation and Warrior assignment, previously reachable from an
> Encampment 'Party Manager' screen, are superseded by the Milestone 4
> encampment UI shell below. Party Details now offers Add Member for an
> encamped party, restoring the ordinary in-game assignment path."

Assignment was restored when Party Details got its Add Member button.
Creation never got an equivalent replacement — it fell through the cracks
between that milestone and this one. This branch's own goal, per that same
roadmap doc, was to let "a new campaign grow beyond its starting Warrior
without debug tooling" — recruitment does that, but only for a roster that
already has a party to assign new hires into. The blocker sits one step
earlier than anything this branch touched, which is why it was in scope for
neither this branch's design doc nor its reviews, and why it's easy to miss:
recruiting/assigning/deploying/fighting are all real and correct, but a
genuinely fresh save can't reach any of them.

### Design tension worth resolving at the same time

`GameSession.create_party()`'s one-party-ever cap
(`game_session.gd:127-128`) predates this branch, but this branch's own
Roster → Unit Details "Add to Party" feature calls
`GameSession.get_encamped_parties()` and presents a *picker* of eligible
parties — UI built for a world with more than one party, sitting on top of a
domain layer that only ever allows one. Whoever builds the Create Party
screen needs to decide: lift the one-party cap now, or keep Create Party
single-shot (disabled/hidden once a party exists) and treat the picker as
future-proofing that stays inert until a later milestone actually allows
multiple parties.

### Recommended fix

Add a real "Create Party" action reachable from Parties (or Units), calling
`GameSession.create_party()` through a `GameManager` wrapper (matching every
other mutation in this codebase's established shape — validate, mutate,
return `Error`/`bool`, let the caller decide whether to navigate). Decide the
one-party-cap question above before or during that work, not after.

## Why the test suite and review process didn't catch this

Every test in this codebase (all 439, including the ones added by this
branch) and the screenshot tour follow the same shape: seed `GameSession`
state directly, then instantiate one target screen and assert on it. None of
them ask "how would a player have reached this state?" — they don't need to,
because the direct API call always short-circuits that question.

Concrete examples of the pattern:

- `tests/unit/test_game_manager.gd:68-77` builds a fully-staffed party via
  three direct `GameSession` calls, then invokes
  `manager.depart_selected_party()` as a plain function call — never through
  Encampment's Deploy Party button.
- `tests/unit/test_encampment.gd:42-52` proves the Deploy Party button
  enables once a party exists, but creates that party with
  `GameSession.create_party()` and forces a redraw with `screen.refresh()` —
  it never asks how the party got there.
- `tests/unit/test_deploy_party.gd:15-29`'s `_ineligible_party()` helper
  hand-crafts a *second* raw party dictionary and appends it straight into
  `GameSession.parties`, bypassing `create_party()`'s one-party cap entirely
  (its own comment admits this: *"create_party only ever allows one real
  party in this slice"*).
- Several "routing" tests never execute anything:
  `tests/unit/test_game_manager.gd:10-33` and
  `tests/unit/test_deploy_party.gd:184-186` read the `.gd` file as text and
  assert a string like `"GameManager.go_to_encampment()"` appears in it. That
  proves a call exists somewhere in the file; it proves nothing about
  whether a button is wired to it.
- The screenshot tour's `"parties"` step
  (`scripts/tools/screenshot_tour.gd:48-51`) calls
  `GameSession.create_party()` directly, and its `"world_map"` step
  (`:70-71`) calls `GameManager.depart_selected_party()` directly rather than
  activating a row in the Deploy Party table — so even the one tool whose
  whole job is "show me every real screen" never exercises the real
  deploy-by-clicking-a-row path, let alone a nonexistent Create Party button.
- No test anywhere in the suite instantiates a scene, triggers a real
  navigation side effect, and then instantiates the *next* screen to
  continue the flow. The proven, working test convention here is
  exclusively single-screen: seed state directly, assert one screen (or a
  source-text substring). That convention is structurally blind to a missing
  button, because it never needs the button.

This branch's own review process inherited the same blind spot. Five
task-scoped reviews and one final whole-branch review all worked from diffs
and test output — real, careful verification of what the code does, but none
of it was "install the game and click through it," because nothing in the
process ever asked a subagent to do that, and the one point where the plan
itself called for real play (index.md's acceptance route, gated on human
approval) hadn't happened yet when this was raised.

**Process recommendation:** for any future milestone that touches core-loop
reachability (not just an isolated screen), add at least one integration
test that chains real signal emissions across more than one screen instance
end-to-end, and/or move human play-testing earlier than the final merge gate
— a mid-branch play-test of just the new screens would have surfaced this
immediately, since Roster and Recruitment are themselves only reachable once
a party already exists to recruit *for*.

## P1 — Fixes already flagged during this branch's reviews, still open

These were raised as Minor findings during task-scoped or final review,
deliberately deferred (not blocking), and remain unfixed:

1. **Raw, untranslated status literals in new code.**
   `scripts/ui/roster.gd:64` renders `availability_status` verbatim
   ("available"); `scripts/ui/parties.gd:59` and
   `scripts/ui/deploy_party.gd:64` hardcode the literal strings
   `"deployed"`/`"encamped"` directly in the controller, with no translation
   key. `docs/party-screens.txt` shows these as title-case ("Available",
   "Encamped") in its mockups. Suggested keys: `roster.status.*`,
   `parties.status.*`.

2. **Dead translation keys**, two separate sets:
   - From this branch: `party_details.member_row` (`translations/en.tres`),
     `deploy_party.party_row`, `add_member.member_row` — no code references
     any of them after the Milestone 4 `TableView` migration replaced the
     button-row rendering that used to call them.
   - Pre-existing, surfaced by the P0 investigation above:
     `party.create`, `party.add_warrior`, `party.remove_warrior`
     (`translations/en.tres:21-23`) — dead since the old Party Manager
     screen was replaced. Resolve these together with the P0 fix (the new
     Create Party action may want to reuse or replace `party.create`).

3. **`_tree_row_values()` is copy-pasted verbatim into six test files**
   (`test_add_member`, `test_deploy_party`, `test_parties`,
   `test_party_details`, `test_recruitment`, `test_roster`) across
   Milestones 2-4 of this branch. Worth hoisting into a shared test helper.

4. **Two milestones independently reinvented the same predicates.**
   `unit_details.gd`'s adventurer-unassigned check and `add_member.gd`'s
   adventurer-available check are the same linear scan of
   `get_available_adventurers()`; `deploy_party.gd`'s deployability check and
   `recruitment.gd`'s candidate-exists check are the same shape again. Per
   this codebase's own ownership rule (`GameSession` owns
   eligibility/validation), these belong there as named queries (e.g.
   `is_adventurer_available(id)`, `has_recruitment_candidate(id)`) rather
   than being reimplemented per-controller.

5. **No single test exercises the recruit → assign → Roster-shows-the-party
   round trip in one place.** Coverage is thorough per-unit (purchase in
   `test_game_session`, assignment in `test_unit_details`, the Party column
   in `test_roster`) but the seam between them is only proven by reading
   three files together. A single test doing all three steps against the
   real objects (no scene changes needed) would guard against a future
   regression at the boundary.

6. **The screenshot tour never captures the new purchase UI.** Its
   `"recruitment"` and `"roster"` steps select no row, so the
   InformationPanel's recruitment summary + Recruit button — the main new
   panel surface from Milestone 3 — appears in no screenshot, and neither
   does an affordable-vs-unaffordable button state.

7. **Add Member's newly-wired View button loses the party you came from.**
   Milestone 4 wired Add Member's panel `adventurer_selected` signal to
   `GameManager.go_to_unit_details(id)` for the first time (previously Add
   Member had no InformationPanel selection state at all). Unit Details'
   Back button only knows two destinations — Roster origin, or the
   hardcoded default of Parties — so View → Back from Add Member lands on
   Parties, not back on the party you were adding a member to. Minor because
   it's new-but-harmless surface area, not a regression of prior behavior,
   but worth an origin-aware fix if Add Member's View action is meant to
   stay.

8. **Cosmetic, no action needed unless convenient:**
   `scripts/ui/recruitment.gd:50`'s `cost_column` has no explicit
   `TableColumn.Type.INTEGER` (harmless today — string comparison already
   sorts "10" correctly via natural-sort; would only matter if a future
   candidate's cost isn't a clean two-digit match). `information_panel.gd`'s
   `information.recruitment_cost` translation value ("Cost:") carries its
   colon differently than sibling keys do; purely stylistic.

## Priority summary

| Priority | Item | Blocks |
|---|---|---|
| P0 | No Create Party UI | The entire core loop, for any real player |
| P0-adjacent | One-party cap vs. multi-party assignment UI | Design decision needed before/with the P0 fix |
| P1 | Items 1-8 above | Nothing functionally; polish/hygiene/coverage |
