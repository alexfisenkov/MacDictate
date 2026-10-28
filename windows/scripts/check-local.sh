#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ -x "$root/.local/dotnet/dotnet" ]]; then sdk="$root/.local/dotnet/dotnet"; else sdk="$(command -v dotnet)"; fi
cd "$root/windows"
"$sdk" run --project tests/MacDictate.Core.Tests/MacDictate.Core.Tests.csproj -c Release
"$sdk" build src/MacDictate.Windows/MacDictate.Windows.csproj -c Release --nologo
