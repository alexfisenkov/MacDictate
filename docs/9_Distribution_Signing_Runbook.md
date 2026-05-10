# Distribution Signing Runbook

Этот документ описывает правильный release-контур для MacDictate `.app` / `.dmg`.

Цель: заменить ad-hoc подпись на стабильную `Developer ID Application` подпись, notarization и stapling, чтобы macOS сохраняла trust identity приложения между обновлениями.

## Почему это важно

Ad-hoc подпись привязана к cdhash конкретной сборки. После пересборки cdhash меняется, и macOS TCC/Accessibility может воспринимать приложение как новый binary identity. Поэтому пользователь иногда вынужден удалять старую запись MacDictate из `System Settings -> Privacy & Security -> Accessibility` и добавлять приложение заново.

Developer ID подпись дает стабильную designated requirement вокруг Team ID, bundle id и certificate chain. После одноразового перехода на Developer ID нормальные обновления должны сохранять Accessibility permission, если не меняются:

- bundle id `com.alexfisenkov.macdictate`;
- Developer ID team/certificate identity;
- путь установки `/Applications/MacDictate.app`;
- signing policy релизов.

## Локальная проверка готовности

```bash
cd macos
scripts/check_distribution_signing.sh
```

Скрипт проверяет:

- наличие `Developer ID Application` identity в Keychain;
- наличие `MACDICTATE_SIGN_IDENTITY`, если переменная задана;
- работоспособность `MACDICTATE_NOTARY_PROFILE`, если переменная задана;
- текущее состояние подписи `build/MacDictate.app`, если он уже собран.

## Создание Developer ID certificate

Сертификат должен появиться в Keychain как:

```text
Developer ID Application: <Name> (<TEAM_ID>)
```

Рекомендованный путь:

1. Открыть Xcode.
2. `Xcode -> Settings -> Accounts`.
3. Добавить Apple ID с активным Apple Developer Program membership.
4. Выбрать команду.
5. `Manage Certificates...`.
6. Нажать `+` и создать/download `Developer ID Application`.
7. Проверить:

```bash
security find-identity -v -p codesigning
```

Для публичного MacDictate release нельзя использовать `Apple Development: ...`; он подходит для development/debug, но не решает distribution identity.

Текущий MacDictate Developer ID certificate:

```text
Developer ID Application: Aleksander Fisenkov (5BABN9U6WS)
Issued by Developer ID Certification Authority G2
Valid until 2031-05-11
```

## Notary profile

Notarization credentials хранятся в Keychain profile. Пароли, app-specific passwords, private keys и API keys не коммитятся и не записываются в документы.

Вариант с Apple ID app-specific password:

```bash
xcrun notarytool store-credentials "macdictate-notary" \
  --apple-id "<APPLE_ID_EMAIL>" \
  --team-id "<TEAM_ID>" \
  --password "<APP_SPECIFIC_PASSWORD>"
```

Безопаснее не передавать пароль в командной строке, а дать `notarytool` запросить его интерактивно:

```bash
xcrun notarytool store-credentials "macdictate-notary" \
  --apple-id "a.fisenkov@gmail.com" \
  --team-id "5BABN9U6WS"
```

Проверка:

```bash
xcrun notarytool history --keychain-profile "macdictate-notary"
```

## Release build

Обычная локальная сборка остается ad-hoc:

```bash
./build.sh
```

Developer ID signed build без notarization:

```bash
MACDICTATE_SIGN_IDENTITY="Developer ID Application: <Name> (<TEAM_ID>)" \
MACDICTATE_NOTARIZE=false \
./build.sh
```

Полная release-сборка с notarization/stapling:

```bash
MACDICTATE_SIGN_IDENTITY="Developer ID Application: <Name> (<TEAM_ID>)" \
MACDICTATE_NOTARY_PROFILE="macdictate-notary" \
MACDICTATE_NOTARIZE=true \
./build.sh
```

`build.sh` подписывает `.app`, staging-копию внутри DMG source и сам `.dmg`. При включенной notarization он выполняет:

- `xcrun notarytool submit --wait`;
- `xcrun stapler staple`;
- `xcrun stapler validate`;
- `spctl` проверку primary signature DMG.

## Release validation

Минимальная проверка перед публикацией:

```bash
tmp_app_dir="$(mktemp -d)"
ditto --noextattr --noqtn build/MacDictate.app "$tmp_app_dir/MacDictate.app"
dot_clean -m "$tmp_app_dir/MacDictate.app" >/dev/null 2>&1 || true
xattr -cr "$tmp_app_dir/MacDictate.app" >/dev/null 2>&1 || true
xattr -c "$tmp_app_dir/MacDictate.app" >/dev/null 2>&1 || true
xattr -d com.apple.FinderInfo "$tmp_app_dir/MacDictate.app" >/dev/null 2>&1 || true
codesign --verify --deep --strict --verbose=2 "$tmp_app_dir/MacDictate.app"
codesign -dv --verbose=4 build/MacDictate.app
hdiutil verify build/artifacts/MacDictate_Final_v1.5.1.dmg
xcrun stapler validate build/artifacts/MacDictate_Final_v1.5.1.dmg
spctl -a -vv -t open --context context:primary-signature build/artifacts/MacDictate_Final_v1.5.1.dmg
rm -rf "$tmp_app_dir"
```

После установки из DMG дополнительно проверить:

```bash
codesign --verify --deep --strict --verbose=2 /Applications/MacDictate.app
codesign -dv --verbose=4 /Applications/MacDictate.app
spctl -a -vv --type execute /Applications/MacDictate.app
```

## Accessibility migration note

Переход с ad-hoc на Developer ID может потребовать один раз заново выдать Accessibility permission, потому что identity меняется. После этого следующие Developer ID signed updates должны сохранять разрешение без удаления старой записи через минус.
