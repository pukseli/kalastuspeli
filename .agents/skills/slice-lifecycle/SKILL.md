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
- [ ] Orchestrator runs `bash .agents/skills/godot-gatekeeper/scripts/check_slice.sh` itself and confirms all 5 fail-closed gates pass (spec ≤ 60 lines & tests ≤ 5, single scene `src/main.tscn`, pure `src/core/`, SHA-256 / test immutability lock verified, `bash tests/run.sh` exit 0 with 0 engine errors).
- [ ] `specs/01-state-schema.md` updated with the State Delta from the slice.
- [ ] View slices: manual visual/budget check verified.
- [ ] User tested `"Nyt voin ___"` result.
- [ ] `specs/02-roadmap.md` status updated from `draft`/`in-progress` to `done`.
- [ ] Git commit (`feat(slice-NN): …`) and `git push origin main` via `finish_slice.sh`.

## 2. Automating DoD & Git Commit

Run the lifecycle helper:
```bash
bash .agents/skills/slice-lifecycle/scripts/finish_slice.sh <slice-num> "<commit-message>"
```

What `finish_slice.sh` enforces automatically:
1. Runs `bash .agents/skills/godot-gatekeeper/scripts/check_slice.sh` (all 5 gates, including SHA-256 lock verification).
2. Inspects `git status` and **fails** if untracked/modified files exist outside `src/`, `tests/`, `specs/`, and `config/` (pass `ALLOW_EXTRA_FILES=1` only when intentionally committing files outside those directories).
3. Verifies branch is `main`, stages only `src tests specs config` (or `-A` if `ALLOW_EXTRA_FILES=1`), commits `feat(slice-<NN>): <message>`, pushes to `origin/main`, and clears `.agents/slice_lock.sha256` (`lock_slice.sh --clear`).

Example:
```bash
bash .agents/skills/slice-lifecycle/scripts/finish_slice.sh 05 "add snapshot interpolation for smooth sync"
```
