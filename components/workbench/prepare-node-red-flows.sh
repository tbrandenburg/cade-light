#!/usr/bin/env bash
# MAINTAINER-OWNED: apply Git-backed flow definitions at startup, pull-only.
# Runtime credentials/context remain in Node-RED's persistent userDir.
set -euo pipefail
source_mode="${NODE_RED_FLOWS_SOURCE:-bundled}"
flow_path="${NODE_RED_FLOW_PATH:-flows.json}"
user_dir="${NODE_RED_USER_DIR:-/home/node/.node-red}"
bundled_dir="${NODE_RED_BUNDLED_FLOWS_DIR:-/opt/cade/bundled-flows}"
host_dir="${NODE_RED_HOST_FLOWS_DIR:-/opt/cade/host-flows}"
flow_target="$user_dir/flows.json"

die() { echo "Node-RED flow deployment: $*" >&2; exit 1; }
case "$flow_path" in
  ""|/*|..|../*|*/..|*/../*) die "NODE_RED_FLOW_PATH must stay inside the selected source directory" ;;
esac
mkdir -p "$user_dir"
chmod 700 "$user_dir"
checkout=""
cleanup() { if [[ -n "$checkout" ]]; then rm -rf "$checkout"; fi; }
trap cleanup EXIT

case "$source_mode" in
  bundled)
    root="$bundled_dir"
    revision="bundled"
    ;;
  host)
    root="$host_dir"
    revision="host"
    [[ -d "$root" ]] || die "host mode requires compose.node-red-host-flows.yaml and an existing host directory"
    ;;
  git)
    url="${NODE_RED_GIT_URL:-}"
    ref="${NODE_RED_GIT_REF:-main}"
    [[ -n "$url" ]] || die "NODE_RED_GIT_URL is required in git mode"
    [[ -n "$ref" ]] || die "NODE_RED_GIT_REF must not be empty"
    export GIT_TERMINAL_PROMPT=0
    checkout="$(mktemp -d "${TMPDIR:-/tmp}/cade-node-red-git.XXXXXXXX")"
    git clone --quiet --no-checkout -- "$url" "$checkout/repo" ||
      die "could not clone Git source; runtime flow file was left unchanged"
    root="$checkout/repo"
    revision="$(git -C "$root" rev-parse --verify --quiet "${ref}^{commit}")" ||
      revision="$(git -C "$root" rev-parse --verify --quiet "refs/remotes/origin/${ref}^{commit}")" ||
      die "Git ref '$ref' not found in source repo"
    git -C "$root" checkout --quiet --detach "$revision" ||
      die "could not check out Git commit"
    ;;
  *) die "invalid NODE_RED_FLOWS_SOURCE '$source_mode' (bundled, git, host)" ;;
esac

source_file="$(python3 - "$root" "$flow_path" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1]).resolve()
path = (root / sys.argv[2]).resolve()
if not path.is_relative_to(root) or not path.is_file():
    sys.exit("Flow path missing or escapes configured source directory")
print(path)
PY
)" || die "flow file missing or escapes configured source directory"
python3 - "$source_file" <<'PY' || die "flow file must be a valid JSON array of objects"
import json, sys
with open(sys.argv[1], encoding="utf-8") as stream:
    flows = json.load(stream)
if not isinstance(flows, list) or not all(isinstance(node, dict) for node in flows):
    raise ValueError("Node-RED flows must be a JSON array of objects")
PY

# Atomic deployment. If the existing working copy differs, back it up,
# including uncommitted edits made through the running Node-RED editor.
staged="$(mktemp "$user_dir/.flows-staged.XXXXXXXX")"
trap 'rm -f "$staged"; cleanup' EXIT
cp "$source_file" "$staged"
chmod 600 "$staged"
if [[ -f "$flow_target" ]] && ! cmp -s "$staged" "$flow_target"; then
  mkdir -p "$user_dir/.cade-flow-backups"
  chmod 700 "$user_dir/.cade-flow-backups"
  cp -p "$flow_target" "$user_dir/.cade-flow-backups/flows-$(date -u +%Y%m%dT%H%M%SZ)-$$.json"
fi
if [[ ! -f "$flow_target" ]] || ! cmp -s "$staged" "$flow_target"; then
  mv -f "$staged" "$flow_target"
else
  rm -f "$staged"
fi
printf '%s\n' "$source_mode:$revision:$flow_path" > "$user_dir/.cade-flow-revision"
echo "Node-RED flows deployed from $source_mode (revision=$revision, path=$flow_path)"
