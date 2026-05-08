# Release Governance Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a durable release/version management system for MacDictate macOS desktop.

**Architecture:** Keep runtime code unchanged. Add a release ledger under `releases/`, policy docs under `docs/`, local agent instructions, and a verification script that prevents future release drift.

**Tech Stack:** Markdown, JSON, Bash, Python 3, git, GitHub Releases API.

---

### Task 1: Create Release Ledger

**Files:**
- Create: `releases/README.md`
- Create: `releases/registry.json`
- Create: `releases/versions/*/RELEASE.md`
- Create: `releases/versions/*/artifacts/ARTIFACTS.md`
- Create: `releases/versions/*/artifacts/SHA256SUMS`

- [x] Create per-version folders for `v1.0`, `v1.1`, `v1.2`, `v1.3`, `v1.4`, `v1.4.1-local`, `v1.4.2`, `v1.5.0-working`.
- [x] Move local DMG/build logs into version/archive artifact folders.
- [x] Record artifact checksums and source confidence.

### Task 2: Add Governance Policy

**Files:**
- Create: `docs/7_Release_Governance.md`
- Modify: `docs/0_Project_Operating_Model.md`
- Modify: `docs/4_Decision_Log.md`
- Modify: `docs/6_Release_Checklist.md`

- [x] Define release statuses.
- [x] Define branch/tag/checkpoint model.
- [x] Define rollback procedure.
- [x] Define GitHub Release and local artifact rules.

### Task 3: Add Verification

**Files:**
- Create: `scripts/verify_release_governance.sh`
- Create: `scripts/README.md`
- Modify: `.gitignore`

- [x] Validate registry JSON and per-version folders.
- [x] Validate artifact checksums.
- [x] Validate `Info.plist` current stable version/build.
- [x] Validate required local tags.
- [x] Add optional online GitHub Release check.

### Task 4: Update Project Memory

**Files:**
- Create: `CLAUDE.md`
- Create: `AGENTS.md`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/2_ActionLog.md`
- Modify: `docs/3_TechDebt_Tasks.md`

- [x] Document new source of truth.
- [x] Preserve historical caveats.
- [x] Record unresolved release debt.

### Task 5: Verify

**Commands:**

```bash
cd /Users/AlexFisenkov_1/Documents/MacDictate/macos
scripts/verify_release_governance.sh
python3 -m json.tool releases/registry.json >/tmp/macdictate-release-registry.json
cmp -s CLAUDE.md AGENTS.md
git status --short
```

- [x] Run local verification.
- [x] Report any unverified GitHub/history items as explicit debt.

### Task 6: Newcomer Audit Fixes

**Files:**
- Modify: `build.sh`
- Modify: `README.md`
- Modify: `CLAUDE.md`
- Modify: `AGENTS.md`
- Modify: `docs/7_Release_Governance.md`
- Modify: `scripts/verify_release_governance.sh`

- [x] Audit the project from root README/CLAUDE and macOS README/CLAUDE entry points.
- [x] Fix the contradiction where governance forbade root DMG files while `build.sh` still wrote DMG to the root.
- [x] Make `build.sh` output transient DMG files to `build/artifacts/`.
- [x] Avoid unnecessary Homebrew auto-update when `create-dmg` is already installed.
- [x] Harden bundle metadata cleanup before `codesign`.
- [x] Extend release governance verification to fail on root DMG/build-log clutter and root-DMG build script output.
