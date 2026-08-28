# Step 07 — Numeric-key persistence policy

**Objective:** Choose and enforce one safe persisted-dictionary key policy
before any numeric-only ID namespace is introduced.

**Dependency:** Step 06 merged. **Branch:** `hardening/numeric-json-keys`.

## Required policy confirmation

Present these options to the user with a JSON round-trip example and obtain a
written choice before implementation:

1. **Schema-aware normalization (recommended):** preserve string keys globally
   and convert only documented numeric maps (currently crystal tiers) at their
   schema boundary.
2. **Forbid numeric-only IDs:** validate/reject them at every write boundary;
   retain global conversion.
3. **Typed envelope/migration:** version a broader format change; choose only
   if another planned schema needs it.

## Files

- Modify: `scripts/save/save_repository.gd:160-188` and selected snapshot
  normalizers in `scripts/save/campaign_snapshot.gd`
- Modify: `tests/unit/test_save_repository.gd` and/or
  `tests/unit/test_campaign_snapshot.gd`
- Modify: a durable persistence design reference only if the policy changes
  the save-format contract

## Red/green TDD and completion

After approval, add real JSON stringify/parse round trips for a numeric-only
key in every affected category and for integer crystal tiers. Assert the
chosen category survives with its required type, unsupported data fails
atomically with a useful error, and no unrelated key changes type. Run the
relevant focused file(s) red, make the narrow schema-aware/validation change,
then run focused green, `make check`, editor parse, and `git diff --check`.

Reviewer checks migration/compatibility and that no global rule accidentally
rewrites unrelated dictionaries. No manual UI check is needed. After user
signoff, commit only the approved policy implementation and tests, merge/delete
the branch, and record the choice for future ID work.
