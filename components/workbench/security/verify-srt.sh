#!/usr/bin/env bash
# Test inside workbench: verify-srt
# Launch must succeed BEFORE we interpret a denied read/write as enforcement.
set -euo pipefail
tempdir="$(mktemp -d /workspace/.srt-check.XXXXXXXX)"
trap 'rm -rf "$tempdir"' EXIT
mkdir -p "$tempdir/secrets"
printf 'protected-test-value\n' > "$tempdir/.env"
printf 'original-test-value\n' > "$tempdir/secrets/locked.txt"

echo "[1/3] Sandbox must launch"
srt --settings /etc/srt-settings.json sh -c 'echo sandbox-launched' ||
  { echo "FAIL: SRT could not start" >&2; exit 1; }

echo "[2/3] Nested .env must be unreadable"
if srt --settings /etc/srt-settings.json cat "$tempdir/.env" >/dev/null 2>&1; then
  echo "FAIL: protected .env readable" >&2; exit 1
fi

echo "[3/3] Secrets path must be read-only"
if srt --settings /etc/srt-settings.json sh -c 'echo changed > "$1"' _ "$tempdir/secrets/locked.txt" >/dev/null 2>&1; then
  echo "FAIL: protected secrets file writable" >&2; exit 1
fi
test "$(cat "$tempdir/secrets/locked.txt")" = "original-test-value" ||
  { echo "FAIL: protected file changed" >&2; exit 1; }
echo "PASS: sandbox launched; test read/write denials enforced."
