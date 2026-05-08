# Decision Log

## D-001 — Working line goes to 1.5.0, not 1.4.3

- **Дата:** 2026-04-19
- **Решение:** Продолжать линию как `release/1.5.0`.
- **Почему:** изменения уже затрагивают не один bugfix, а product surface целиком: app licensing, backend checkout, docs/governance и архитектуру app-layer.

## D-002 — Backend / web / legal are part of the product surface

- **Дата:** 2026-04-19
- **Решение:** считать `backend/`, `web-landing/`, `docs/legal/` частью канона продукта, а не внешними случайными папками.
- **Почему:** desktop app зависит от live `/api/license/status`, checkout и legal copy; их нельзя больше рассматривать отдельно от продукта.

## D-003 — App layer is modularized around responsibilities

- **Дата:** 2026-04-19
- **Решение:** `AppController.swift` становится thin composition root, а license/diagnostics/hotkeys/transcription/paste/UI выделяются в отдельные файлы.
- **Почему:** giant hotspot уже начал смешивать несвязанные обязанности и мешал безопасным изменениям.

## D-004 — Rollback discipline is tag-based

- **Дата:** 2026-04-19
- **Решение:** перед рискованными этапами ставить annotated checkpoint tags.
- **Почему:** локальная рабочая линия может быть грязной и многослойной; tag дает быстрый rollback anchor без лишней веточной акробатики.

## D-005 — Secrets live only in env / secret storage

- **Дата:** 2026-04-19
- **Решение:** hardcoded secrets и proxy credentials запрещены.
- **Почему:** payment/licensing слой уже production-sensitive; секреты в коде ломают безопасность и дисциплину деплоя.

## D-006 — Offline grace is bounded, not infinite fail-open

- **Дата:** 2026-04-19
- **Решение:** app-side fallback работает через bounded cached grace.
- **Почему:** нужен компромисс между UX при кратковременном outage и защитой от бесконечного бесплатного доступа при сетевых ошибках.

## D-007 — Desktop releases are governed by a release ledger

- **Дата:** 2026-05-08
- **Решение:** все desktop-версии MacDictate ведутся через `docs/7_Release_Governance.md`, `releases/registry.json` и `releases/versions/<version>/RELEASE.md`.
- **Почему:** исторические DMG, tags и GitHub Releases уже расходились; будущим агентам нужен единый канон, а не реконструкция по случайным файлам.

## D-008 — Binary artifacts are local/archive assets, not code source of truth

- **Дата:** 2026-05-08
- **Решение:** локальные DMG/build logs хранятся в `releases/versions/*/artifacts/` или `releases/archive/*/artifacts/`, игнорируются git и описываются через манифест/checksum.
- **Почему:** Git source должен оставаться управляемым, а публичным каналом распространения DMG является GitHub Release asset.

## D-009 — Historical version uncertainty is explicit

- **Дата:** 2026-05-08
- **Решение:** `v1.2`, `v1.3`, `v1.4.1-local` и локальный `v1.4.2` DMG помечаются с уровнем доверия и оговорками в registry/RELEASE.md.
- **Почему:** лучше честно показать reconstructed/local-only историю, чем выдавать непроверенные артефакты за полноценный канон.

## D-010 — Release structure is locked by policy and verification

- **Дата:** 2026-05-08
- **Решение:** новые desktop-версии запрещено вести вне схемы `releases/versions/<version>/` + одноименная запись в `releases/registry.json`; нарушение считается блокирующим состоянием проекта.
- **Почему:** текстовых правил недостаточно для длинной истории релизов. Структура должна быть машинно проверяемой, чтобы будущие люди и агенты не создавали параллельные каталоги, локальные "релизы" и неучтенные артефакты.

## D-011 — Release governance check runs in GitHub Actions

- **Дата:** 2026-05-08
- **Решение:** `.github/workflows/release-governance.yml` запускает `scripts/verify_release_governance.sh` на push/PR в основные рабочие ветки.
- **Почему:** локальная дисциплина полезна, но запрет на нарушение структуры должен быть виден и на GitHub, чтобы pull request не проходил без актуального release ledger.

## D-012 — Text improvement uses optional Qwen GGUF via llama.cpp

- **Дата:** 2026-05-08
- **Решение:** вторую локальную нейросеть для коррекции текста строим как optional layer: `Qwen2.5-1.5B-Instruct-GGUF` quantization `Q4_K_M` запускается через `llama.cpp` runtime (`llama-completion` в актуальном Homebrew), а модель хранится отдельным `.gguf` файлом `qwen2.5-1.5b-instruct-q4_k_m.gguf`. Для первого внедрения Qwen получает только input до `6_000` символов; длинные тексты fallback-ятся к cleaned Whisper text без попытки генерации.
- **Почему:** Qwen2.5-1.5B достаточно легкий для M1/16 GB, официально мультиязычный, поддерживает instruct-following и structured output, а GGUF/llama.cpp повторяет уже принятый в MacDictate паттерн внешнего локального CLI-процесса. 7B/8B варианты дают лучшее качество, но увеличивают cold-start, RAM/disk footprint и риск UX-регрессии для фоновой диктовки.
- **Источники:** `https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF`, `https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct`, `https://www.mintlify.com/ggml-org/llama.cpp/installation`.
- **Ограничение:** отсутствие Qwen/`llama.cpp` runtime не блокирует базовую диктовку. При failure automatic text improvement должен fallback-ить к cleaned Whisper text.

## D-013 — Qwen quality is guided by an editor profile before fine-tuning

- **Дата:** 2026-05-08
- **Решение:** улучшение качества второй нейросети сначала делается через `TextImprovementProfile.professionalCopyEditor`: prompt rules, terminology packs и speech-normalization hints. Настоящий LoRA/fine-tune откладывается до появления реального корпуса пар `raw Whisper text -> desired edited text`.
- **Почему:** GGUF-модель внутри app не дообучается напрямую. Prompt/profile слой быстрее, локальнее, проверяемее и безопаснее для смысла текста. Fine-tune без корпуса пользовательских диктовок будет дороже, медленнее и менее контролируем.
- **Ограничение:** терминологические пакеты не являются исчерпывающей энциклопедией. Они задают канонические написания и контекстные подсказки; новые термины должны добавляться по мере реальных ошибок.

## D-014 — Copywriting datasets are secondary quality material, not the main correction corpus

- **Дата:** 2026-05-08
- **Решение:** рекламные/copywriting датасеты HuggingFace (`jaykin01/advertisement-copy`, `smangrul/ad-copy-generation`, `PeterBrendan/Ads_Creative_Text_Programmatic`, `RafaM97/marketing_social_media`) не используются как прямой первый fine-tune для MacDictate text improvement. Основной корпус должен собираться из реальных debug-сессий диктовки и утвержденных пар `raw Whisper text -> desired corrected text`.
- **Почему:** задача MacDictate — исправлять диктовку, оформлять абзацы/списки и сохранять смысл. Датасеты рекламной генерации учат модель писать продающий copy и могут усилить нежелательное переписывание, добавление фактов, CTA и маркетингового тона.
- **Как использовать:** после license review и фильтрации эти датасеты можно применять как вторичный материал для style/eval наборов или отдельных экспериментов, но не смешивать с базовым корректором без контрольных тестов на смысловую сохранность.
- **Источники:** `https://huggingface.co/datasets/jaykin01/advertisement-copy`, `https://huggingface.co/datasets/smangrul/ad-copy-generation`, `https://huggingface.co/datasets/PeterBrendan/Ads_Creative_Text_Programmatic`, `https://huggingface.co/datasets/RafaM97/marketing_social_media`.
