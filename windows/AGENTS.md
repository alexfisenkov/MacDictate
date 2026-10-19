# Windows desktop context

Windows-компонент MacDictate в существующем desktop Git-репозитории (`macos/`).

- Канон: `README.md`, `../docs/superpowers/plans/2026-10-19-windows-1.6.0.md`, `../releases/registry.json`.
- Portable domain/process/storage: `src/MacDictate.Core/`; Win32 services (включая UI Automation identity) и tray UI: `src/MacDictate.Windows/`.
- Проверки: `dotnet run --project tests/MacDictate.Core.Tests/MacDictate.Core.Tests.csproj`; `dotnet build src/MacDictate.Windows/MacDictate.Windows.csproj` из этой папки. Native smoke требует Windows интерактивный desktop.
- Default: двойной левый Alt начинает запись, повторный двойной левый Alt останавливает. Right Alt/AltGr и комбинации не запускают её. Hook всегда передаёт клавиши дальше.
- Без активации/лицензионных запросов. Аудио/текст не уходят по сети и не попадают в логи. Только явная model download по закреплённому SHA, atomic replacement и отмена.
- Не смешивать UI, Win32 interop, model download и Whisper orchestration в один файл; не переносить сюда Swift/iOS код.
- Runtime: `runtime/whisper-cli.exe`; model metadata: `runtime-lock.json`. Не коммитить runtime/models/build output.
- Не называть Windows10/11 physical microphone/hotkey/paste проверенными на основании cross-build или Windows Server CI.
- Автоввод сверяет top-level HWND, native input HWND и UI Automation RuntimeId; неизвестная identity/timeout500мс означает только ручное восстановление.
- Известные ограничения: unsigned Windows distribution, CPU-only ASR, первая Windows-версия без LLM-коррекции; принудительный kill может оставить temp WAV.
- `AGENTS.md` — точная копия этого файла; менять CLAUDE.md, затем копировать и проверять parity.
