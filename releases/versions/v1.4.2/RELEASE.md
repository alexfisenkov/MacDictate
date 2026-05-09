# MacDictate v1.4.2

## Status

- Status: `public_release`
- Bundle: `1.4.2` / build `9`
- Git tag: `v1.4.2`
- Git commit: `4a2fa2a3eebd392f4f336080df2b3c84d0884d26`
- GitHub Release: `https://github.com/alexfisenkov/MacDictate/releases/tag/v1.4.2`

## Summary

Предыдущая публичная стабильная desktop-версия. Добавлены OTA-проверка обновлений через GitHub Releases API и звук `Tink` после успешной вставки.

## Difference From v1.4

- Версия поднята с `1.4/7` до `1.4.2/9`.
- Update check переведен на `https://api.github.com/repos/alexfisenkov/MacDictate/releases/latest`.
- Добавлен звук успешного paste.
- DMG переименован в `MacDictate_Final_v1.4.2.dmg`.

## Artifact Note

GitHub API сообщает SHA256 публичного asset:

```text
7c63e4d3d29cb99ab4cf557e070a53e55cb62347dcbff3ae412839529a4464f5
```

Локальный DMG в этой папке имеет другой SHA256:

```text
8f86246ea0b823a2f1b106e96f7a14014a06fd252df3055a5de5e6d8ae166ddb
```

Вывод: публичный GitHub Release остается source of truth для скачивания. Локальный файл хранится как локальный артефакт и требует отдельной сверки, если его планируется переиспользовать.
