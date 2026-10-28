# macOS Release Ledger

Эта папка хранит историю версий MacDictate для компьютера.

## Канон

- `registry.json` — машинно-читаемый реестр всех известных desktop-версий.
- `versions/<version>/RELEASE.md` — описание конкретной версии.
- `versions/<version>/artifacts/` — локальные DMG/build logs/checksums. Бинарники в этой папке игнорируются git.
- `archive/` — неканонические тестовые образы и legacy build experiments.

Правила ведения описаны в `../docs/7_Release_Governance.md`.

## Быстрая проверка

```bash
cd macos
scripts/verify_release_governance.sh
```

Для проверки GitHub Releases:

```bash
cd macos
scripts/verify_release_governance.sh --online
```

## Новая версия

Для новой версии сначала создать папку:

```text
releases/versions/vX.Y.Z/
├── RELEASE.md
└── artifacts/
    ├── ARTIFACTS.md
    └── SHA256SUMS
```

Затем обновить `registry.json`, `CHANGELOG.md`, action log и checklist.


Windows-only candidates use `current.windows.publicStable`/`workingLine`; global `current.publicStable` remains the Mac latest channel. Windows1.6.1 is published in `v1.6.1` with status `public_release` and selected by `current.windows.publicStable`; actual public timestamp is2026-10-28T19:07:43Z and asset digest/size read-back4/4 PASS. Final Pages delivery/read-back is pending; `v1.6.1-working` retains source-preparation history. Canonical version/names come from Windows csproj through `release-info.ps1`. Run `python3 windows/scripts/check-delivery.py` alongside the existing root governance checker. Windows-only releases must use `make_latest=false` and version-pinned URLs; see D-025 and `docs/7_Release_Governance.md`.
