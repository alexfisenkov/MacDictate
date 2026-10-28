window.STATE =
{
  "version": 2,
  "slug": "windows-first-run",
  "dir": "2026-10-29-windows-first-run--wip",
  "title": "Windows: от скачивания до первой диктовки",
  "mode": "auto",
  "depth": "normal",
  "questions": null,
  "tier": "T1",
  "briefFile": "2026-10-29-brief.md",
  "memoryFile": "CLAUDE.md",
  "memoryOwner": "user",
  "skillDir": "/Users/AlexFisenkov/.agents/skills/aispa",
  "skillVersion": "1.0.2",
  "baseCommit": "9531dcc",
  "startedAt": "2026-10-29T00:59:49+08:00",
  "updatedAt": "2026-10-29T02:57:36+08:00",
  "finishedAt": null,
  "stages": [
    {
      "id": "preflight",
      "status": "done",
      "startedAt": "2026-10-29T00:59:49+08:00",
      "finishedAt": "2026-10-29T01:00:45+08:00"
    },
    {
      "id": "manifest",
      "status": "done",
      "startedAt": "2026-10-29T01:00:45+08:00",
      "finishedAt": "2026-10-29T01:00:46+08:00"
    },
    {
      "id": "briefing",
      "status": "skipped",
      "startedAt": "2026-10-29T01:00:46+08:00",
      "finishedAt": "2026-10-29T01:01:20+08:00",
      "note": "Сам по брифу: решения интерфейса и диагностики принимаю самостоятельно"
    },
    {
      "id": "spec",
      "status": "done",
      "startedAt": "2026-10-29T01:01:20+08:00",
      "finishedAt": "2026-10-29T01:10:59+08:00"
    },
    {
      "id": "plan",
      "status": "done",
      "startedAt": "2026-10-29T01:10:59+08:00",
      "finishedAt": "2026-10-29T01:12:20+08:00"
    },
    {
      "id": "build",
      "status": "done",
      "startedAt": "2026-10-29T01:12:20+08:00",
      "finishedAt": "2026-10-29T01:48:25+08:00"
    },
    {
      "id": "review",
      "status": "done",
      "startedAt": "2026-10-29T01:48:25+08:00",
      "finishedAt": "2026-10-29T02:18:18+08:00"
    },
    {
      "id": "final",
      "status": "active",
      "startedAt": "2026-10-29T02:18:18+08:00"
    }
  ],
  "requirements": {
    "total": 10,
    "done": 10,
    "inTicket": 0,
    "inSpec": 0,
    "placeholder": 0,
    "deferred": 0,
    "dropped": 0
  },
  "tickets": [
    {
      "id": "01",
      "title": "От первого запуска к первой диктовке",
      "requirements": [
        "R01",
        "R03",
        "R04",
        "R05",
        "R06",
        "R07",
        "R08i",
        "R09i",
        "R10i"
      ],
      "blockedBy": [],
      "wave": 1,
      "zone": [
        "windows/src",
        "windows/tests",
        "windows/scripts/check-local.sh",
        "scripts/check_architecture_guardrails.sh"
      ],
      "review": "да — фундамент",
      "model": "сильная",
      "status": "done",
      "startedAt": "2026-10-29T01:12:20+08:00",
      "finishedAt": "2026-10-29T01:41:46+08:00",
      "retries": 0,
      "repairs": 1,
      "repairFindings": [
        "Исчезнувший micID остаётся активным; ошибка целостности модели скрыта общим текстом"
      ],
      "tests": {
        "passed": 54,
        "failed": 0
      },
      "commit": "f1582a5"
    },
    {
      "id": "02",
      "title": "Понятное скачивание и проверенная доставка Windows",
      "requirements": [
        "R01",
        "R02",
        "R05",
        "R07",
        "R09i"
      ],
      "blockedBy": [
        "01"
      ],
      "wave": 2,
      "zone": [
        "windows/src/MacDictate.Windows/OnboardingSmoke.cs",
        "web-landing",
        "windows/README.md",
        "windows/scripts (кроме check-local.sh)",
        ".github/workflows",
        "releases",
        "docs",
        "windows/src/MacDictate.Windows/MacDictate.Windows.csproj"
      ],
      "review": "нет",
      "model": "сильная",
      "status": "done",
      "startedAt": "2026-10-29T01:28:21+08:00",
      "finishedAt": "2026-10-29T02:40:35+08:00",
      "retries": 1,
      "repairs": 2,
      "tests": {
        "passed": 60,
        "failed": 0
      },
      "commit": "538519d",
      "repairFindings": [
        "Existing docs-layout check red: five stale line counts in docs/00-индекс.md",
        "Final Windows CI check-delivery charmap decode failure before native UI; explicit UTF-8 needed"
      ]
    },
    {
      "id": "F1",
      "title": "Заключительный ремонт первого запуска",
      "requirements": [
        "R02",
        "R03",
        "R05",
        "R06",
        "R07",
        "R08i",
        "R09i",
        "R10i"
      ],
      "blockedBy": [],
      "wave": 3,
      "zone": [
        "windows/src/MacDictate.Core",
        "windows/src/MacDictate.Windows/MainForm.cs",
        "windows/src/MacDictate.Windows/TrayApplication.cs",
        "windows/src/MacDictate.Windows/Native/MicrophoneService.cs",
        "windows/src/MacDictate.Windows/Native/PasteService.cs",
        "windows/src/MacDictate.Windows/OnboardingSmoke.cs",
        "windows/tests",
        "web-landing/index.html"
      ],
      "review": "да — ремонт ветки",
      "model": "сильная",
      "status": "done",
      "retries": 0,
      "repairs": 1,
      "startedAt": "2026-10-29T01:56:48+08:00",
      "finishedAt": "2026-10-29T02:18:18+08:00",
      "tests": {
        "passed": 60,
        "failed": 0
      },
      "commit": "b87038f",
      "repairFindings": [
        "Render скрывает local ms-settings/clipboard ошибку; связать её с видимым состоянием"
      ]
    }
  ],
  "tests": {
    "passed": 60,
    "failed": 0
  },
  "debt": {
    "placeholders": [],
    "assumptions": [
      "Поддерживаем Windows10 build19041+ и Windows11 x64; точная конфигурация компьютера друга неизвестна",
      "Первый запуск открывает видимый мастер; после явного запуска настройки проверка и подготовка идут автоматически",
      "Сохраняем двойной левый Alt; добавляем видимую кнопку записи и проверку горячей клавиши"
    ],
    "emptyEnv": []
  },
  "additions": [],
  "coverage": {
    "found": 0,
    "fixed": 0,
    "deferred": 0,
    "items": []
  },
  "concerns": [
    "OnboardingSmoke.cs:51 — Visible property не доказывает видимость поверх других окон; T02/native read-back должен проверить настоящее окно",
    "T01 repair re-review: NoDevice state lost after empty device refresh/WM_DEVICECHANGE; Record stays enabled Untested untilclick. Capture guarded but UI readiness false; fix-now candidate for wholebranch F1. Integrity error condition closed.",
    "T02 self-review: result TextBox can remain below initial viewport in long Home flow; test must not hide this with forcedscroll. R07/R10i production first result should be visibly reachable automatically without stealing external paste focus.",
    "T02 UI inspection: operation Message/mic status may be below initial viewport in long setup. Wholebranch must evaluate production visibility, not merely source text or forced test scrolling."
  ],
  "blind": {
    "checked": 8,
    "matched": 4,
    "mismatches": [
      "Physical microphone/Alt/editor on friend Windows10/11 nottested; automaticServer2025 accepted only",
      "New public website/download notyetdeployed; localbrowserchecked, candidateaccepted"
    ]
  },
  "beats": [
    "2026-10-29T00:59:49+08:00",
    "2026-10-29T01:00:45+08:00",
    "2026-10-29T01:00:46+08:00",
    "2026-10-29T01:01:20+08:00",
    "2026-10-29T01:10:59+08:00",
    "2026-10-29T01:12:04+08:00",
    "2026-10-29T01:12:20+08:00",
    "2026-10-29T01:17:33+08:00",
    "2026-10-29T01:24:05+08:00",
    "2026-10-29T01:28:20+08:00",
    "2026-10-29T01:28:21+08:00",
    "2026-10-29T01:34:20+08:00",
    "2026-10-29T01:34:21+08:00",
    "2026-10-29T01:39:46+08:00",
    "2026-10-29T01:41:46+08:00",
    "2026-10-29T01:43:14+08:00",
    "2026-10-29T01:46:10+08:00",
    "2026-10-29T01:48:24+08:00",
    "2026-10-29T01:48:25+08:00",
    "2026-10-29T01:56:47+08:00",
    "2026-10-29T01:56:48+08:00",
    "2026-10-29T01:58:21+08:00",
    "2026-10-29T01:58:42+08:00",
    "2026-10-29T01:59:30+08:00",
    "2026-10-29T02:10:32+08:00",
    "2026-10-29T02:14:44+08:00",
    "2026-10-29T02:18:18+08:00",
    "2026-10-29T02:19:50+08:00",
    "2026-10-29T02:24:32+08:00",
    "2026-10-29T02:24:33+08:00",
    "2026-10-29T02:25:58+08:00",
    "2026-10-29T02:33:09+08:00",
    "2026-10-29T02:40:35+08:00",
    "2026-10-29T02:57:36+08:00"
  ],
  "rev": 59,
  "waiting": null,
  "waits": [],
  "log": [
    {
      "t": "2026-10-29T00:59:49+08:00",
      "k": "init"
    },
    {
      "t": "2026-10-29T01:00:45+08:00",
      "k": "stage",
      "id": "manifest",
      "act": "start"
    },
    {
      "t": "2026-10-29T01:00:46+08:00",
      "k": "stage",
      "id": "briefing",
      "act": "start"
    },
    {
      "t": "2026-10-29T01:01:20+08:00",
      "k": "stage",
      "id": "briefing",
      "act": "skip",
      "note": "Сам по брифу: решения интерфейса и диагностики принимаю самостоятельно"
    },
    {
      "t": "2026-10-29T01:01:20+08:00",
      "k": "add",
      "key": "debt.assumptions",
      "n": 3
    },
    {
      "t": "2026-10-29T01:01:20+08:00",
      "k": "gate",
      "g": "G1",
      "ok": false,
      "open": 10,
      "total": 10
    },
    {
      "t": "2026-10-29T01:01:20+08:00",
      "k": "stage",
      "id": "spec",
      "act": "start"
    },
    {
      "t": "2026-10-29T01:10:59+08:00",
      "k": "gate",
      "g": "G2",
      "ok": true,
      "found": 0,
      "fixed": 0,
      "deferred": 0
    },
    {
      "t": "2026-10-29T01:10:59+08:00",
      "k": "stage",
      "id": "plan",
      "act": "start"
    },
    {
      "t": "2026-10-29T01:10:59+08:00",
      "k": "tier",
      "v": "T1"
    },
    {
      "t": "2026-10-29T01:12:04+08:00",
      "k": "tickets",
      "n": 2
    },
    {
      "t": "2026-10-29T01:12:04+08:00",
      "k": "gate",
      "g": "G3",
      "ok": false,
      "problems": 2
    },
    {
      "t": "2026-10-29T01:12:20+08:00",
      "k": "tickets",
      "n": 2
    },
    {
      "t": "2026-10-29T01:12:20+08:00",
      "k": "gate",
      "g": "G3",
      "ok": true,
      "problems": 0
    },
    {
      "t": "2026-10-29T01:12:20+08:00",
      "k": "stage",
      "id": "build",
      "act": "start"
    },
    {
      "t": "2026-10-29T01:12:20+08:00",
      "k": "ticket",
      "ids": [
        "01"
      ],
      "act": "start"
    },
    {
      "t": "2026-10-29T01:17:33+08:00",
      "k": "add",
      "key": "report",
      "n": 3
    },
    {
      "t": "2026-10-29T01:24:05+08:00",
      "k": "add",
      "key": "report",
      "n": 1
    },
    {
      "t": "2026-10-29T01:28:20+08:00",
      "k": "ticket",
      "ids": [
        "01"
      ],
      "act": "done",
      "tests": {
        "passed": 46,
        "failed": 0
      }
    },
    {
      "t": "2026-10-29T01:28:21+08:00",
      "k": "ticket",
      "ids": [
        "01"
      ],
      "act": "review"
    },
    {
      "t": "2026-10-29T01:28:21+08:00",
      "k": "ticket",
      "ids": [
        "02"
      ],
      "act": "start"
    },
    {
      "t": "2026-10-29T01:34:20+08:00",
      "k": "ticket",
      "ids": [
        "01"
      ],
      "act": "repair",
      "note": "Исчезнувший micID остаётся активным; ошибка целостности модели скрыта общим текстом"
    },
    {
      "t": "2026-10-29T01:34:20+08:00",
      "k": "add",
      "key": "concerns",
      "n": 1
    },
    {
      "t": "2026-10-29T01:34:20+08:00",
      "k": "tickets",
      "n": 2
    },
    {
      "t": "2026-10-29T01:34:21+08:00",
      "k": "gate",
      "g": "G3",
      "ok": true,
      "problems": 0
    },
    {
      "t": "2026-10-29T01:39:46+08:00",
      "k": "ticket",
      "ids": [
        "01"
      ],
      "act": "done",
      "tests": {
        "passed": 54,
        "failed": 0
      }
    },
    {
      "t": "2026-10-29T01:39:46+08:00",
      "k": "ticket",
      "ids": [
        "01"
      ],
      "act": "review"
    },
    {
      "t": "2026-10-29T01:41:46+08:00",
      "k": "add",
      "key": "concerns",
      "n": 1
    },
    {
      "t": "2026-10-29T01:41:46+08:00",
      "k": "ticket",
      "ids": [
        "01"
      ],
      "act": "done",
      "tests": {
        "passed": 54,
        "failed": 0
      }
    },
    {
      "t": "2026-10-29T01:43:14+08:00",
      "k": "add",
      "key": "concerns",
      "n": 1
    },
    {
      "t": "2026-10-29T01:46:10+08:00",
      "k": "add",
      "key": "concerns",
      "n": 1
    },
    {
      "t": "2026-10-29T01:48:24+08:00",
      "k": "ticket",
      "ids": [
        "02"
      ],
      "act": "done",
      "tests": {
        "passed": 54,
        "failed": 0
      }
    },
    {
      "t": "2026-10-29T01:48:25+08:00",
      "k": "stage",
      "id": "review",
      "act": "start"
    },
    {
      "t": "2026-10-29T01:56:47+08:00",
      "k": "add",
      "key": "report",
      "n": 1
    },
    {
      "t": "2026-10-29T01:56:48+08:00",
      "k": "tickets",
      "n": 3
    },
    {
      "t": "2026-10-29T01:56:48+08:00",
      "k": "gate",
      "g": "G3",
      "ok": true,
      "problems": 0
    },
    {
      "t": "2026-10-29T01:56:48+08:00",
      "k": "ticket",
      "ids": [
        "F1"
      ],
      "act": "start"
    },
    {
      "t": "2026-10-29T01:58:21+08:00",
      "k": "add",
      "key": "report",
      "n": 1
    },
    {
      "t": "2026-10-29T01:58:42+08:00",
      "k": "ticket",
      "ids": [
        "02"
      ],
      "act": "repair",
      "note": "Existing docs-layout check red: five stale line counts in docs/00-индекс.md"
    },
    {
      "t": "2026-10-29T01:59:30+08:00",
      "k": "ticket",
      "ids": [
        "02"
      ],
      "act": "done",
      "tests": {
        "passed": 54,
        "failed": 0
      }
    },
    {
      "t": "2026-10-29T02:10:32+08:00",
      "k": "ticket",
      "ids": [
        "F1"
      ],
      "act": "done",
      "tests": {
        "passed": 59,
        "failed": 0
      }
    },
    {
      "t": "2026-10-29T02:10:32+08:00",
      "k": "ticket",
      "ids": [
        "F1"
      ],
      "act": "review"
    },
    {
      "t": "2026-10-29T02:14:44+08:00",
      "k": "add",
      "key": "report",
      "n": 1
    },
    {
      "t": "2026-10-29T02:14:44+08:00",
      "k": "ticket",
      "ids": [
        "F1"
      ],
      "act": "repair",
      "note": "Render скрывает local ms-settings/clipboard ошибку; связать её с видимым состоянием"
    },
    {
      "t": "2026-10-29T02:18:18+08:00",
      "k": "ticket",
      "ids": [
        "F1"
      ],
      "act": "done",
      "tests": {
        "passed": 60,
        "failed": 0
      }
    },
    {
      "t": "2026-10-29T02:18:18+08:00",
      "k": "stage",
      "id": "final",
      "act": "start"
    },
    {
      "t": "2026-10-29T02:18:18+08:00",
      "k": "tests",
      "passed": 60,
      "failed": 0
    },
    {
      "t": "2026-10-29T02:19:50+08:00",
      "k": "add",
      "key": "report",
      "n": 1
    },
    {
      "t": "2026-10-29T02:24:32+08:00",
      "k": "ticket",
      "ids": [
        "02"
      ],
      "act": "repair",
      "note": "Final Windows CI check-delivery charmap decode failure before native UI; explicit UTF-8 needed"
    },
    {
      "t": "2026-10-29T02:24:33+08:00",
      "k": "add",
      "key": "report",
      "n": 1
    },
    {
      "t": "2026-10-29T02:25:58+08:00",
      "k": "ticket",
      "ids": [
        "02"
      ],
      "act": "done",
      "tests": {
        "passed": 60,
        "failed": 0
      }
    },
    {
      "t": "2026-10-29T02:33:09+08:00",
      "k": "ticket",
      "ids": [
        "02"
      ],
      "act": "retry"
    },
    {
      "t": "2026-10-29T02:33:09+08:00",
      "k": "add",
      "key": "report",
      "n": 1
    },
    {
      "t": "2026-10-29T02:40:35+08:00",
      "k": "ticket",
      "ids": [
        "02"
      ],
      "act": "done",
      "tests": {
        "passed": 60,
        "failed": 0
      }
    },
    {
      "t": "2026-10-29T02:40:35+08:00",
      "k": "add",
      "key": "report",
      "n": 1
    },
    {
      "t": "2026-10-29T02:57:36+08:00",
      "k": "gate",
      "g": "G4",
      "ok": false,
      "checked": 8,
      "matched": 4
    },
    {
      "t": "2026-10-29T02:57:36+08:00",
      "k": "add",
      "key": "report",
      "n": 1
    }
  ],
  "reqList": [
    {
      "id": "R01",
      "text": "«Проверяй - куча вопросов про винду!»",
      "status": "done"
    },
    {
      "id": "R02",
      "text": "«Кнопки по скачиванию не очевидны»",
      "status": "done"
    },
    {
      "id": "R03",
      "text": "«после установки ни каких разрешений не выскакивает»",
      "status": "done"
    },
    {
      "id": "R04",
      "text": "«ничего в итоге не работает при нажатии на альт»",
      "status": "done"
    },
    {
      "id": "R05",
      "text": "«никаких инструкций что куда нажать?»",
      "status": "done"
    },
    {
      "id": "R06",
      "text": "«Никаких автоматических действий»",
      "status": "done"
    },
    {
      "id": "R07",
      "text": "«ни какой работы в итоге! Доводи до конца!»",
      "status": "done"
    },
    {
      "id": "R08i",
      "text": "(подразумевается) модель, микрофон и приложение должны быть готовы до диктовки",
      "status": "done"
    },
    {
      "id": "R09i",
      "text": "(подразумевается) при ошибке понятно, что делать дальше",
      "status": "done"
    },
    {
      "id": "R10i",
      "text": "(подразумевается) видно, что приложение запущено и запись началась",
      "status": "done"
    }
  ],
  "gates": {
    "G1": {
      "ok": false,
      "at": "2026-10-29T01:01:20+08:00",
      "open": 10,
      "total": 10
    },
    "G2": {
      "ok": true,
      "at": "2026-10-29T01:10:59+08:00",
      "found": 0,
      "fixed": 0,
      "deferred": 0
    },
    "G3": {
      "ok": true,
      "at": "2026-10-29T01:56:48+08:00",
      "problems": 0
    },
    "G4": {
      "ok": false,
      "at": "2026-10-29T02:57:36+08:00",
      "checked": 8,
      "matched": 4
    }
  },
  "result": null,
  "report": [
    "Подтверждены два UX-барьера: модальные настройки блокируют Alt, скачанная модель не активируется до Save; причина конкретного ПК пока неизвестна",
    "Windows WinMM не гарантирует отдельный OS consent prompt; проверяем реальную запись и общий desktop microphone toggle",
    "Без физического Windows устройства не выдаём синтетический PCM/hotkey seam за подтверждение на компьютере друга",
    "Локальная реализация приложения прошла cross-build без warnings и46portable checks по отчёту исполнителя; native UI/ASR приёмка ещё впереди",
    "Уже существующий по адресу загрузки файл с другимSHA сохраняется; повтор без смены/переноса файла не ремонтирует его. Ручное восстановление остаётся отдельным ограничением",
    "Browser runtime QA: RU/EN390px и1440px безoverflow; EXEявныйprimary,ZIPотдельнораскрывается; текущиепубличныеURLещёv1.6.0доverifiedpublication1.6.1",
    "Ограниченное отступление от лимита F1: scoped review оставил невидимые local errors ms-settings/clipboard. По явному уведомлению пользователя закрываем тем же writer коротким ремонтом и локальной проверкой, без третьего полного ревью",
    "Набор33b3687 передан независимой G4-проверке: чистый GitHubклон + единственный manualWindowsCI. Orchestrator не запускаетдубликат; ждём фактическиеUI/ASR/installer/PNG",
    "CI40744090057 RED on check-delivery charmap decode7147; packagesbuilt, WindowsUI/ASR/installnotrun. OnlyconcreteUTF8repairjustifiesnextmanualrun",
    "RepairCI40745192074 realWhisperUIonboarding/nativePASS; installednormalfreshUI failed LastDictationText missing. Mustdiagnoseactualvisibility vswrongassertion, no passclaim.",
    "CI40745192074 actualUI+realWhisperPASS, normalfreshgatehadincorrectalways-result assumption. Fixedstate-aware34contractcases; native rerunneeded. Appcodeunchanged.",
    "G4actual finalJSON/PNG PASSautomatic: installed normal UI/Copy/reopen/492payload/reinstall/uninstall, realbundledWhisperresultvisible. Retention1populatedPNGmissing; UIA/clipboard+realASRPNGverified."
  ]
}
