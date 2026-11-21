---
name: slice-builder
description: >-
  Use this skill when implementing a vertical slice, writing or editing GDScript code in src/,
  or acting as a Builder subagent in the kalastuspeli project. Enforces core architecture boundaries,
  test immutability, and headless verification.
---

# Slice Builder Runbook

Follow these mandatory rules when implementing vertical slices (`src/` and unit tests).

## 1. Non-Negotiable Rules

1. **Acceptance Test Immutability:** Never modify `tests/test_*.gd` acceptance tests created by the Architect. If a test appears wrong, report it to the Architect rather than changing it.
2. **Headless Core Boundary (`src/core/`):**
   - Pure logic classes must extend `RefCounted`.
   - **Zero dependencies** on `Node`, `Node3D`, rendering, or networking classes.
   - Simulation step: `step(state, delta)` must use fixed delta `1.0 / 60.0`.
3. **Single Scene Rule:**
   - Only **one** `.tscn` file exists (`src/main.tscn`).
   - All 3D meshes, materials, lights, cameras, and UI elements are created procedurally via GDScript.
4. **Coordinate Spaces:**
   - Players move and synchronize in **Boat Local Space** (`local_position: Vector3`).
   - In view layer (`src/view/`), `PlayerView` instances must be children of `BoatView/PlayersContainer`.
5. **Language Rule:**
   - All code, class names, variables, functions, and inline comments must be in **English**.
   - Specifications and documentation are in **Finnish**.

## 2. Implementation Workflow

1. Read the assigned slice spec in `specs/slices/NN-<slug>.md` and the acceptance test in `tests/test_NN_<slug>.gd`.
2. Inspect existing models in `specs/01-state-schema.md` and related files under `src/core/state/` and `src/core/simulation/`.
3. Implement the minimal code required to satisfy the State Delta and Rules & Math specified in the slice.
4. Run verification:
   ```bash
   bash tests/run.sh
   ```
5. If tests fail:
   - Fix your implementation in `src/`.
   - Do **NOT** touch the acceptance tests in `tests/test_*.gd`.
6. Confirm exit code is 0 and no `SCRIPT ERROR` appears in output before reporting completion.
