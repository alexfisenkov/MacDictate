# Release Governance macOS

Этот документ задает канон ведения версий MacDictate для компьютера. Он обязателен для будущих людей и агентов, работающих в `macos/`.

## Источники истины

| Уровень | Канон | Назначение |
| --- | --- | --- |
| Правила | `docs/7_Release_Governance.md` | Как создаются версии, теги, GitHub Releases, локальные артефакты и rollback. |
| Реестр | `releases/registry.json` | Машинно-читаемый список всех известных desktop-версий и checkpoint-ов. |
| Описание версии | `releases/versions/<version>/RELEASE.md` | Человеческое описание конкретной версии, статус, отличия, артефакты, риски. |
| Артефакты | `releases/versions/<version>/artifacts/` | Локальные DMG/build logs/checksums. Бинарники не являются source of truth для кода. |
| Runtime | `src/`, `assets/`, `build.sh` | Исходники desktop-приложения. |
| GitHub | Git tags + GitHub Releases | Публичная история релизов и публичные DMG assets. |
| Public download channel | `web-landing/downloads/latest-desktop.json` + GitHub stable asset alias (D-022) | GitHub alias должен отдавать тот же DMG, что и `public_stable`; старый website mirror относится только к legacy server channel. |

Если источники расходятся, порядок приоритета такой:

1. `releases/registry.json`;
2. `releases/versions/<version>/RELEASE.md`;
3. Git tag / commit;
4. GitHub Release;
5. локальный DMG/build log.

Локальный DMG без записи в registry считается не релизом, а неучтенным артефактом.

## Статусы версий

| Статус | Что означает | Пример |
| --- | --- | --- |
| `public_stable` | Последняя публичная стабильная версия для пользователей. | `v1.4.2` |
| `public_release` | Публичный GitHub Release, но не текущая stable. | `v1.1`, `v1.2`, `v1.3`, `v1.4` |
| `local_only` | Локальная сборка/артефакт без публичного GitHub Release. | `v1.0`, `v1.4.1-local` |
| `working_line` | Активная линия разработки без release asset. | `v1.5.0-working` |
| `checkpoint` | Rollback anchor внутри рабочей линии. | `checkpoint/1.5.0-sprint2` |
| `scratch` | Тестовый или промежуточный артефакт, не версия продукта. | `rw.*.dmg`, `test.dmg` |

## Каталог версий

Каждая версия обязана иметь папку:

```text
releases/versions/<version>/
├── RELEASE.md
└── artifacts/
    ├── ARTIFACTS.md
    ├── SHA256SUMS
    ├── MacDictate_*.dmg        # локально, игнорируется git
    └── build_log*.txt          # локально, игнорируется git
```

Правило именования:

- публичные версии: `v1.4.2`;
- локальные промежуточные версии: `v1.4.1-local`;
- рабочая линия: `v1.5.0-working`;
- scratch-артефакты: `releases/archive/<bucket>/artifacts/`.

Жесткое правило: папка `releases/versions/<version>/` без записи в `releases/registry.json` запрещена. Запись в registry без папки `RELEASE.md` тоже запрещена. Это проверяется `scripts/verify_release_governance.sh`.

Допустимый формат имени версии:

- `v1.4`;
- `v1.4.2`;
- `v1.4.1-local`;
- `v1.5.0-working`.

Другие форматы требуют отдельного решения в `docs/4_Decision_Log.md`.

## Structure Lock

Каталог версий считается закрытым контрактом. Даже если появится сто новых версий, каждая новая desktop-версия обязана проходить через один и тот же путь:

1. выбрать имя версии в разрешенном формате;
2. создать ровно одну папку `releases/versions/<version>/`;
3. добавить эту же версию в `releases/registry.json`;
4. заполнить `RELEASE.md`, `ARTIFACTS.md` и `SHA256SUMS`;
5. обновить `CHANGELOG.md` и release checklist;
6. выполнить `scripts/verify_release_governance.sh`.

Если проверка падает, дальнейшая feature/release работа запрещена до восстановления release ledger.

