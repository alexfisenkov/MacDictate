# Backend Ops Runbook

Этот документ фиксирует минимальный production-контур для `macdictate.pro`, потому что desktop app зависит от `GET /api/license/status`.

## Health checks

- Public app/API health: `https://macdictate.pro/api/health`
- Alias: `https://macdictate.pro/healthz`
- License status smoke: `https://macdictate.pro/api/license/status?deviceId=MD-OPS-SMOKE`
- Website download smoke: `https://macdictate.pro/downloads/MacDictate_Latest.dmg`

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
