# MacDictate

MacDictate — menu bar utility для локальной диктовки на macOS с Whisper.cpp, licensing layer и checkout surface.

## Versioning

- Публичная стабильная база: `v1.5.1`
- Следующая рабочая линия: `release/1.5.2`
- Канон по версиям и артефактам: `docs/7_Release_Governance.md` + `releases/registry.json`
- Обычный `./build.sh` кладет временный DMG в `build/artifacts/`.
- Release DMG/build logs должны переноситься в `releases/versions/<version>/artifacts/` или `releases/archive/`, а не оставаться в корне проекта.

## Product Surfaces

- `src/`, `assets/`, `build.sh` — основной macOS product.
- `backend/` — licensing/payment API и SQLite storage.
- `web-landing/` — публичный лендинг и checkout surface.
- `docs/legal/` — legal-тексты, используемые сайтом.
- `docs/` — инженерный канон, журнал решений, smoke matrix и release discipline.

## Source of truth

- Канон по desktop runtime: `src/AppDelegate.swift`, `src/AppController.swift` и app-side модули в `src/App`, `src/License`, `src/Diagnostics`, `src/Hotkeys`, `src/Transcription`, `src/TextImprovement`, `src/Paste`, `src/UI`, `src/System`, `src/Updates`.
- Канон по росту app-side архитектуры: `docs/10_App_Architecture_Guardrails.md` + `scripts/check_architecture_guardrails.sh`.
- Канон по тарифам и оплате: `backend/plans.js`.
- Главный operating model проекта: `docs/0_Project_Operating_Model.md`.
- Канон по версиям, rollback и release assets: `docs/7_Release_Governance.md`, `releases/registry.json`, `releases/versions/<version>/RELEASE.md`.
- Контракт `GET /api/license/status` должен оставаться совместимым с текущим macOS app.

## Release ledger

Версии desktop-продукта ведутся через `releases/`:

- `releases/registry.json` — машинно-читаемый реестр всех известных версий и checkpoint-ов.
- `releases/versions/v1.5.1/RELEASE.md` — карточка текущей stable.
- `releases/versions/v1.5.1-working/RELEASE.md` — завершенная рабочая линия `1.5.1`.
- `releases/versions/v1.5.2-working/RELEASE.md` — текущая рабочая линия.
- `scripts/verify_release_governance.sh` — проверка, что registry, папки версий, checksums, `Info.plist` и обязательные git tags не расходятся.

Перед выпуском или восстановлением любой старой версии сначала читать `docs/7_Release_Governance.md`.

## Локальный запуск

### App

- Модели живут в `~/.macdictate/models`.
- Первый запуск идет через `src/AppDelegate.swift` и `src/ModelDownloader.swift`.
- Вторая модель Qwen скачивается лениво после включения `Улучшить текст`; runtime для неё (`llama-completion` + `.dylib`) должен быть уже bundled внутри `.app`, без требования ставить Homebrew пользователю.
- Сборка выполняется через `./build.sh`.
- Результат обычной сборки: `build/MacDictate.app` и `build/artifacts/MacDictate_Final_v*.dmg`.
- Для release-candidate перенесите DMG и build log в `releases/versions/<version>/artifacts/`, обновите `SHA256SUMS`, `ARTIFACTS.md` и `releases/registry.json`.

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
- `scripts/check_bundled_llama_runtime.sh build/MacDictate.app` проверяет, что runtime второй нейросети self-contained и не зависит от `/opt/homebrew` / `/usr/local`.
- Больше проектных правил и rollback discipline: `docs/0_Project_Operating_Model.md`.
- Больше правил по версиям, GitHub Releases и локальному складу артефактов: `docs/7_Release_Governance.md`.
