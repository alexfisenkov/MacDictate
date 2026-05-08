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
