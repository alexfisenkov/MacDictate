# MacDictate v1.5.0-working

## Status

- Status: `working_line`
- Branch: `release/1.5.0`
- Current HEAD at registry creation: `9c138a794135e564d49ac2f03d179bf75ae5e974`
- Bundle remains: `1.4.2` / build `9`
- Public Release: not released

## Summary

Активная линия разработки для следующего desktop-релиза. Она уже включает backend checkout hardening, license state machine, bounded offline grace, runtime diagnostics, app-layer modularization и release governance foundation.

## Current Working-Line Hardening

- Release ledger/govеrnance введен как обязательный pre-release контур, но `v1.5.0-working` не имеет release asset.
- `WhisperRunner` получил bounded timeout для зависшего `whisper-cli`; сценарий покрыт локальным harness `scripts/test_whisper_runner_timeout.sh`.
- Локальные DMG/build logs остаются ignored artifacts; clean checkout проверка governance допускает их отсутствие, строгая локальная проверка доступна через `scripts/verify_release_governance.sh --strict-local-artifacts`.

## Release Rule

`v1.5.0` нельзя считать выпущенной, пока не будут выполнены:

- version bump в `assets/Info.plist`;
- обновление `CHANGELOG.md`;
- обновление `releases/registry.json`;
- заполнение финального `releases/versions/v1.5.0/RELEASE.md`;
- прохождение `scripts/verify_release_governance.sh`;
- сборка `./build.sh`;
- smoke matrix;
- annotated tag `v1.5.0`;
- GitHub Release с DMG asset.
