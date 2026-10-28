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
  "baseCommit": null,
  "startedAt": "2026-10-29T00:59:49+08:00",
  "updatedAt": "2026-10-29T01:12:20+08:00",
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
      "status": "active",
      "startedAt": "2026-10-29T01:10:59+08:00"
    },
    {
      "id": "build",
      "status": "pending"
    },
    {
      "id": "review",
      "status": "pending"
    },
    {
      "id": "final",
      "status": "pending"
    }
  ],
  "requirements": {
    "total": 10,
    "done": 0,
    "inTicket": 10,
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
      "status": "pending",
      "retries": 0,
      "repairs": 0
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
      "status": "pending",
      "retries": 0,
      "repairs": 0
    }
  ],
  "tests": null,
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
  "concerns": [],
  "blind": null,
  "beats": [
    "2026-10-29T00:59:49+08:00",
    "2026-10-29T01:00:45+08:00",
    "2026-10-29T01:00:46+08:00",
    "2026-10-29T01:01:20+08:00",
    "2026-10-29T01:10:59+08:00",
    "2026-10-29T01:12:04+08:00",
    "2026-10-29T01:12:20+08:00"
  ],
  "rev": 15,
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
    }
  ],
  "reqList": [
    {
      "id": "R01",
      "text": "«Проверяй - куча вопросов про винду!»",
      "status": "in-ticket"
    },
    {
      "id": "R02",
      "text": "«Кнопки по скачиванию не очевидны»",
      "status": "in-ticket"
    },
    {
      "id": "R03",
      "text": "«после установки ни каких разрешений не выскакивает»",
      "status": "in-ticket"
    },
    {
      "id": "R04",
      "text": "«ничего в итоге не работает при нажатии на альт»",
      "status": "in-ticket"
    },
    {
      "id": "R05",
      "text": "«никаких инструкций что куда нажать?»",
      "status": "in-ticket"
    },
    {
      "id": "R06",
      "text": "«Никаких автоматических действий»",
      "status": "in-ticket"
    },
    {
      "id": "R07",
      "text": "«ни какой работы в итоге! Доводи до конца!»",
      "status": "in-ticket"
    },
    {
      "id": "R08i",
      "text": "(подразумевается) модель, микрофон и приложение должны быть готовы до диктовки",
      "status": "in-ticket"
    },
    {
      "id": "R09i",
      "text": "(подразумевается) при ошибке понятно, что делать дальше",
      "status": "in-ticket"
    },
    {
      "id": "R10i",
      "text": "(подразумевается) видно, что приложение запущено и запись началась",
      "status": "in-ticket"
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
      "at": "2026-10-29T01:12:20+08:00",
      "problems": 0
    }
  },
  "result": null
}
