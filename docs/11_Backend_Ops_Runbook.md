# Backend Ops Runbook

Этот документ фиксирует минимальный production-контур для `macdictate.pro`: сайт, обновления и API для старых desktop-версий. Бесплатный desktop по решению D-021 от 2026-10-19 не вызывает `GET /api/license/status`; сохраняем API совместимым для ранее установленных клиентов. Переход публичной дистрибуции и checkout отслеживается отдельно в backlog.

## Health checks

- Public app/API health: `https://macdictate.pro/api/health`
- Alias: `https://macdictate.pro/healthz`
- License status smoke: `https://macdictate.pro/api/license/status?deviceId=MD-OPS-SMOKE`
- Website download smoke: `https://macdictate.pro/downloads/MacDictate_Latest.dmg`
- Current production host: `193.233.247.71`
- SSH aliases from the maintainer machine: `ssh macdictate-prod`, `ssh macdictate-moscow`

Quick local probe:

```bash
scripts/check_public_services.sh
```

## Timeout triage

Если `curl` показывает быстрый TCP connect, но `time_appconnect=0` и `SSL connection timeout`, запрос не дошел до Express route. В первую очередь проверять TLS/reverse-proxy слой:

```bash
curl -I -L --connect-timeout 5 --max-time 15 https://macdictate.pro/api/health
curl -I -L --connect-timeout 5 --max-time 15 https://www.macdictate.pro/api/health
curl -I -L --connect-timeout 5 --max-time 15 http://macdictate.pro/
```

На сервере:

```bash
docker compose ps
docker compose logs --tail=200 api
systemctl status nginx
journalctl -u nginx --since "30 min ago" --no-pager
ss -ltnp | grep -E ':80|:443|:3000'
df -h
free -m
```

`3000` должен слушать только `127.0.0.1`; публичный доступ к API идет через nginx `/api/*` на 80/443.

## Production Host

Current production layout on `193.233.247.71`:

- Static website: `/var/www/macdictate.pro`
- Backend: `/opt/macdictate-backend`
- SQLite database: `/opt/macdictate-backend/data/database.sqlite`
- Nginx vhost: `/etc/nginx/sites-available/macdictate.pro`
- Backups: `/root/macdictate-backups`

The Moscow host is the active production host. It runs nginx, Docker Compose v2, certbot, the current static site, backend code, and the `v1.5.1` DMG alias. Runtime credentials live only in server-local `/opt/macdictate-backend/.env` with `0600` permissions; do not copy them into the repo or logs.

Registrar DNS:

- `A macdictate.pro` -> `193.233.247.71`
- `A www.macdictate.pro` -> `193.233.247.71`

Post-deploy checks should be run with normal DNS. Use `--resolve macdictate.pro:443:193.233.247.71` only when bypassing DNS cache during incident triage.

## Backend hardening

The Node API exposes `/api/health`, logs slow requests as structured `slow_request` events without device IDs, and sets explicit server timeouts through env:

- `SERVER_REQUEST_TIMEOUT_MS`
- `SERVER_HEADERS_TIMEOUT_MS`
- `SERVER_KEEP_ALIVE_TIMEOUT_MS`
- `SLOW_REQUEST_LOG_MS`
- `DB_BUSY_TIMEOUT_MS`

SQLite runs with WAL and a busy timeout to reduce transient lock failures. This does not fix TLS-handshake stalls by itself; those must be handled at the reverse proxy / host layer.

## Release obligation

Every public desktop release must update both public channels:

1. GitHub Release asset.
2. Website alias `/downloads/MacDictate_Latest.dmg`.

`scripts/verify_release_governance.sh --online` checks both the GitHub Release and the website alias availability.

## Free rollout 2026-10-19 — deployment gate

Current source returns perpetual free legacy access without DB writes, empty plans,
and HTTP410 for new payment creation. Existing callbacks/history remain supported.
`python3 scripts/test_free_access_backend.py` verifies this against a disposable DB.

Production access is currently unverified: the historical IP presents changed SSH
keys and TLS internal error from two independent networks. Do not accept the key
without independent owner/provider verification. Paths above are historical until
a trusted server read-back. No credentials or database may be committed.
