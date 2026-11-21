---
name: godot-gatekeeper
description: >-
  Use this skill to run headless tests, verify slice DoD (Definition of Done), and diagnose Godot 4
  GDScript engine errors in the kalastuspeli project.
---

# Godot Gatekeeper & DoD Verification

This skill provides fast, fail-closed verification of headless Godot tests, slice constraints, architectural boundaries, and SHA-256 test/spec locks.

## 1. Quick Verification & SHA-256 Locking

Before handing off a slice to a Builder subagent, lock the test harness, acceptance tests, and slice specs:
```bash
bash .agents/skills/godot-gatekeeper/scripts/lock_slice.sh
```
This writes `.agents/slice_lock.sha256` (gitignored) so any modification to locked tests or specs—including newly created, untracked acceptance tests—causes Gate 4 to fail.

Run all 5 verification gates:
```bash
bash .agents/skills/godot-gatekeeper/scripts/check_slice.sh
```

Other lock helper commands:
- `bash .agents/skills/godot-gatekeeper/scripts/lock_slice.sh --verify` — verify SHA-256 checksums without running Godot tests.
- `bash .agents/skills/godot-gatekeeper/scripts/lock_slice.sh --clear` — remove `.agents/slice_lock.sha256` (run automatically by `finish_slice.sh` after push).

## 2. Gatekeeper Quality Gates (Fail-Closed)

| Gate | Requirement | Recovery / Rule |
| :--- | :--- | :--- |
| **[1/5] Slice Size & Test Limits** | Spec `≤ 60` non-empty lines; slice tests `≤ 5` `func test_` methods | Split the slice per `specs/00-architecture.md §5`. |
| **[2/5] Single Scene Rule** | Only `src/main.tscn` may exist under `src/` | Delete extra `.tscn` files and build nodes procedurally in GDScript. |
| **[3/5] Headless Core Boundary** | Zero `Node`, view, input, or network class references in `src/core/` | Refactor `src/core/` code to pure `RefCounted` data/simulation. |
| **[4/5] Test & Spec Immutability** | SHA-256 lock `.agents/slice_lock.sha256` matches (or, if absent, tracked `tests/run*` and `tests/test_*.gd` have no diff/delete) | Revert accidental builder edits (`git checkout -- tests/ specs/slices/`). Pass `ALLOW_TEST_EDITS=1` only when intentionally editing tracked tests without a lock file. |
| **[5/5] Headless Tests & Engine Errors** | `bash tests/run.sh` exits `0` with `0` `SCRIPT ERROR` or `ERROR:` lines | Fix the implementation in `src/` and re-run `check_slice.sh`. |

## 3. Common Godot Headless Gotchas

- **Import Cache:** Godot headless registers `class_name` definitions during `--import`. If a class is not found, ensure `--import` has finished cleanly.
- **Fixed Physics Step:** Always use `1.0 / 60.0` delta in simulation tests to ensure determinism.
- **No Node3D in Core:** If an error mentions `Node3D`, `Transform3D`, or visual classes in `src/core/`, refactor to use pure GDScript data (`Vector3`, `float`, `Dictionary`, `RefCounted`).
