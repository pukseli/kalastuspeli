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

## 2. Authoring Workflow

1. Consult `specs/02-roadmap.md` for the next slice goal.
2. Create `specs/slices/NN-<slug>.md` using the template at [slice_template.md](./resources/slice_template.md).
3. Draft the acceptance test at `tests/test_NN_<slug>.gd`:
   - Inherits `extends "res://tests/test_case.gd"`.
   - Maximum 5 tests using **Given-When-Then** naming and structure.
4. Verify spec length:
   ```bash
   grep -c '[^[:space:]]' specs/slices/NN-<slug>.md
   ```
5. Hand off to Builder (e.g. `flash` model) using a minimal Zero-Duplication prompt referencing the slice file.
