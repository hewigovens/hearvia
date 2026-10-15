#!/bin/sh
# Writes Apps/Shared/DevSecrets.generated.swift (gitignored) from .env for Debug device testing.
# The key ends up in the Debug binary only: Release builds write an empty key, and the generated
# file also compiles the key out of non-Debug builds in case a stale Debug file is ever compiled for Release.
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/Apps/Shared/DevSecrets.generated.swift"
key=""
if [ "${CONFIGURATION:-Debug}" = "Debug" ] && [ -f "$root/.env" ]; then
  key="$(grep '^OPENAI_API_KEY=' "$root/.env" | head -1 | cut -d= -f2- | tr -d "\"' ")"
fi
content="enum DevSecrets {
    #if DEBUG
        static let openAIKey = \"$key\"
    #else
        static let openAIKey = \"\"
    #endif
}"
mkdir -p "$(dirname "$out")"
[ -f "$out" ] && [ "$(cat "$out")" = "$content" ] && exit 0
printf '%s\n' "$content" > "$out"
