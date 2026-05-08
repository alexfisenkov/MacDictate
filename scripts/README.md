# Scripts

## `verify_release_governance.sh`

Проверяет, что desktop release registry, per-version folders, локальные артефакты, checksums, `Info.plist` и обязательные git tags не расходятся.

Скрипт также запрещает:

- папки `releases/versions/<version>/` без записи в `releases/registry.json`;
- записи в registry без одноименной version-папки;
- имена версий вне разрешенного формата;
- `working_line` без суффикса `-working`;
- публичные релизы с `-local` или `-working`;
- `RELEASE.md` без совпадающего `Status`;
- новый DMG/build log в корне `macos/`.

Локальная проверка:

```bash
scripts/verify_release_governance.sh
```

Проверка с GitHub Releases API:

```bash
scripts/verify_release_governance.sh --online
```

Строгая локальная проверка ignored DMG/build logs:

```bash
scripts/verify_release_governance.sh --strict-local-artifacts
```

GitHub Actions gate:

```text
.github/workflows/release-governance.yml
```

## `test_whisper_runner_timeout.sh`

Компилирует `WhisperRunner` с fake `whisper-cli` и проверяет, что transcription timeout возвращает диагностическую ошибку, останавливает subprocess, чистит temp audio и не блокируется на большом `stderr`.

```bash
scripts/test_whisper_runner_timeout.sh
```

## `test_license_machine_id_timeout.sh`

Компилирует `LicenseService` с fake `ioreg` и проверяет parsing/cache machine ID, а также быстрый generated fallback при зависшем command.

```bash
scripts/test_license_machine_id_timeout.sh
```

## `test_recording_temp_cleanup.sh`

Компилирует `RecordingService` и проверяет cleanup stale temp WAV/TXT.

```bash
scripts/test_recording_temp_cleanup.sh
```
