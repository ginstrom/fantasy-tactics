# Information Design Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Give player-facing information one clear home: panels for context,
one large modal for consequential outcomes, and a durable Encampment Journal.

**Architecture:** `GameSession` owns append-only Journal records and read
state; `CampaignSnapshot` persists them. UI scenes present records and request
acknowledgement. Battlefield builds one post-battle payload that drives an
in-place outcome modal and player-selected level-up modals.

**Tech Stack:** Godot 4.7.1, GDScript, `.tscn` scenes, GUT 9.7.1.

## Delivery rules

This is serial. Start each step from current `main` on a regular branch--never
a worktree. Read `docs/dev/README.md`, this index, the assigned step, and its
source contracts. Preserve unrelated changes. An independent reviewer checks
`git diff <base>...HEAD`. Only after review and user manual signoff: commit
documented files, merge locally to `main`, delete the branch, and record a
handoff. Do not push or open a PR unless asked.

## Ordered milestones

1. [Durable Journal domain and snapshot](01-journal-domain-and-snapshot.md)
2. [Journal navigation and views](02-journal-navigation-and-views.md)
3. [Panels and modal shell](03-panels-and-modal-shell.md)
4. [Battle outcome and level-ups](04-battle-outcome-and-level-ups.md)
5. [Event wiring and exit gate](05-event-wiring-and-exit-gate.md)

Step 4 depends on 3. Step 5 depends on 1-4. Accepted Guild Hall quests remain
an explicit future decision: Quests initially renders a placeholder rather
than inventing acceptance behavior.

## Exit gate

Run `make check`, `godot --headless --path . --editor --quit`, `git diff
--check`, and `make screenshots`. Manual `make play`: verify unoccluded World
Map panels; one battle outcome modal even with multiple level-ups; View returns
to it; Escape behavior; and individual Journal `!` acknowledgement.
