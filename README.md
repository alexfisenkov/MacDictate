# MacDictate

В этом репозитории есть не только macOS app, но и весь product surface, от которого зависит лицензирование:

- `src/`, `assets/`, `build.sh` — основной macOS product.
- `backend/` — licensing/payment API и SQLite storage.
- `web-landing/` — публичный лендинг и checkout surface.
- `docs/legal/` — legal-тексты, используемые сайтом.

## Source of truth

- Канон по desktop runtime: `src/AppDelegate.swift`, `src/AppController.swift`, `build.sh`.
- Канон по тарифам и оплате: `backend/plans.js`.
- Контракт `GET /api/license/status` должен оставаться совместимым с текущим macOS app.

## Локальный backend

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
