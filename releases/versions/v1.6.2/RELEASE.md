# Windows v1.6.2

Status: `local_only`

Checked source `3ce00dc83a149eba60ea1413cf60fd91efd2762f`; [final CI](https://github.com/alexfisenkov/MacDictate/actions/runs/41384129041)3/3 PASS on first attempt. Actual downloaded package digests, all smoke JSON and all referenced PNG files verified. Publication pending; Windows stable remains1.6.1 and global/Mac latest1.6.0.

## Changes and scope

- Offline, modeless setup help with automatic Windows-version suggestion, manual Windows10/11 selector and RU/EN text.
- Exact permission/sound paths, desktop-app switches, manual Win+I fallback, return/retest and signal criteria, first record/Copy, double-left-Alt alternatives and tray recovery.
- Discoverable detailed guide on landing and Windows README. No new dependencies or recording policy changes.
- Zones: Windows MainForm/help/explicit smoke; landing; version ledger/checklists and normal installed screenshot retention. Unrelated main licensing research preserved.

## Exact checked artifacts

| File | Bytes | SHA256 |
|---|---:|---|
| MacDictate_Windows_v1.6.2_x64.exe | 54367459 | `bb23e61ece6acefcdd63b893ab4faccf670077c8f0f336a23e61aca66f88ea54` |
| MacDictate_Windows_v1.6.2_x64.zip | 77353465 | `0c0bdd20bd96468480a654ecef4993f3ed012ace248f90e4de8c1ad37369b7e8` |

## Verified

60portable checks and cross-build0warnings0errors locally;62portable checks on Windows. New help Windows10/11×RU/EN, settings callback failure recovery and both main/help synthetic125/150% layout passed. Real bundled Whisper recognized synthetic speech; result/Copy/clipboard and native hook/paste guards passed. Normal installed fresh/populated UI and492payload files, reinstall/uninstall synthetic sentinel preservation passed. All73artifact files downloaded; every referenced screenshot exists including formerly missing populated installed screenshot. Root read smoke JSON and inspected real help screenshots.

Website RU/EN at390/1440px, keyboard-operable OS sections, no horizontal overflow, no-JS/CDN-blocked fallback, exact button labels, inline-JS syntax and pinned installer fallback tests passed. Primary Microsoft microphone/desktop privacy documentation checked live.

## Limits and remaining acceptance

CI host is Windows Server2025 atactualDPI96. Physical Windows10/11 microphone, actual Alt and third-party editor, native125/150% monitor and interactive SmartScreen remain NOT_RUN. Tests do not change runner privacy settings: the links are routed to a controlled callback, not actual Settings navigation. Real settings paths were verified against Microsoft guidance. Windows package remains unsigned. Model GUI HTTP success and manual recovery for an existing different-hash model retain prior limits.

## Delivery

Next: publish four exact Windows assets with make_latest=false, promote Windows manifest/pinned links, one final Pages publication and HTTPS/download read-back. Do not claim complete delivery from this preparation entry.
