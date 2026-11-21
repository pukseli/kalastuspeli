---
name: godot-gatekeeper
description: >-
  Use this skill to run headless tests, verify slice DoD (Definition of Done), and diagnose Godot 4
  GDScript engine errors in the kalastuspeli project.
---

# Godot Gatekeeper & DoD Verification

This skill provides fast, reliable verification of headless Godot tests and slice constraints.

## 1. Quick Verification

Run the slice verification script:
```bash
bash .agents/skills/godot-gatekeeper/scripts/check_slice.sh
```

To also check that acceptance tests have not been accidentally modified by a builder subagent:
```bash
CHECK_TEST_DIFF=1 bash .agents/skills/godot-gatekeeper/scripts/check_slice.sh
```

## 2. Gatekeeper Quality Gates

| Gate | Requirement | Recovery / Rule |
| :--- | :--- | :--- |
| **Exit Code** | `0` | If non-zero, check failure summary at end of log. |
| **Engine Errors** | `0` errors | `tests/run.sh` scans for `SCRIPT ERROR` and `ERROR:` lines. |
| **Spec Line Limit** | `≤ 60` non-empty lines | If violated, slice must be split per `specs/00-architecture.md §5`. |
| **Acceptance Tests** | Unmodified by builder | Revert any accidental changes to `tests/test_*.gd` (`git checkout -- tests/test_*.gd`). |

## 3. Common Godot Headless Gotchas

- **Import Cache:** Godot headless registers `class_name` definitions during `--import`. If a class is not found, ensure `--import` has finished cleanly.
- **Fixed Physics Step:** Always use `1.0 / 60.0` delta in simulation tests to ensure determinism.
- **No Node3D in Core:** If an error mentions `Node3D`, `Transform3D`, or visual classes in `src/core/`, refactor to use pure GDScript data (`Vector3`, `float`, `Dictionary`, `RefCounted`).
