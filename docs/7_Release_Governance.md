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

На GitHub этот же запрет закреплен workflow `.github/workflows/release-governance.yml`: push и pull request в основные рабочие ветки должны пройти `scripts/verify_release_governance.sh`.

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
11. Снова выполнить `scripts/verify_release_governance.sh --online`.

## Что нельзя делать

- Нельзя оставлять новый DMG в корне `macos/`. Временный output `./build.sh` живет в `build/artifacts/`, release artifact живет в `releases/versions/<version>/artifacts/`.
- Нельзя создавать папку версии без registry entry и `RELEASE.md`.
- Нельзя менять release status только в тексте: status должен быть изменен в `releases/registry.json`.
- Нельзя добавлять новый публичный release без GitHub Release URL, asset name и явного checksum plan.
- Нельзя менять цену/тариф/checkout без `docs/4_Decision_Log.md`.
- Нельзя выпускать релиз без записи в `releases/registry.json`.
- Нельзя считать `v1.5.0` выпущенной, пока нет release tag, GitHub Release, `RELEASE.md`, registry entry и smoke evidence.
- Нельзя публиковать новый desktop DMG, подписанный ad-hoc или `Apple Development`; публичный release должен быть подписан `Developer ID Application`, notarized и stapled. Исключение требует отдельной записи в `docs/4_Decision_Log.md`.
- Нельзя переписывать старые release notes молча. Исправления истории пишутся как `Correction note`.

## Текущие исторические оговорки

- `v1.2` и `v1.3` существуют как GitHub Releases и remote tags, но в локальном git их tag refs сейчас не присутствуют. Remote tags указывают на тот же commit, что `v1.4`; фактическое отличие подтверждается локальными DMG bundle versions и GitHub release notes.
- `v1.4.1` есть как локальный DMG/build `8`, но публичного GitHub Release/tag не найдено.
- Локальный `MacDictate_Final_v1.4.2.dmg` отличается по SHA256 от опубликованного GitHub asset. Публичным source of truth для скачивания остается GitHub Release `v1.4.2`.
