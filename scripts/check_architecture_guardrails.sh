#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
errors=0

fail() {
  echo "ERROR: $*" >&2
  errors=$((errors + 1))
}

line_count() {
  wc -l < "$1" | tr -d ' '
}

check_max_lines() {
  local path="$1"
  local max_lines="$2"
  local lines
  lines="$(line_count "$ROOT_DIR/$path")"

  if (( lines > max_lines )); then
    fail "$path has $lines lines; limit is $max_lines. Split it according to docs/10_App_Architecture_Guardrails.md."
  fi
}

if ! cmp -s "$ROOT_DIR/CLAUDE.md" "$ROOT_DIR/AGENTS.md"; then
  fail "CLAUDE.md and AGENTS.md differ. Update CLAUDE.md first, then run: cp CLAUDE.md AGENTS.md"
fi

while IFS= read -r -d '' file; do
  rel="${file#$ROOT_DIR/}"
  case "$rel" in
    src/AppController.swift)
      check_max_lines "$rel" 250
      ;;
    src/App/AppController+*.swift)
      check_max_lines "$rel" 320
      ;;
    src/*.swift|src/*/*.swift)
      check_max_lines "$rel" 350
      ;;
  esac
done < <(find "$ROOT_DIR/src" -name "*.swift" -print0)

while IFS= read -r path; do
  case "$path" in
    .github/*|archive/*|assets/*|backend/*|docs/*|releases/*|scripts/*|src/*|web-landing/*)
      ;;
    .gitignore|AGENTS.md|CHANGELOG.md|CLAUDE.md|README.md|build.sh)
      ;;
    *)
      fail "Unexpected tracked root-level path: $path. Move active source to a layer or historical artifacts to archive/."
      ;;
  esac
done < <(git -C "$ROOT_DIR" ls-files)

if (( errors > 0 )); then
  echo "Architecture guardrails failed with $errors issue(s)." >&2
  exit 1
fi

echo "Architecture guardrails passed."
