# Release Governance Foundation Design

## Goal

Навести устойчивый порядок в desktop/macOS-версии MacDictate так, чтобы каждая версия имела понятный статус, место хранения, описание, rollback anchor и связь с GitHub Releases.

## Scope

Входит:

- release governance rules;
- registry of all known macOS desktop versions;
- per-version release folders and descriptions;
- local artifact warehouse for DMG/build logs;
- verification script;
- updates to README, changelog, action log, decision log, release checklist and local agent instructions.

Не входит:

- runtime-code changes;
- release rebuild;
- signing/notarization implementation;
- GitHub release publishing;
- rewriting git history.

## Architecture

`docs/7_Release_Governance.md` defines the rules. `releases/registry.json` is the machine-readable registry. `releases/versions/<version>/RELEASE.md` is the human-readable release passport. `releases/versions/<version>/artifacts/` stores local binary/log artifacts outside git tracking, while GitHub Releases remain the public distribution channel.

## Validation

`scripts/verify_release_governance.sh` validates the local canon: registry JSON, version folders, manifests, checksums, `Info.plist` version/build and required local git tags. `--online` also checks GitHub Releases API for asset presence/digest when available.

## Historical Handling

Ambiguous versions are not hidden. `v1.2` and `v1.3` are marked reconstructed because their remote tags alias `v1.4`. `v1.4.1-local` is local-only. Local `v1.4.2` DMG checksum differs from GitHub asset checksum, so GitHub remains the public source of truth.
