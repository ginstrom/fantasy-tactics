# UI Layout Design Guidelines

**Implementation status:** these are enduring UI design rules. A component or
layout that follows them is **to implement** until its owning screen ships;
consult the [design status legend](README.md#implementation-status-legend).

## Philosophy

Build UI using **hierarchical layout containers**, not absolute positioning.

Each component is responsible only for laying out its own children. Parent containers determine where components appear on the screen.

---

## Rules

### 1. Use Containers for Layout

- Use `HBoxContainer`, `VBoxContainer`, `GridContainer`, `MarginContainer`, `PanelContainer`, etc.
- Avoid setting `position` or `size` manually for normal UI components.
- Containers define the application's regions.

### 2. Compose Layout Hierarchically

Break the screen into progressively smaller regions.

Example:

```text
Root
└── VBoxContainer
    ├── TopBar
    ├── HBoxContainer
    │   ├── LeftPanel
    │   ├── MapView
    │   └── RightPanel
    └── BottomBar
```

Each child may further subdivide itself using additional containers.

### 3. Components Own Their Contents

Each component manages only its internal layout.

Example:

```text
RightPanel
└── VBoxContainer
    ├── Status
    ├── TableView
    ├── Spacer
    └── Actions
```

A component should never depend on where it is placed in the application.

### 4. Prefer Constraints Over Coordinates

Use:

- Expand / Fill
- Custom Minimum Size
- Stretch ratios
- Theme margins and spacing

Avoid:

- Hardcoded pixel positions
- Layout calculations in code
- Manually updating sibling positions

### 5. Separate Layout from Behavior

Scene hierarchy determines layout.

Components implement behavior only.

For example:

```
MainUI
├── MapView
├── InspectorPanel
├── TableView
└── StatusPanel
```

`MainUI` decides where these components go.

### 6. Use Coordinates Only for World Objects

Absolute positioning is appropriate for:

- Map objects
- Unit markers
- Selection rectangles
- Tooltips
- Floating windows
- Drag-and-drop operations

Application UI should remain container-driven.

---

# Component Responsibilities

| Component | Responsible For | Not Responsible For |
|-----------|-----------------|---------------------|
| Main UI | Screen layout | Internal panel layout |
| Panel | Layout of its children | Screen position |
| TableView | Table rendering and interaction | Sidebar placement |
| LootTable | Tabular loot display and direct actions | Screen placement |
| CardNavigator | Modal shell, ID snapshot, cycling arithmetic, focus management | Card body contents, domain state |
| MapView | Map rendering and overlays | Window layout |

---

# Guiding Principle

> **Containers determine where components live. Components determine how their contents are arranged.**
