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

1. **Acceptance Test & Spec Immutability:** Never modify `tests/test_*.gd`, `tests/run*`, or `specs/slices/*.md` (they are SHA-256 locked by the Architect). If an acceptance test appears wrong, report it to the Architect rather than changing it.
2. **Scope Boundary:** Modify or create **only** the files listed in the slice spec's §6 (`src/` and any explicitly requested helper unit tests). Never touch `tests/test_*.gd`, `tests/run*`, `specs/`, `project.godot`, `.agents/`, or `tools/`.
3. **No Git Commits:** Never run `git commit` or `git push`. Leave committing to the Orchestrator / `finish_slice.sh`.
4. **Headless Core Boundary (`src/core/`):**
   - Pure logic classes must extend `RefCounted`.
   - **Zero dependencies** on `Node`, `Node3D`, rendering, `Input`, or networking classes.
   - Simulation step: `step(state, delta)` must use fixed delta `1.0 / 60.0`.
5. **Single Scene Rule:**
   - Only **one** `.tscn` file exists (`src/main.tscn`).
   - All 3D meshes, materials, lights, cameras, and UI elements are created procedurally via GDScript.
6. **Coordinate Spaces:**
   - Players move and synchronize in **Boat Local Space** (`local_position: Vector3`).
   - In view layer (`src/view/`), `PlayerView` instances must be children of `BoatView/PlayersContainer`.
7. **Language Rule:**
   - All code, class names, variables, functions, and inline comments must be in **English**.
   - Specifications and documentation are in **Finnish**.
8. **Retry Cap (Max 3 Attempts):**
   - You have at most **3** test-fix cycles. If `bash tests/run.sh` still fails after 3 attempts, stop immediately and report the verbatim failure output to the Architect—do not keep guessing or modifying unrelated files.
9. **Verbatim Reporting:**
   - Report exact exit codes and verbatim outputs from `bash tests/run.sh` and `git status --short` without skipping errors or warnings.

## 2. Implementation Workflow

1. Read the assigned slice spec in `specs/slices/NN-<slug>.md` and the acceptance test in `tests/test_NN_<slug>.gd`.
2. Inspect existing models in `specs/01-state-schema.md` and related files under `src/core/state/` and `src/core/simulation/`.
3. Implement only the minimal code required in the allowed files to satisfy State Delta and Rules & Math.
4. Run verification (max 3 attempts):
   ```bash
   bash tests/run.sh
   ```
5. If tests fail:
   - Fix your implementation only within your allowed `src/` files.
   - Do **NOT** touch `tests/test_*.gd` or `specs/`.
6. Before reporting completion, run `git status --short` and confirm exit code `0` and zero `SCRIPT ERROR` / `ERROR:` lines, then report all outputs verbatim.
