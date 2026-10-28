# 02 — Понятное скачивание и проверенная доставка Windows

**Требования:** R01, R02, R05, R07, R09i
**Зависит от:** 01
**Зона:** `web-landing` · `windows/README.md` · `windows/scripts (кроме check-local.sh)` · `.github/workflows` · `releases` · `docs` · `windows/src/MacDictate.Windows/MacDictate.Windows.csproj`
**Волна:** 2
**Ревью:** нет
**Модель:** сильная

## Что должно заработать
Windows EXE становится очевидным рекомендуемым скачиванием, ZIP объяснён отдельно, шаги после установки совпадают с новым UI. Fresh-profile приёмка запускает настоящий Windows UI и реальное распознавание с честно названным источником аудио; установщик и повторный запуск проверены. Подготовлен Windows-only1.6.1, не вызывающий ложного обновления Mac.

## Из брифа, дословно
> «Кнопки по скачиванию не очевидны»
> «никаких инструкций что куда нажать?»
> «Доводи до конца!»

## Разделы спецификации
Истории R01/R02/R05/R07/R09i, включая производные; решения Windows-only версии, противоречивые hardware proofs запрещены.

## Критерии приёмки
- [ ] На Windows-primary карточке явно написаны EXE/установщик/Windows10/11 x64; ZIP вторичный; RU/EN/мобильная вёрстка и legal links сохранены; шаги model/mic/Alt соответствуют актуальному UI.
- [ ] Installer запускает видимый первый экран; поддерживает русский язык и честную unsigned trust инструкцию; upgrade/settings/models сохранены.
- [ ] Один общий ручной final workflow имеет свежий профиль UI onboarding acceptance, actual ASR и installed-copy checks; тесты не подменяют hardware proof и не публикуют пользовательское аудио. Добавлены проверки required payload/sourceSHA/hash, диагностический safe report.
- [ ] Версия Windows1.6.1 централизована для build/installer/CI asset naming без изменения macOS1.6.0/build14; ledger и отдельный Windows manifest/пин на Windows-only tag согласованы. Старые артефакты не перезаписаны. Mac latest не смещается (make_latest=false).
- [ ] Docs/checklist/debt содержат реальные команды и честные результаты; публикация/gh-pages не выполняется исполнителем, готовится конкретный проверяемый комплект для основного агента.