На GitHub проверка доступна вручную через `.github/workflows/release-governance.yml`; промежуточные push/PR не запускают Actions. При активном OWNER_LOCAL_RELEASE_20261015 выпуск подтверждается локальными проверками и сборкой точного SHA main.

Локальные DMG/build logs в `artifacts/` не коммитятся. Поэтому обычная проверка допускает их отсутствие в clean checkout и проверяет checksum только когда файл физически есть. Для локального аудита полного склада артефактов используется строгий режим:

```bash
scripts/verify_release_governance.sh --strict-local-artifacts
```

## Git и GitHub

- Release tag должен быть annotated tag формата `vMAJOR.MINOR.PATCH` или исторического формата `v1.4`, если версия уже выпущена так.
- Новые публичные релизы создаются из чистого рабочего дерева.
- GitHub Release asset должен совпадать с записью в `releases/registry.json`.
- Если локальный DMG отличается от опубликованного GitHub asset по SHA256, это фиксируется в `RELEASE.md` и registry как `localArtifactSha256` vs `githubAssetSha256`.
- Remote-only tags вроде исторических `v1.2` и `v1.3` допустимы только как legacy. Новые версии не должны иметь remote-only tag без локальной фиксации.

## Branch model

| Тип работы | Ветка | Когда использовать |
| --- | --- | --- |
| Stable source | `main` | Состояние последнего публичного stable release. |
| Следующая версия | `release/<version>` | Длинная линия подготовки релиза, например `release/1.5.0`. |
| Hotfix | `hotfix/<version>-<topic>` | Срочная правка от опубликованного тега. |
| Feature/fix | `codex/<topic>` или согласованный префикс | Изолированная задача до merge в release line. |

`assets/Info.plist` меняется только в release-cycle. Имя ветки не является поводом менять bundle version.

## Checkpoint tags

Checkpoint tag нужен перед рискованным этапом или после завершенного слоя. Формат:

```text
checkpoint/<version>-<slug>
```

Примеры:

- `checkpoint/1.5.0-sprint1`;
- `checkpoint/1.5.0-sprint2`;
- `checkpoint/1.5.0-architecture-foundation`.

Checkpoint не заменяет release tag и не публикуется как пользовательский release.

## Rollback и продолжение старых версий

Открыть старую версию для анализа:

```bash
git -C macos switch --detach v1.4.2
```

Создать отдельную ветку hotfix от старой версии:

```bash
git -C macos switch -c hotfix/v1.4.2-critical-fix v1.4.2
```

Создать отдельную рабочую копию старой версии:

```bash
git -C macos worktree add ../MacDictate-macos-v1.4.2 v1.4.2
```

Перед любым hotfix нужно:

1. сверить `releases/versions/<version>/RELEASE.md`;
2. проверить `releases/registry.json`;
3. создать новую hotfix-ветку;
4. после сборки добавить новую запись в registry, `CHANGELOG.md` и release notes.

## Release procedure

1. Проверить, что `git status` чистый или содержит только осознанные release-изменения.
2. Обновить:
   - `CHANGELOG.md`;
   - `releases/registry.json`;
   - `releases/versions/<version>/RELEASE.md`;
   - `docs/2_ActionLog.md`;
   - `docs/4_Decision_Log.md`, если было policy/architecture decision;
   - `docs/3_TechDebt_Tasks.md`, если остался долг.
3. Выполнить `scripts/verify_release_governance.sh`.
4. Выполнить `scripts/check_distribution_signing.sh` на машине, где собирается release.
5. Собрать публичный release только через Developer ID + notarization:
   ```bash
   MACDICTATE_SIGN_IDENTITY="Developer ID Application: <Name> (<TEAM_ID>)" \
   MACDICTATE_NOTARY_PROFILE="macdictate-notary" \
   MACDICTATE_NOTARIZE=true \
   ./build.sh
   ```
   Обычная `./build.sh` без этих переменных остается dev/ad-hoc сборкой и не является публичным release candidate.
