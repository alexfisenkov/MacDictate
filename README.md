# MacDictate

MacDictate — menu bar utility для локальной диктовки на macOS с Whisper.cpp, licensing layer и checkout surface.

## Versioning

- Публичная стабильная база: `v1.4.2`
- Рабочая линия: `release/1.5.0`

## Product Surfaces

- `src/`, `assets/`, `build.sh` — основной macOS product.
- `backend/` — licensing/payment API и SQLite storage.
- `web-landing/` — публичный лендинг и checkout surface.
- `docs/legal/` — legal-тексты, используемые сайтом.
- `docs/` — инженерный канон, журнал решений, smoke matrix и release discipline.

## Source of truth

- Канон по desktop runtime: `src/AppDelegate.swift`, `src/AppController.swift` и новые app-side модули в `src/License`, `src/Diagnostics`, `src/Hotkeys`, `src/Transcription`, `src/Paste`, `src/UI`.
- Канон по тарифам и оплате: `backend/plans.js`.
- Главный operating model проекта: `docs/0_Project_Operating_Model.md`.
- Контракт `GET /api/license/status` должен оставаться совместимым с текущим macOS app.

## Локальный запуск

### App

- Модели живут в `~/.macdictate/models`.
- Первый запуск идет через `src/AppDelegate.swift` и `src/ModelDownloader.swift`.
- Сборка выполняется через `./build.sh`.

### Backend

1. Перейдите в `backend/`.
2. Скопируйте `backend/.env.example` в `backend/.env`.
3. Заполните переменные окружения для платежей.
4. Установите зависимости: `npm install`.
5. Запустите API: `npm start`.

Минимально используемые env:

- `PORT`
- `DB_PATH`
- `TINKOFF_TERMINAL_KEY`
- `TINKOFF_PASSWORD`
- `ALLOWED_ORIGINS`
- `OUTBOUND_PROXY_URL`
- `PUBLIC_BASE_URL`

## Runtime notes

- `backend/plans.js` — единственный источник истины по `planId`, цене и сроку лицензии.
- `web-landing/index.html` должен отправлять в checkout только `deviceId`, `email`, `planId`.
- `GET /api/license/status` используется текущим macOS app и не должен ломаться при backend-изменениях.
- Больше проектных правил и rollback discipline: `docs/0_Project_Operating_Model.md`.
