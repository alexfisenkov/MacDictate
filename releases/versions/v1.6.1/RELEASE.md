# Windows v1.6.1

Status: `local_only`

Prepared Windows-only release candidate, not a published release. Exact build source: `56b45301bc0e98c12f4823e5039152a3c3dd5229`. [Final CI 40747430459](https://github.com/alexfisenkov/MacDictate/actions/runs/40747430459): governance, macOS and Windows jobs all PASS. Annotated tag, GitHub publication and Pages delivery are pending.

## Changes

- Main window guides model → microphone → recording → recognition → result/Copy in Russian and English, with visible readiness and recovery actions.
- Model download checks pinned size/SHA and saves model/settings automatically. Existing usable models remain reusable; an existing different-hash file requires manual move/reselection rather than silent replacement.
- Microphone selection/test/privacy guidance explains why a desktop program may show no separate Windows permission prompt. Recording is available by button or double left Alt; repeated double left Alt stops. Right Alt/AltGr and combinations do not start recording.
- Last text survives reopening and remains available for manual copying if automatic insertion is unsafe. Closing the window leaves the tray app running; the tray/menu or second launch reopens it.
- EXE is the primary download; ZIP is the portable alternative. Both are self-contained x64 and unsigned.

## Exact artifacts

| File | Bytes | SHA-256 |
|---|---:|---|
| `MacDictate_Windows_v1.6.1_x64.exe` | 54351051 | `fe85fd784649f057d16a115392b3c09cb7ceaf42e8f59beefc05d8149b3307e9` |
| `MacDictate_Windows_v1.6.1_x64.zip` | 77339968 | `55eedeed0bda8e91dc807cab00fefc9041e5c3d1151984508107e1e287c6365d` |

Local package bytes, manifests, checksums and synthetic-only JSON/PNG are retained in `artifacts/`. `artifacts/RELEASE_NOTES.md` is ready for the Windows-only GitHub release. Local Latest-named copies are byte-identical verification copies only; they must not be uploaded or used as the public Windows channel.

## Verified boundary

- Final run on Windows Server 2025: 62 portable checks; exact artifact sourceSHA/bytes/runtime/model pins; native Unicode/surrogate paste, unchanged automatic clipboard, changed-window/input rejection and actual hook registration PASS.
- One real bundled Whisper invocation recognized a synthetic spoken fixture through visible onboarding controls. Actual result and Copy were visible before diagnostic scrolling; clipboard read-back PASS. PCM capture and hotkey activation used explicit test seams. Real WinMM enumeration found no audio input; physical capture was not run.
- Ordinary installed EXE without test CLI passed in an empty runner profile: fresh blank state, visible model action, no implicit download, close-to-tray, same-process reopen. Populated state used synthetic persisted text; actual UIA/ValuePattern/Copy/clipboard passed. This is separate from real-ASR evidence.
- Installer verified all 492 payload files. Synthetic settings/model/last-text sentinels survived reinstall and uninstall byte-for-byte. Existing owner/friend data was not used or changed.
- Synthetic geometry/font scale 125/150% passed result/Copy visibility. Actual desktop DPI was 96; native monitor 125/150% was not tested.

## Limits and retained warning

Physical Windows 10/11 microphone, physical Alt, third-party-editor paste, native monitor DPI, GUI model HTTP-success path, interactive installer wizard and SmartScreen remain NOT_RUN. Packages have no Authenticode signature. Corrupted existing model recovery is manual. The normal installed populated PNG named by JSON was not retained; actual UIA/clipboard checks passed and a separate real-ASR result PNG exists. No additional CI was authorized solely for that missing PNG.

## Pending publication

Follow D-025 and `docs/7_Release_Governance.md`: use an annotated `v1.6.1` tag on the checked source above and `make_latest=false`. Publish only the two versioned packages, `windows-build-manifest.json`, `WINDOWS-SHA256SUMS` and release notes. Read back actual published timestamp/source/asset digests before changing Windows stable, manifest or HTML fallback URLs. Global GitHub latest, Mac `v1.6.0`/build 14 and `latest-desktop.json` remain unchanged. Public delivery, live Pages/link/HTTP read-back and physical client acceptance are not completed by this local preparation.
