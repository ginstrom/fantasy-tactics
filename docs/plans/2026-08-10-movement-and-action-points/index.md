# Movement and Action Points Guide Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Publish one canonical guide for tactical movement and Action Points,
then direct related design documents to it.

**Architecture:** The new design guide owns generic Round/AP rules and future
extension constraints. Class and equipment documents keep class/item-specific
rules, linking to the guide rather than duplicating generic AP mechanics.

**Tech Stack:** Markdown documentation and Git validation.

---

## Scope and invariants

- The current movement-plus-one-attack turn remains explicitly **Shipped**;
  generic AP remains **Next slice**.
- Every unit receives 6 AP at the start of a Round. Move one tile costs 1 AP,
  basic attack costs 3 AP, and using a carried potion costs 2 AP.
- A unit may take any legal action while it can pay AP; AP, not an implicit
  attack limit, determines how many attacks it may make.
- The guide defines shared mechanics only. Equipment and class effects retain
  their own ownership and link to it.

## Steps

1. [Create the canonical guide and update cross-links](01-canonical-guide-and-cross-links.md)

## Completion

After the user reviews the guide through `make play` when the AP implementation
arrives, merge the feature branch locally into `main` and delete the branch.
Do not push unless the user asks.
