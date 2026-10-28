# Windows v1.6.1

Status: `public_release`

Published [Windows-only v1.6.1](https://github.com/alexfisenkov/MacDictate/releases/tag/v1.6.1) at `2026-10-28T19:07:43Z` (GitHub release ID427078400), with `make_latest=false`. Annotated tag points to exact checked build source `56b45301bc0e98c12f4823e5039152a3c3dd5229`. [Final CI40747430459](https://github.com/alexfisenkov/MacDictate/actions/runs/40747430459): all three jobs PASS. Four actual public asset sizes/digests match the checked local bytes. Global GitHub latest remains Mac v1.6.0; Pages serves16/16 exact HTTPS files; workflow40752369737 completed success on the exact Pages commit.

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

Local package bytes, manifests, checksums and synthetic-only JSON/PNG are retained in `artifacts/`. `artifacts/RELEASE_NOTES.md` is the published GitHub release body. Local Latest-named copies are byte-identical verification copies only; they must not be uploaded or used as the public Windows channel.

## Verified boundary

- Final run on Windows Server 2025: 62 portable checks; exact artifact sourceSHA/bytes/runtime/model pins; native Unicode/surrogate paste, unchanged automatic clipboard, changed-window/input rejection and actual hook registration PASS.
- One real bundled Whisper invocation recognized a synthetic spoken fixture through visible onboarding controls. Actual result and Copy were visible before diagnostic scrolling; clipboard read-back PASS. PCM capture and hotkey activation used explicit test seams. Real WinMM enumeration found no audio input; physical capture was not run.
- Ordinary installed EXE without test CLI passed in an empty runner profile: fresh blank state, visible model action, no implicit download, close-to-tray, same-process reopen. Populated state used synthetic persisted text; actual UIA/ValuePattern/Copy/clipboard passed. This is separate from real-ASR evidence.
- Installer verified all 492 payload files. Synthetic settings/model/last-text sentinels survived reinstall and uninstall byte-for-byte. Existing owner/friend data was not used or changed.
- Synthetic geometry/font scale 125/150% passed result/Copy visibility. Actual desktop DPI was 96; native monitor 125/150% was not tested.

## Limits and retained warning

Physical Windows 10/11 microphone, physical Alt, third-party-editor paste, native monitor DPI, GUI model HTTP-success path, interactive installer wizard and SmartScreen remain NOT_RUN. Packages have no Authenticode signature. Corrupted existing model recovery is manual. The normal installed populated PNG named by JSON was not retained; actual UIA/clipboard checks passed and a separate real-ASR result PNG exists. No additional CI was authorized solely for that missing PNG.

## Publication and remaining delivery

Root published the annotated checked-source tag with `make_latest=false`. The actual public API receipt confirms release ID427078400, timestamp `2026-10-28T19:07:43Z` and all four asset names/bytes/digests: versioned EXE/ZIP, `windows-build-manifest.json` and `WINDOWS-SHA256SUMS`. The generic local `SHA256SUMS` includes local aliases and is not a public asset. The release body is GitHub metadata, not a fifth uploaded asset.

Windows registry stable, `latest-windows.json` and all three HTML installer/portable fallback URLs now pin v1.6.1 from that actual evidence. Root confirmed global GitHub latest remains v1.6.0; Mac bundle1.6.0/build14, legacy current pointers and `latest-desktop.json` remain unchanged. Root published Pages commit `1d4873e628956a8bde3d76bcd07de9cfd66de62a` from source main `e46b25fb8e1c2203609c2ee750176028a61fdca7`; run [40752369737](https://github.com/alexfisenkov/MacDictate/actions/runs/40752369737). Actual HTTPS receipt verifies16/16 files exactly. A complete unauthenticated EXE download verifies54351051 bytes and SHA-256 `fe85fd784649f057d16a115392b3c09cb7ceaf42e8f59beefc05d8149b3307e9`. Root subsequently confirmed workflow40752369737 completed success with exact head `1d4873e628956a8bde3d76bcd07de9cfd66de62a`. Live browser acceptance and a complete ZIP download are not established by these receipts. Physical client acceptance is still limited as recorded above.
