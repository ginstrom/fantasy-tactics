# Step 08 — Selected-party defensive query

**Objective:** Make the public selected-party read API safe from external
mutation if it remains a query rather than an internal mutable accessor.

**Dependency:** Step 07 policy approved/merged. **Branch:** `hardening/selected-party-query`.

## Files

- Modify: `scripts/campaign/party_service.gd:80-90`
- Modify: `tests/unit/test_game_session.gd` and/or a focused party-service test
- Inspect all `get_selected_party()` call sites before changing its return
  contract; migrate only callers proven to require mutation.

## Red/green TDD

1. Add a regression that obtains `get_selected_party()`, mutates nested and
   top-level fields on the returned dictionary, then asserts the stored party
   and a fresh `get_selected_party()` read are unchanged. Add a companion test
   that a public mutation path still works through its intended service method.
2. Run the focused test file red.
3. Return `duplicate(true)` from the public query or, if the call-site audit
   proves it cannot be a query, move mutation callers to a narrowly named
   internal accessor and document it. Never expose a mutable durable-state
   dictionary merely for convenience.
4. Run focused green, full/static/diff checks.

Reviewer must receive the call-site audit and verify no direct caller silently
stops persisting a legitimate update. No manual UI check is required. After
user signoff, commit `fix(parties): return defensive selected party snapshots`,
merge locally, delete the branch, and record any intentional mutable boundary.
