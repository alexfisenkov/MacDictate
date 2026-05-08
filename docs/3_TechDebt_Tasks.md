# Технический Долг и Backlog

Этот файл теперь ведется как живой backlog с приоритетом и ожидаемым impact.

| Area | Status | Priority | Impact | Effort | Owner | Item |
| --- | --- | --- | --- | --- | --- | --- |
| Release | Open | P0 | Distribution | M | Project | Перевести release path на Developer ID + notarization + stapling. |
| Release | Open | P0 | Integrity | M | Project | Определить один source of truth для release asset: GitHub release vs site download. |
| Release | Open | P0 | History | S | Project | Нормализовать исторические remote/local tags `v1.2` и `v1.3`: решить, пересоздавать/документировать aliases или оставить как legacy. |
| Release | Open | P1 | Packaging | M | Project | Перед публичным релизом отдельно подтвердить strict verification установленной/смонтированной DMG-копии; `create-dmg`/Finder layout может добавлять Finder metadata на bundle внутри образа, поэтому финальный release path должен быть проверен вместе с Developer ID/notarization. |
| Release | Open | P1 | Integrity | S | Project | Скачать опубликованные GitHub assets для `v1.1`-`v1.4` и заполнить `githubAssetSha256` в `releases/registry.json`. |
| Release | Open | P1 | Hygiene | S | Project | Проверить, нужно ли удалять ранее tracked binary DMG из git history через отдельную history-rewrite policy; текущая cleanup-итерация только убирает их из рабочего дерева вперед. |
| Backend/App | Open | P0 | Revenue / UX | M | Project | Ввести app-side support snapshot и операторски понятный manual license recheck flow. |
| Backend | Open | P1 | Ops | M | Project | Подтвердить parity локального `backend/` с production deploy и задокументировать production ownership. |
| App | Open | P1 | Supportability | M | Project | Добавить repair flow для `no model / no whisper / permission denied`. |
| App | Open | P1 | UX | M | Project | Вынести `launch at login` из AppleScript fallback в более чистый и проверяемый path. |
| App | Open | P1 | Flexibility | M | Project | Сделать настраиваемую горячую клавишу без ломки menu bar utility UX. |
| Repo | Open | P1 | Hygiene | S | Project | Провести отдельную cleanup-итерацию по оставшимся root artifact clutter: icon scratch files и helper scripts. DMG/build logs уже расфасованы в release ledger. |
| App | Open | P2 | Onboarding | L | Project | Уйти от зависимости на Homebrew `whisper-cli` или хотя бы сделать управляемый bundled runtime path. |
| App | Open | P2 | Onboarding | M | Project | Уйти от зависимости на Homebrew `llama.cpp` runtime для второй нейросети или сделать управляемый bundled runtime path. |
| App | Open | P2 | UX | M | Project | После runtime smoke решить, нужен ли progress/cancel flow для долгого улучшения текста. |
| App | Open | P2 | UX | M | Project | Решить, нужен ли chunking для улучшения длинных диктовок; текущая защита fallback-ит input > 6 000 символов к Whisper-тексту. |
| App/AI | Open | P2 | Quality | M | Project | Накопить реальный корпус пар `raw Whisper text -> desired edited text` и на его базе решить, достаточно ли prompt/profile или нужен LoRA/fine-tune. |
| App/AI | Open | P2 | Quality / Legal | S | Project | Провести license review HuggingFace copywriting datasets перед любым training/eval использованием; `jaykin01/advertisement-copy` сейчас имеет unknown license на HF card. |
| App | Open | P2 | Runtime | S | Project | Собрать runtime evidence по экстремально длинным диктовкам и решить, нужен ли user-facing progress/cancel flow. |
| App/AI | Open | P2 | Runtime / UX | S | Project | После тестов Qwen2.5-3B собрать latency/RAM evidence на M1/16 GB и решить, нужен ли user-facing selector между 3B quality mode и 1.5B fast mode. |
| App/Diagnostics | Open | P2 | Privacy / Supportability | S | Project | Для debug-сессий добавить user-facing управление: открыть папку логов, отключить logging, удалить старые session folders и/или задать retention policy. |

## Notes

- Исторические TODO уровня `1.1` не удалены по смыслу: часть из них реализована, часть перенесена в таблицу выше.
- Бесконечное ожидание `whisper-cli` закрыто в `release/1.5.0` через bounded 30-минутный timeout. Оставшийся долг — runtime evidence и UX для экстремально длинных диктовок.
- Cleanup stale `/tmp/mac_dictate_dist.wav` и `.txt` закрыт в `release/1.5.0` через `RecordingService`.
- Text improvement добавлен как optional enhancement: отсутствие Qwen/`llama.cpp` runtime не блокирует диктовку, длинный input > 6 000 символов fallback-ится к Whisper-тексту, preferred-моделью стала Qwen2.5-3B с fallback на 1.5B, а редакторское поведение управляется `TextImprovementProfile`; runtime distribution, long-text chunking, latency/RAM evidence и corpus-based quality tuning остаются отдельными debt items.
- Debug session logging добавлен как локальный opt-in инструмент диагностики качества. Он сохраняет чувствительные аудио/текстовые artifacts только на устройстве; user-facing управление retention/cleanup остается отдельным debt item.
- Каждый крупный спринт должен оставлять след здесь, если появились новые незавершенные риски или остаточные компромиссы.
