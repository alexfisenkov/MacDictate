# MacDictate v1.0

## Status

- Status: `local_only`
- Bundle: `1.0` / build `1`
- Git commit: `b402420467e4a3a06fe9b081e2c3c868371258fc`
- Git tag: отсутствует
- GitHub Release: отсутствует

## Summary

Первая native Swift/AppKit desktop-сборка MacDictate. По git commit message: Native Swift Core, Local Whisper Homebrew, Auto-Permissions & Uninstaller.

## Known Scope

- `src/AppController.swift`, `src/AppDelegate.swift`, `src/ModelDownloader.swift`, `src/main.swift`;
- `assets/Info.plist`, `assets/AppIcon.icns`, `assets/dmg_background.png`;
- `build.sh`;
- первые docs: architecture/action log/tech debt.

## Artifacts

Локальный DMG и build log лежат в `artifacts/`. Бинарник игнорируется git; checksum фиксируется в `artifacts/SHA256SUMS` и `releases/registry.json`.

## Notes

Это локальная историческая база, а не публичный GitHub Release. Для rollback по коду использовать commit `b402420`, для пользовательского скачивания не использовать.
