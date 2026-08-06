# Two Starting Encounters Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Start each campaign with a one-star Goblin Camp and a two-star Orc
Outpost, using stars as the World Map's only encounter label.

**Architecture:** `GameSession` gains display-only difficulty data and seeds
the two documented active encounter instances. `WorldMap` derives a bounded
star string directly from each active record and replaces the text label. The
existing clear/vacancy behavior continues to replace one cleared site after
15 World Map turns without exceeding the two-site cap.

**Tech Stack:** Godot 4.7.1, GDScript, GUT, semantic translation resources.

---

## Delivery protocol

1. Work from a regular branch off current `main`; do not use a worktree.
2. Follow red/green TDD for every behavior change. Preserve unrelated edits.
3. Before manual verification, run `make check`,
   `godot --headless --path . --editor --quit`, and `git diff --check`.
4. Ask the user to run `make play`. Merge locally only after user signoff; do
   not push unless asked.

## Steps

1. [01-two-site-session-state.md](01-two-site-session-state.md) — make the
   initial encounter state and difficulty data explicit.
2. [02-star-map-markers.md](02-star-map-markers.md) — replace World Map text
   labels with star markers and cover rendering regression cases.
3. [03-integration-and-design-record.md](03-integration-and-design-record.md)
   — run the full checks, complete the manual route, and merge after signoff.
