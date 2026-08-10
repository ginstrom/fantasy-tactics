# Step 2 — Item Instances and Modifiers

## Milestone

Existing stackable normal gear migrates safely to immutable base definitions plus unique owned item instances when improved, equipped, saved, sold, or restored.

## Red/green delivery

Branch as `feat/equipment-instances`. Add failing tests for instance creation, ownership transfer, duplicate-id rejection, category replacement, cross-category stacking, snapshot round trips, and failed atomic operations. Implement `GameSession` instance/recipe APIs and migrate active equipment pointers without breaking normal Stores or unit inventory behaviour. Verify focused tests, `make check`, editor scan, snapshot tests, and `git diff --check`; use `make play` to equip normal and improved items. After user signoff, commit, merge locally, delete the branch, and do not push.
