#!/bin/sh
# Writes Apps/Shared/DevSecrets.generated.swift (gitignored) from .env for Debug device testing.
# The keys end up in the Debug binary only: Release builds write empty keys, and the generated
# file also compiles the keys out of non-Debug builds in case a stale Debug file is ever compiled for Release.
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$root/Apps/Shared/DevSecrets.generated.swift"
openai=""
gemini=""
if [ "${CONFIGURATION:-Debug}" = "Debug" ] && [ -f "$root/.env" ]; then
  openai="$(grep '^OPENAI_API_KEY=' "$root/.env" | head -1 | cut -d= -f2- | tr -d "\"' ")"
  gemini="$(grep '^GEMINI_API_KEY=' "$root/.env" | head -1 | cut -d= -f2- | tr -d "\"' ")"
fi
content="enum DevSecrets {
    #if DEBUG
        static let openAIKey = \"$openai\"
        static let geminiKey = \"$gemini\"
    #else
        static let openAIKey = \"\"
        static let geminiKey = \"\"
    #endif
}"
mkdir -p "$(dirname "$out")"
[ -f "$out" ] && [ "$(cat "$out")" = "$content" ] && exit 0
printf '%s\n' "$content" > "$out"
