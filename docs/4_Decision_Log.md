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
