# MacDictate v1.6.0

- Status: `public_stable`
- Published: `2026-10-19T13:39:24Z`
- Source/tag: `e80a4a094affb65457c4f3f77e090b84d6aef210` / annotated `v1.6.0`
- Final CI: https://github.com/alexfisenkov/MacDictate/actions/runs/39259656403 — governance/macOS/Windows PASS
- macOS: `1.6.0` / build `14`, Developer ID, Apple notarization Accepted, stapled, Gatekeeper and mounted-install PASS.
- Windows: `1.6.0`, self-contained x64 .NET10.0.13/WinForms, per-user EXE and portable ZIP; unsigned.
- Public release: https://github.com/alexfisenkov/MacDictate/releases/tag/v1.6.0

## User-visible change

Free Windows tray dictation: double left Alt toggles start/finish, alternatives Ctrl+Shift+Space/F8. Verified multilingual Whisper small setup, language auto/ru/en, local CPU recognition, focus-checked Unicode entry without Enter or clipboard overwrite, recoverable last text. No Windows LLM correction is claimed. macOS retains its existing free behavior; DMG naming now derives from bundle version.

## Verification

Windows37portable checks, native input/menu/focus/surrogate/clipboard smoke, actual synthetic speech through the bundled CLI with Cyrillic/emoji model/WAV/TEMP paths, installed-copy smoke and uninstaller PASS. Complete runtime/WinForms/UIAutomation payload and licenses verified. macOS complete Swift compile and9regression harnesses PASS. Exact source SHA matches both platform build manifests. All9uploaded asset digests/sizes read back after atomic draft publication; aliases are byte-identical to versioned files.

## Artifacts

- macOS DMG SHA256: `d2c582541991b83973362cd8e926c651f85b595252b74825cbb2e05f13c3fe18`
- Windows EXE SHA256: `7760c34fb04c2d59887b613a8c71ce3001920a91448d60e9048fa207d2f689c2`
- Windows ZIP SHA256: `4bae36e98ab81a10fe929a05c398aa1d3e23d0aad02112eed3ac76966f6644c7`
- Complete list: `artifacts/SHA256SUMS` and public `windows-build-manifest.json`.

## Limits / next acceptance

Physical microphone, physical Alt and third-party editor path on Windows10/11: NOT_RUN. Hosted runner is Server2025. Windows10 build19041+ compatibility target; ordinary Win10 Home/Pro is outside current .NET10 OS lifecycle support. Windows packages unsigned; SmartScreen/policy may block. CPU-only, no ARM-native Windows build. Existing model with a different hash is preserved; recovery requires manual move/reselect. Hung UIA provider fails closed to manual copy and requires restart. Physical macOS mic/Option/paste remains separate from compile/synthetic proof. Optional macOS Qwen3B model rights remain separate, as documented in public EULA.

## Rollback

Prior v1.5.2 release and local free app backup preserved. No user models, old license data or historical payment records were changed. Legacy server remains off and was not accessed or deployed.