6. Обычная сборка создает DMG в `build/artifacts/`; для release-candidate поместить DMG и build log в `releases/versions/<version>/artifacts/`.
7. Обновить `SHA256SUMS` и `ARTIFACTS.md`.
8. Выполнить `scripts/verify_release_governance.sh --strict-local-artifacts`, если release-candidate ссылается на локальные artifact files.
9. Создать annotated tag.
10. Опубликовать GitHub Release и asset.
11. Обновить website download alias:
   - загрузить те же байты notarized DMG на сайт как `/downloads/MacDictate_Latest.dmg`;
   - обновить `web-landing/downloads/latest-desktop.json` по `releases/registry.json` текущего `public_stable`;
   - убедиться, что ссылки на сайте продолжают вести на `/downloads/MacDictate_Latest.dmg`.
12. Снова выполнить `scripts/verify_release_governance.sh --online`.

## Что нельзя делать

- Нельзя оставлять новый DMG в корне `macos/`. Временный output `./build.sh` живет в `build/artifacts/`, release artifact живет в `releases/versions/<version>/artifacts/`.
- Нельзя создавать папку версии без registry entry и `RELEASE.md`.
- Нельзя менять release status только в тексте: status должен быть изменен в `releases/registry.json`.
- Нельзя добавлять новый публичный release без GitHub Release URL, asset name и явного checksum plan.
- Нельзя считать release завершенным, если сайт продолжает отдавать старый `/downloads/MacDictate_Latest.dmg` или `web-landing/downloads/latest-desktop.json` не совпадает с `registry.current.publicStable`.
- Нельзя менять цену/тариф/checkout без `docs/4_Decision_Log.md`.
- Нельзя выпускать релиз без записи в `releases/registry.json`.
- Нельзя считать `v1.5.0` выпущенной, пока нет release tag, GitHub Release, `RELEASE.md`, registry entry и smoke evidence.
- Нельзя публиковать новый desktop DMG, подписанный ad-hoc или `Apple Development`; публичный release должен быть подписан `Developer ID Application`, notarized и stapled. Исключение требует отдельной записи в `docs/4_Decision_Log.md`.
- Нельзя переписывать старые release notes молча. Исправления истории пишутся как `Correction note`.

## Текущие исторические оговорки

- `v1.2` и `v1.3` существуют как GitHub Releases и remote tags, но в локальном git их tag refs сейчас не присутствуют. Remote tags указывают на тот же commit, что `v1.4`; фактическое отличие подтверждается локальными DMG bundle versions и GitHub release notes.
- `v1.4.1` есть как локальный DMG/build `8`, но публичного GitHub Release/tag не найдено.
- Локальный `MacDictate_Final_v1.4.2.dmg` отличается по SHA256 от опубликованного GitHub asset. Публичным source of truth для скачивания остается GitHub Release `v1.4.2`.

## GitHub-only free distribution (D-022, 2026-10-19)

Владелец подтвердил, что прежний сервер выключен. Для новых бесплатных версий
канон скачивания — GitHub Release с versioned DMG и byte-identical
`MacDictate_Latest.dmg` asset. `latest-desktop.json.publicUrl` указывает на
этот GitHub alias; `publicPath` остаётся legacy logical path. Website mirror
на выключенном сервере больше не release gate. App updater использует GitHub
API напрямую. Статический сайт не должен зависеть от backend или оплаты.
Проверяются публичный asset, checksum, notarization, install flow и publicUrl.

## GitHub Pages publication gate

Push в connected `gh-pages` считается внешней публикацией и может автоматически
запустить deployment даже после предварительного Pages API404. Не использовать
эту ветку как staging: собрать и проверить статический snapshot (включая content
и legal QA) отдельно, затем сделать один финальный commit/push. В итерации
2026-10-19 фактически прошли три автоматические Pages выкладки; это отклонение
зафиксировано в ActionLog, а не выдано за одну финальную CI.

## Coordinated Windows/macOS release (D-023/D-024)

