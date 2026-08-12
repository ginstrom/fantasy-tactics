# Step 6: Full Verification, Manual Walkthrough & Local Merge

> **Branch:** `feat/scout-ranger-class`

## Goal
Perform comprehensive regression testing, headless battle simulations, manual gameplay walkthrough, user signoff, local merge to `main`, and cleanup.

---

## Verification Checklist

### 1. Automated Unit & Integration Tests
Run the entire automated test suite to confirm zero regressions across all existing systems:
```bash
make check
```
- **Criteria**: All tests (1100+ assertions) pass with 0 failures and 0 errors.

### 2. Headless Battle Simulations
Run 50 automated battle simulations to verify combat stability and AI performance with ranged combatants:
```bash
make simulate
```
- **Criteria**: 50 battles finish cleanly; win rates and average turn counts are logged without crashes or infinite loops.

### 3. Manual Verification Scenario (`make play`)
Perform a manual walkthrough in the game UI:
```bash
make play
```
1. **Encampment & Guild Hall**:
   - Open Guild Hall / Recruitment screen.
   - Verify Scout candidates appear with starting bow (`shortbow_iron`).
   - Recruit a Scout adventurer.
2. **Roster & Equipment**:
   - Open Unit Details for the Scout.
   - Verify class is listed as "Scout" and equipment displays weapon range (1–3).
   - Attempt to equip a heavy 2H sword on the Scout → verify system rejects invalid equipment type.
3. **World Map Scouting Intel**:
   - Assign Scout to `party_001` and deploy to World Map.
   - Hover over / select Goblin Camp and Orc Outpost encounters.
   - Verify scouting intel reveals exact enemy composition (e.g. `1x Goblin, 1x Goblin Archer`).
4. **Tactical Combat**:
   - Enter battle with the Scout.
   - Select the Scout unit. Verify attack range overlay displays 1–3 tiles with LoS filtering.
   - Fire a ranged attack at a distant enemy (costs 3 AP).
   - Verify enemy `goblin_archer` returns ranged fire when in range and LoS.
   - Complete battle cleanly and return home to Encampment.

---

## Local Merge & Branch Cleanup

Upon user signoff:
1. Ensure all changes are committed on `feat/scout-ranger-class`.
2. Merge back to `main` locally:
   ```bash
   git checkout main
   git merge feat/scout-ranger-class
   git branch -d feat/scout-ranger-class
   ```
3. Update `docs/designs/class-system.md` to mark **Slice 2 (Warrior + Scout/Ranger)** as **Shipped**.
