---
name: slice-lifecycle
description: >-
  Use this skill to close a vertical slice, verify Definition of Done (DoD), update specs/01-state-schema.md
  and specs/02-roadmap.md, and commit/push changes per project rules.
---

# Slice Lifecycle & DoD Runbook

Follow this runbook when completing a vertical slice.

## 1. Definition of Done (DoD) Checklist

Before marking a slice complete, verify each item:
- [ ] `bash .agents/skills/godot-gatekeeper/scripts/check_slice.sh` passes (exit code 0, 0 engine errors, spec ≤ 60 lines).
- [ ] `specs/01-state-schema.md` updated with the State Delta from the slice.
- [ ] View slices: manual visual/budget check verified.
- [ ] User tested `"Nyt voin ___"` result.
- [ ] `specs/02-roadmap.md` status updated from `draft`/`in-progress` to `done`.
- [ ] Git commit (`feat(slice-NN): …`) and `git push origin main`.

## 2. Automating DoD & Git Commit

Run the lifecycle helper:
```bash
bash .agents/skills/slice-lifecycle/scripts/finish_slice.sh <slice-num> "<commit-message>"
```

Example:
```bash
bash .agents/skills/slice-lifecycle/scripts/finish_slice.sh 04 "add station interaction and helm occupation"
```
