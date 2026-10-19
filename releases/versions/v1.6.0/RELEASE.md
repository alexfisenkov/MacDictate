# MacDictate v1.6.0

- Status: `local_only`
- Branch: `release/1.6.0`
- macOS bundle: `1.6.0` / build `14`
- Windows app: `1.6.0`, x64, self-contained .NET10

## Scope

Free Windows tray dictation: double Alt to start and finish; configurable alternatives, local Whisper small, language selection, verified model setup, last-text recovery. No Windows LLM correction is claimed. macOS keeps the existing free behavior and notarized distribution.

## Release gates

Not published yet. Require final GitHub checks on exact source SHA, Windows native Server2025 smoke and synthetic ASR, macOS signed/notarized DMG, annotated tag, checksums and public read-back.

## Acceptance limits

Windows10/11 physical microphone/hotkey/paste: NOT_RUN. Hosted Windows runner is Server2025. Windows Authenticode signing is unavailable; binaries are unsigned. Win10 Home/Pro is outside current .NET official OS lifecycle support; technical compatibility target is not physical acceptance.