`windows/` is an active desktop source zone in this same Git repository. Windows distribution is self-contained x64: versioned ZIP and per-user EXE, pinned runtime source/model metadata, SHA256 and `windows-build-manifest.json` containing exact sourceSHA. Current signing status must be explicit. Windows native code must build/run on the final GitHub runner before publication; physical microphone/client-OS acceptance is reported independently.

For desktop1.6.0 the final manual `desktop-release.yml` validates governance, Swift source/regressions, Windows portable tests, native keyboard/paste integration, synthetic ASR, installer/uninstaller and creates Windows release artifacts. The GitHub source SHA must equal the local notarized macOS build source SHA. GitHub latest release must include both platform aliases, so Mac updater cannot point at a Windows-only release with a stale DMG. Do not publish partial latest assets.

Windows release metadata is additive under `versions[].windows`; macOS legacy manifest stays schema1. A separate `latest-windows.json` exposes the Windows asset/version/hash. CI runner OS is Windows Server2025, never describe it as Windows11. Final Pages content is staged away from gh-pages and pushed only after completed QA.


## Windows-only hotfix (D-025)

This section narrows the coordinated-release rule for a Windows-only fix. Do not build or version-bump macOS for Windows1.6.1, do not create a new Mac alias, and do not replace global GitHub latest.

1. Prepare `v1.6.1-working` with status `working_line`/platform `win-x64`; `current.windows.workingLine` points to it. Windows csproj `Version` is the canonical build version. `current.windows.publicStable` continues to point to the actually published Windows version. Legacy `current.publicStable`, `workingLine`, Mac bundle and `latest-desktop.json` remain Mac-owned.
2. Run `windows/scripts/check-local.sh`, `python3 windows/scripts/check-delivery.py`, local PowerShell syntax/package-guard checks, release governance and independent review. Commit reviewed source. Run the one manual `desktop-release.yml` on that exact source SHA. A repair needs a concrete recorded failure.
3. Download its exact artifact bundle. Run `python3 windows/scripts/check-delivery.py --build-manifest <directory>/windows-build-manifest.json --source-sha <full-checked-sha>`. It verifies exact package set, actual byte counts/digests, sourceSHA and pinned runtime/model. Read every UI/installer JSON and RU/EN/layout PNG. Runner synthetic input is not physical client-OS evidence.
4. Add the final `v1.6.1` ledger entry/release directory with actual build source, hashes and CI URL, initially `local_only`. Keep the working entry/history. A Windows stable entry uses global status `public_release` after publication; its platform stability is selected by `current.windows.publicStable`, leaving the only global `public_stable` as the Mac release.
5. Stage a GitHub draft on the exact checked source tag. The release create/update request **must include `make_latest: "false"`** (`gh release create ... --latest=false` or the explicit REST field). Upload only the checked EXE/ZIP, `windows-build-manifest.json`, `WINDOWS-SHA256SUMS` and release notes. Do not overwrite historical assets or publish test WAV/model files. Do not use global Windows Latest aliases for this channel.
6. Publish with `make_latest=false`, read back actual published tag/source/asset sizes/digests and independently confirm GitHub `/releases/latest` is still the Mac release. A draft, upload or local checksum is not publication proof.
7. Promote `current.windows.publicStable` to `v1.6.1`, fill its Windows ledger metadata from actual evidence, and update `latest-windows.json` plus the two pinned HTML fallback URLs to exact versioned assets. Preserve source of truth order: registry → manifest → page. Run both governance checks again. Do not fill hashes/timestamps with placeholders.
8. After RU/EN/mobile/links/legal QA, publish the staged site with the one authorized final gh-pages push and read back HTTPS bytes + actual download hashes. Keep Windows physical microphone/Alt/editor and native125/150% acceptance visibly open.

`windows/scripts/check-delivery.py` is the root-invoked Windows channel/schema/hash guard in the existing final workflow; legacy `scripts/verify_release_governance.sh` continues to validate the Mac-oriented ledger/folder contract. Both are mandatory. No new hosted workflow or push/PR trigger is added.
