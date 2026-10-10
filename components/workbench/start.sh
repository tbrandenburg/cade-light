#!/usr/bin/env bash
set -euo pipefail

code-server \
  --bind-addr 0.0.0.0:8080 \
  --auth password /workspace &
code_pid=$!

jupyter lab \
  --ip=0.0.0.0 --port=8888 \
  --no-browser \
  --ServerApp.root_dir=/workspace \
  --IdentityProvider.token="$JUPYTER_TOKEN" &
jupyter_pid=$!

node-red --settings /etc/node-red/settings.js &
node_red_pid=$!

cleanup() {
  kill "$code_pid" "$jupyter_pid" "$node_red_pid" 2>/dev/null || true
  wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM
wait -n "$code_pid" "$jupyter_pid" "$node_red_pid"
