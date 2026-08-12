# Step 6: Integrated Verification and Signoff

## Preconditions

Steps 1–5 are individually signed off and merged locally to `main`; do not
create another feature branch or repeat their merges.

## Automated verification

Run from `main`:

```bash
godot --headless --path . --editor --quit
make check
git diff --check
rg -n -i 'Trading Post' scripts scenes translations tests docs
```

The first three commands must succeed. The final audit must contain only the
documented legacy schema/compatibility allowlist; no player-visible text may
remain.

## Manual signoff (`make play`)

1. New campaign: Shop is available at level 1 with 100 Shop gold, iron weapons
   only, and passive income reaches player gold after End Turn.
2. Verify Shop budget transfers on buy/sell, insufficient Shop cash blocks a
   sale unchanged, the tenth successful turn refills only to cap, and the
   50-gold upgrade unlocks steel and a 200-gold cap.
3. Verify first-party Create/Dismiss behavior, direct Party Details landing,
   and both Add from Roster and direct-to-that-party Recruit routes.
4. Verify ordinary recruitment stays in place, View Roster works, and targeted
   recruitment does not misassign after a target becomes invalid.
5. Visit all Units, Buildings, and Trade descendants; verify their exact
   left-aligned/indented submenus. Verify Deploy Party absence/presence.
6. In Stores verify direct button states for no selection, equipment, mana
   crystal, and Shop-underfunded sale. Verify Party Details/victory tables do
   not gain irrelevant direct controls.

Record user signoff. No remote push or PR is part of this plan.
