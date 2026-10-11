#!/usr/bin/env bash
# Local, offline GitOps deployment test; no Docker or network required.
set -euo pipefail
script="$(cd "$(dirname "$0")/.." && pwd)/components/workbench/prepare-node-red-flows.sh"
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/state" "$root/bundled" "$root/host" "$root/work"
printf '[{"id":"bundled"}]\n' > "$root/bundled/flows.json"
printf '[{"id":"host"}]\n' > "$root/host/flows.json"

run() {
  NODE_RED_USER_DIR="$root/state" \
  NODE_RED_BUNDLED_FLOWS_DIR="$root/bundled" \
  NODE_RED_HOST_FLOWS_DIR="$root/host" \
  "$script"
}

NODE_RED_FLOWS_SOURCE=bundled run
grep -q '"id":"bundled"' "$root/state/flows.json"
printf 'encrypted-credentials\n' > "$root/state/flows_cred.json"
printf '[{"id":"unsynced-editor-change"}]\n' > "$root/state/flows.json"
NODE_RED_FLOWS_SOURCE=bundled run
grep -q '"id":"bundled"' "$root/state/flows.json"
grep -q 'unsynced-editor-change' "$root/state"/.cade-flow-backups/*
test "$(cat "$root/state/flows_cred.json")" = encrypted-credentials
NODE_RED_FLOWS_SOURCE=host run
grep -q '"id":"host"' "$root/state/flows.json"

git init -q -b main "$root/work"
git -C "$root/work" config user.name "CI"
git -C "$root/work" config user.email "ci@example.invalid"
printf '[{"id":"main"}]\n' > "$root/work/flows.json"
git -C "$root/work" add flows.json
git -C "$root/work" commit -qm initial
main_sha="$(git -C "$root/work" rev-parse HEAD)"
git -C "$root/work" tag v1
git -C "$root/work" checkout -qb feature
printf '[{"id":"feature"}]\n' > "$root/work/flows.json"
git -C "$root/work" commit -qam feature
git init --bare -q "$root/remote.git"
git -C "$root/work" remote add origin "$root/remote.git"
git -C "$root/work" push -q origin main feature --tags

NODE_RED_FLOWS_SOURCE=git NODE_RED_GIT_URL="$root/remote.git" NODE_RED_GIT_REF=feature run
grep -q '"id":"feature"' "$root/state/flows.json"
NODE_RED_FLOWS_SOURCE=git NODE_RED_GIT_URL="$root/remote.git" NODE_RED_GIT_REF=v1 run
grep -q '"id":"main"' "$root/state/flows.json"
NODE_RED_FLOWS_SOURCE=git NODE_RED_GIT_URL="$root/remote.git" NODE_RED_GIT_REF="$main_sha" run
grep -q "$main_sha" "$root/state/.cade-flow-revision"

before="$(sha256sum "$root/state/flows.json" | cut -d' ' -f1)"
if NODE_RED_FLOWS_SOURCE=git NODE_RED_GIT_URL="$root/remote.git" NODE_RED_GIT_REF=missing run; then
  echo "FAIL: missing Git revision accepted" >&2; exit 1
fi
if NODE_RED_FLOWS_SOURCE=git NODE_RED_GIT_URL= run; then
  echo "FAIL: missing Git URL accepted" >&2; exit 1
fi
if NODE_RED_FLOWS_SOURCE=bundled NODE_RED_FLOW_PATH=../escape.json run; then
  echo "FAIL: source path traversal accepted" >&2; exit 1
fi
printf '{broken\n' > "$root/bundled/flows.json"
if NODE_RED_FLOWS_SOURCE=bundled run; then
  echo "FAIL: invalid JSON accepted" >&2; exit 1
fi
test "$(sha256sum "$root/state/flows.json" | cut -d' ' -f1)" = "$before"
echo "PASS: source selection, Git branches/tags/commit, preservation and failure protection"
