# MacDictate v1.5.1

## Status

- Status: `public_stable`
- Bundle: `1.5.1` / build `11`
- Git tag: `v1.5.1`
- Git commit: recorded in `releases/registry.json` after tag creation
- GitHub Release: `https://github.com/alexfisenkov/MacDictate/releases/tag/v1.5.1`

## Summary

Публичный desktop-релиз `1.5.1`. Главная цель версии — зафиксировать первую полноценную Developer ID signed/notarized ветку после `v1.5.0`, сохранить новый брендовый icon system и закрыть permission regression вокруг микрофона на hardened runtime сборках.

## Highlights

- macOS menu bar, app icon, web surface и iOS microphone visuals приведены к единой брендовой иконке вместо emoji/system glyphs.
- Добавлен recovery action `Скопировать последнюю диктовку`: финальный текст сохраняется локально до paste и может быть восстановлен из menu bar, если активное окно/курсор изменились.
- В status bar возвращена динамическая индикация: branded microphone icon в idle, compact status symbols для записи, обработки и ошибок.
- Release pipeline переведен на `Developer ID Application: Aleksander Fisenkov (5BABN9U6WS)`, hardened runtime, timestamp, notarization и stapled DMG.
- Добавлен `assets/MacDictate.entitlements` с `com.apple.security.device.audio-input`, чтобы macOS корректно показывала MacDictate в `Privacy & Security -> Microphone`.
- `scripts/check_distribution_signing.sh` теперь валидирует microphone entitlement, Developer ID identity, notary profile и Gatekeeper acceptance.

## Verification

- `plutil -lint assets/Info.plist assets/MacDictate.entitlements`
- `bash -n build.sh scripts/check_distribution_signing.sh`
- `MACDICTATE_SIGN_IDENTITY="Developer ID Application: Aleksander Fisenkov (5BABN9U6WS)" MACDICTATE_NOTARY_PROFILE="macdictate-notary" MACDICTATE_NOTARIZE=true ./build.sh`
- `codesign --verify --deep --strict /Applications/MacDictate.app`
- `codesign -d --entitlements :- /Applications/MacDictate.app`
- `spctl -a -vv --type execute /Applications/MacDictate.app`
- `scripts/check_distribution_signing.sh /Applications/MacDictate.app`
- `hdiutil verify build/artifacts/MacDictate_Final_v1.5.1.dmg`
- `xcrun stapler validate build/artifacts/MacDictate_Final_v1.5.1.dmg`
- `spctl -a -vv -t open --context context:primary-signature build/artifacts/MacDictate_Final_v1.5.1.dmg`

## Known Limitations

- Whisper and llama.cpp runtimes are still expected from Homebrew paths.
- Text improvement remains optional and bounded: input over `6_000` characters falls back instead of chunking.
- Full desktop dictation history is still future work; `v1.5.1` includes only last-dictation recovery.
- The first transition from older ad-hoc builds to Developer ID may still require a one-time Accessibility/Microphone re-approval, but subsequent Developer ID updates should preserve trust identity.
