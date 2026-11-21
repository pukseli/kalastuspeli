---
name: slice-architect
description: >-
  Use this skill when drafting, specifying, or planning a new vertical slice (specs/slices/NN-*.md)
  and its acceptance tests (tests/test_NN_*.gd) in the kalastuspeli project.
---

# Slice Architect Runbook

Use this skill when authoring new slices according to the project's **Atomic Vertical Slicing** ideology.

## 1. Slice Sizing Constraints (Strict Limits)

| Constraint | Limit |
| :--- | :--- |
| **Deliverable** | Exactly **one** user-testable capability: `"Nyt voin ___"` |
| **New Concept** | Exactly **one** new architectural concept |
| **Acceptance Tests** | Maximum **5** acceptance tests |
| **Spec Length** | Maximum **60 non-empty lines** |

> If any limit is exceeded, split the slice into smaller increments (e.g., core logic first, then networking/view).

## 2. Authoring & Hand-off Workflow

1. **Check Git Precondition:** Run `git rev-parse --short HEAD && git status --short` before drafting or delegating so the starting state is clean and known.
2. Consult `specs/02-roadmap.md` for the next slice goal.
3. Create `specs/slices/NN-<slug>.md` using the template at [slice_template.md](./resources/slice_template.md).
4. Draft the acceptance test at `tests/test_NN_<slug>.gd`:
   - Inherits `extends "res://tests/test_case.gd"`.
   - Maximum 5 tests using **Given-When-Then** naming and structure.
5. Verify limits (`<= 60` non-empty lines, `<= 5` tests) and **lock** specs & tests with SHA-256 before starting the Builder:
   ```bash
   grep -c '[^[:space:]]' specs/slices/NN-<slug>.md
   grep -cE '^[[:space:]]*func[[:space:]]+test_' tests/test_NN_<slug>.gd
   bash .agents/skills/godot-gatekeeper/scripts/lock_slice.sh
   ```
6. Hand off to Builder (`Model: "flash"`) with a **Zero-Duplication, Bounded-Scope** prompt containing:
   - Exact files to read (`specs/slices/NN-<slug>.md`, `tests/test_NN_<slug>.gd`, `specs/01-state-schema.md`)
   - Explicit **Allowed Files** (the files listed in spec §6)
   - Explicit **Forbidden Paths**: `tests/test_*.gd`, `tests/run*`, `specs/`, `project.godot`, `.agents/`, `tools/`
   - Instruction: **"Do NOT commit. Max 3 fix attempts; report command outputs verbatim."**

## 3. Orchestrator Verification & Retry Rule

- **Trust, but verify:** Never rely solely on the Builder subagent's summary. After the Builder completes, always run the full gatekeeper yourself:
  ```bash
  bash .agents/skills/godot-gatekeeper/scripts/check_slice.sh
  git status --short
  ```
- **Retry / Rollback Rule:**
  - If verification fails with a localized implementation bug, send the exact failure output to that same Builder subagent **once** (`send_message`).
  - If the **second** attempt also fails—or if Gate 4 detects any tampering with locked tests/specs—revert invalid builder changes (`git checkout -- src/` or affected paths), stop delegating to Flash, and resolve the issue directly as Architect.
