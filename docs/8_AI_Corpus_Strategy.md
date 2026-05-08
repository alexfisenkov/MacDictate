# AI Corpus Strategy

Этот документ фиксирует, как улучшать вторую нейросеть MacDictate без потери главного требования: исправлять и оформлять диктовку, но не менять смысл.

## Primary Corpus

Главный источник качества для MacDictate — реальные локальные debug-сессии:

- `audio.wav` — что было произнесено;
- `01_whisper_raw.txt` — сырой output Whisper;
- `02_whisper_cleaned.txt` — очищенный text после Whisper;
- `04_qwen_prompt.txt` — prompt второй нейросети;
- `05_qwen_raw_output.txt` — сырой output Qwen;
- `06_qwen_cleaned_output.txt` — cleaned output Qwen;
- `06b_qwen_final_after_formatter.txt` — итог после deterministic formatter;
- `07_final_inserted.txt` — текст, который реально ушел во вставку;
- `events.jsonl` — порядок событий и ошибки.

Для будущего обучения или eval нужны не все debug-сессии подряд, а утвержденные человеком пары:

```json
{"source":"сырой или cleaned Whisper text","target":"правильно исправленный текст","language":"ru","task":"dictation_correction","preserve_meaning":true}
```

## HuggingFace Copywriting Datasets Reviewed

| Dataset | Verified facts | Role in MacDictate |
| --- | --- | --- |
| `jaykin01/advertisement-copy` | HF viewer показывает `1.14k` rows, CSV, поля `product`, `description`, `ad`, license `unknown`. | Не использовать для product fine-tune до license review. Может быть reference для рекламного стиля, но не для базового корректора диктовки. |
| `smangrul/ad-copy-generation` | HF card говорит, что это `jaykin01/advertisement-copy`, переформатированный под Llama V2 chat template; `1,141` rows, `197 kB`. | Удобен технически, но задача — генерация рекламы. Использовать только как secondary style/eval experiment после license review. |
| `PeterBrendan/Ads_Creative_Text_Programmatic` | HF viewer показывает MIT license, `1k` rows, CSV с рекламным текстом и banner dimensions. | Можно рассмотреть для отдельного рекламного style eval, но данные шумные и не являются correction corpus. |
| `RafaM97/marketing_social_media` | HF viewer показывает English JSON, `689` rows, поля `instruction`, `input`, `response`, `503 kB`. | Потенциальный secondary eval для marketing/social copy, но не источник базового поведения корректора. |

## Rule

Не делать первый LoRA/fine-tune на рекламных датасетах. Это будет учить модель переписывать и генерировать, а MacDictate должен в первую очередь:

- сохранять смысл, факты, цифры, имена и бренды;
- исправлять орфографию и пунктуацию;
- оформлять абзацы и списки;
- нормализовать профессиональные термины;
- не добавлять маркетинговые CTA, эмоции и новые обещания.

## Practical Path

1. Включить `MacDictateDebugSessionLoggingEnabled` только на время тестирования.
2. Накопить реальные debug-сессии по коротким, средним и длинным диктовкам.
3. Для каждой проблемной сессии сравнить Whisper, Qwen и final inserted artifacts.
4. Исправлять сначала prompt/profile/formatter, если проблема системная и локальная.
5. Создать ручной approved corpus только из сессий, где человек подтвердил target text.
6. Переходить к LoRA/fine-tune только после появления достаточного correction corpus и eval-набора на смысловую сохранность.

## Open Questions

- Нужен ли user-facing approval UI для пары `raw -> target`, или пока достаточно локального ручного отбора debug-сессий.
- Какой минимальный размер корпуса считать достаточным для первого LoRA experiment: ориентир `100-500` качественных пар, а не тысячи рекламных генераций.
- Нужен ли отдельный marketing mode в будущем. Если да, он должен быть отдельным режимом, а не поведением базовой диктовки.
