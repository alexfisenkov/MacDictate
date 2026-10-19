# Бесплатный desktop — план выпуска

> Исполнение: основной агент и независимые workers/reviewers; согласовано текущим запросом владельца.

**Цель:** бесплатный macOS MacDictate у владельца и для всех пользователей.
**Архитектура:** удалить billing из app; оставить legacy HTTP schema без DB-перезаписи; закрыть новые оплаты, сохранить callbacks прошлых заказов.
**Стек:** Swift/AppKit, whisper.cpp, Node/Express/SQLite, статический landing, Developer ID/notarytool.
**Спецификация:** D-021 в `docs/4_Decision_Log.md` и прямое подтверждение владельца о выпуске для всех.

## Ограничения и проверки

- [x] Удалить license lifecycle, gate, оплату и machine ID из компилируемого app.
- [x] Сохранить разрешения микрофона/Accessibility, модели и горячие клавиши.
- [x] Проверить реальное меню, diagnostic logger и установленный Whisper на synthetic speech.
- [x] Установить локальную бесплатную сборку с резервной копией.
- [x] Отключить новые платежи; интеграционный HTTP-тест проверяет отсутствие новых orders/devices.
- [ ] Проверить free landing, RU/EN legal и ссылки, desktop/mobile rendering.
- [ ] Зафиксировать цельный источник в GitHub и собрать build13 из точного SHA main.
- [ ] Нотарифицировать DMG в Apple, staple, проверить подпись и смонтированную установку.
- [ ] Опубликовать GitHub asset и одинаковые байты на сайте; сверить manifest и SHA.
- [ ] Перезапустить backend из GitHub SHA, проверить free access и HTTP410 без изменений прежних заказов.

Риски проверки: старый expired cache; outage license API; прямой старый payment URL; дубликат bundle ID у iOS-wrapper; смешение runtime libs. Они покрываются source guard, HTTP harness, exact-path/hash install read-back и artifact checks.

Открыто: сервер сайта предъявляет изменившийся SSH-ключ и TLS internal error с двух независимых сетей; требуется установить доверенную идентичность хоста до deployment. Live mic/hotkey/paste не проверены из-за timeout native UI runtime.
