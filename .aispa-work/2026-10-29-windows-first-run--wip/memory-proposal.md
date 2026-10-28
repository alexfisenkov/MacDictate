# Memory proposal — Windows first run

- Start with `windows/README.md` for the installed first-run flow; use `windows/CLAUDE.md` for ownership, safety boundaries, and native-runtime limits.
- The documented first launch is explicit model download, then microphone selection/test, then a manual in-window recording and Copy check; Windows desktop apps do not normally get a separate microphone permission prompt.
- Model readiness is persisted after integrity-checked download; no Save action is needed. A model with a different pinned hash is not silently replaced.
- Global dictation is double-left-Alt; use the ordinary window and Copy as the first acceptance path. Auto-insertion is guarded by foreground/native/UI Automation identity, and unknown identity or timeout leaves text available for manual copy.
- Delivery has independent Windows stable and working channels: public Windows remains 1.6.0 until release; 1.6.1 is the candidate. Never move the global Mac latest pointer for a Windows-only release.
- Useful root checks: `windows/scripts/check-local.sh`; `python3 windows/scripts/check-delivery.py`; `python3 windows/scripts/test-delivery-encoding.py`; `python3 windows/tests/check-landing-fallback.py`; `pwsh -NoProfile -File windows/tests/test-installed-ui-contract.ps1` (synthetic contract cases, not native Windows proof).
- On Darwin, a clean checkout may lack `dotnet` on PATH: the local check needs .NET SDK 10.0.402 via the repo-local SDK or PATH. A cross-build does not verify physical Windows microphone, Alt key, paste, or native DPI behavior.
- No app-specific environment variable names were found in the inspected Windows code/scripts. Scripts use the standard `RUNNER_TEMP`, `TEMP`, and `TMP` names; do not copy machine-specific values into notes.

## Plain-session progress pointer

For follow-up work, point the session at `.aispa-work/2026-10-29-windows-first-run--wip/interfaces.md` and the current `windows/README.md`; keep the implementation trail in the WIP run folder. Record each checkpoint with `status`, `source commit`, `command or CI run`, `observed result`, and `remaining physical-Windows evidence`. Mark CI and synthetic seams as such; they do not establish physical-device acceptance.
