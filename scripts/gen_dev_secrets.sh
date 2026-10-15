#!/bin/sh
# Writes Apps/Shared/DevSecrets.generated.swift (gitignored) from .env for Debug device testing.
# The key ends up in the Debug binary; never use this for distributed builds.
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/Apps/Shared/DevSecrets.generated.swift"
key=""
if [ "${CONFIGURATION:-Debug}" = "Debug" ] && [ -f "$root/.env" ]; then
  key="$(grep '^OPENAI_API_KEY=' "$root/.env" | head -1 | cut -d= -f2- | tr -d "\"' ")"
fi
content="enum DevSecrets { static let openAIKey = \"$key\" }"
[ -f "$out" ] && [ "$(cat "$out")" = "$content" ] && exit 0
printf '%s' "$content" > "$out"
