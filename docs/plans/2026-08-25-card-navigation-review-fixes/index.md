# Card Navigation Review Fixes Implementation Plan

> **For Codex:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Goal:** Repair the three confirmed card-navigation review findings without changing unrelated gameplay behavior.

**Architecture:** `CardNavigator` remains the sole modal owner for Escape while a `LevelUp` body is embedded in it. `AddMember` maps the reusable unit-card assignment intent to its already-selected target party. The exit-gate report is corrected to reflect a whitespace-clean committed diff.

**Tech Stack:** Godot 4.7.1, GDScript, GUT 9.7.1, Markdown.

## Ordered steps

1. [Restore Escape ownership and Add Member assignment](01-interaction-regressions.md)
2. [Correct verification formatting and run the regression gate](02-verification-and-handoff.md)

Run the steps serially. Each starts with a focused failing GUT test, follows with the smallest production change, reruns focused tests, and preserves all unrelated work. After the documented manual `make play` check and user signoff, commit this branch and merge it locally to `main`; do not push or open a PR.
