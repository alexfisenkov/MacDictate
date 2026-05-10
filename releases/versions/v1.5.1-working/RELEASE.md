# MacDictate v1.5.1-working

## Status

- Status: `working_line`
- Branch: `release/1.5.1`
- Bundle: `1.5.1` / build `11`
- Public Release: not released

## Summary

Следующая desktop working line после публичного релиза `v1.5.0`.

## Initial Scope

- Собирать новые regression-кейсы по второй нейросети из debug-сессий.
- Дорабатывать качество controlled retry / validation без изменения публичного `v1.5.0`.
- Сохранять release governance и не публиковать новый релиз без отдельного release-cycle.

## Working Changes

- Brand icon standardization: macOS menu bar, app icon source, web landing/legal/payment pages and iOS app/keyboard microphone controls now use the user-provided `mic_logo.svg` / `mic_menubar.svg` family instead of emoji/system mic glyphs where this is product branding.
- Last dictation safety copy: macOS now stores the final non-empty dictation text before paste and exposes `Скопировать последнюю диктовку` in the menu bar for manual recovery if focus/cursor/window changes during processing.
- Dynamic status bar state indicators are restored: idle shows the branded microphone icon, while recording/processing/error states show compact status symbols.

## Release Rule

`v1.5.1` нельзя считать выпущенной, пока не будут выполнены version-specific release notes, registry update, build artifact, annotated tag, GitHub Release и smoke evidence.
