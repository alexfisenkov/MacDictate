#!/usr/bin/env bash
set -uo pipefail

BASE_URL="${MACDICTATE_PUBLIC_BASE_URL:-https://macdictate.pro}"
CURL="${CURL:-/usr/bin/curl}"
TIMEOUT="${MACDICTATE_PUBLIC_CHECK_TIMEOUT:-15}"

check_url() {
  local label="$1"
  local url="$2"
  echo "== $label =="
  if ! "$CURL" -L -sS -o /dev/null \
    --connect-timeout 5 \
    --max-time "$TIMEOUT" \
    -w "code=%{http_code} dns=%{time_namelookup} connect=%{time_connect} tls=%{time_appconnect} ttfb=%{time_starttransfer} total=%{time_total} remote=%{remote_ip}\n" \
    "$url"; then
    status=1
  fi
}

status=0
check_url "health" "$BASE_URL/api/health"
check_url "license" "$BASE_URL/api/license/status?deviceId=MD-PUBLIC-SMOKE"
check_url "plans" "$BASE_URL/api/plans"
check_url "latest-dmg" "$BASE_URL/downloads/MacDictate_Latest.dmg"
exit "$status"
