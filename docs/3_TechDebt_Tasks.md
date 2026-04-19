# Технический Долг и Backlog

Этот файл теперь ведется как живой backlog с приоритетом и ожидаемым impact.

| Area | Status | Priority | Impact | Effort | Owner | Item |
| --- | --- | --- | --- | --- | --- | --- |
| Release | Open | P0 | Distribution | M | Project | Перевести release path на Developer ID + notarization + stapling. |
| Release | Open | P0 | Integrity | M | Project | Определить один source of truth для release asset: GitHub release vs site download. |
| Backend/App | Open | P0 | Revenue / UX | M | Project | Ввести app-side support snapshot и операторски понятный manual license recheck flow. |
| Backend | Open | P1 | Ops | M | Project | Подтвердить parity локального `backend/` с production deploy и задокументировать production ownership. |
| App | Open | P1 | Supportability | M | Project | Добавить repair flow для `no model / no whisper / permission denied`. |
| App | Open | P1 | UX | M | Project | Вынести `launch at login` из AppleScript fallback в более чистый и проверяемый path. |
| App | Open | P1 | Flexibility | M | Project | Сделать настраиваемую горячую клавишу без ломки menu bar utility UX. |
| Repo | Open | P1 | Hygiene | S | Project | Провести отдельную cleanup-итерацию по root artifact clutter: legacy DMG, icon scratch files, build logs. |
| App | Open | P2 | Onboarding | L | Project | Уйти от зависимости на Homebrew `whisper-cli` или хотя бы сделать управляемый bundled runtime path. |
| App | Open | P2 | Diagnostics | S | Project | Добавить cleanup `/tmp/mac_dictate*` при старте после аварийных сценариев. |

## Notes

- Исторические TODO уровня `1.1` не удалены по смыслу: часть из них реализована, часть перенесена в таблицу выше.
- Каждый крупный спринт должен оставлять след здесь, если появились новые незавершенные риски или остаточные компромиссы.
