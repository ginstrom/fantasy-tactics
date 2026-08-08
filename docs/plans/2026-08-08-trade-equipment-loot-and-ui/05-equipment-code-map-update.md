# Task 05: Update `docs/dev/code-map.md`'s domain-model section

## Objective

Keep the developer map of `GameSession`'s domain model honest now that the
adventurer record's equipment shape has changed.

## Files

- Modify: `docs/dev/code-map.md`

## Depends on

Task 02 (the `equipment` field it documents).

## Steps

1. In `docs/dev/code-map.md`'s "Domain model" section, replace:

   ```
   - **`adventurers: Array[Dictionary]`** — the full roster, whether or not a
     member is assigned to a party. Each entry: `id`, `name`, `class`,
     `weapon`, `level`, `availability_status`, `stats` (`max_health`, `attack`,
     `move_range` — base values), `progression` (`xp: float`, `skill_points`,
     `perks: Array`).
   ```

   with:

   ```
   - **`adventurers: Array[Dictionary]`** — the full roster, whether or not a
     member is assigned to a party. Each entry: `id`, `name`, `class`,
     `equipment` (`{weapon: String, armor: String}` — item ids into
     `GameSession.WEAPONS`/`GameSession.ARMORS`, see
     `docs/plans/2026-08-08-trade-equipment-loot-and-ui/`), `level`,
     `availability_status`, `stats` (`max_health`, `attack`, `move_range` —
     base values), `progression` (`xp: float`, `skill_points`, `perks: Array`).
   ```

2. **Commit** only this task's files:

   ```bash
   git add docs/dev/code-map.md
   git commit -m "docs: update code-map for the adventurer equipment field"
   ```

## Milestone

`docs/dev/code-map.md` accurately describes the adventurer record's
`equipment` field instead of the stale unused `weapon` string, closing out
Phase A.
