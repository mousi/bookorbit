#!/usr/bin/env bash

set -euo pipefail

REMOTE_USER="${REMOTE_USER:-kostas}"
REMOTE_HOST="${REMOTE_HOST:-10.0.3.3}"
REMOTE_PLUGIN_DIR="${REMOTE_PLUGIN_DIR:-/home/kostas/dev/docker/bookorbit/bookorbit.koplugin}"
LOCAL_PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bookorbit.koplugin"
REMOTE="${REMOTE_USER}@${REMOTE_HOST}"

if [[ ! -d "$LOCAL_PLUGIN_DIR" ]]; then
  printf 'Local plugin directory does not exist: %s\n' "$LOCAL_PLUGIN_DIR" >&2
  exit 1
fi

printf 'Preparing %s\n' "$REMOTE:$REMOTE_PLUGIN_DIR"
ssh "$REMOTE" mkdir -p "$REMOTE_PLUGIN_DIR"

printf 'Streaming local plugin with tar over SSH\n'
tar -C "$LOCAL_PLUGIN_DIR" -cf - . |
  ssh "$REMOTE" "find '$REMOTE_PLUGIN_DIR' -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + && tar -xf - -C '$REMOTE_PLUGIN_DIR'"

printf 'KOReader plugin synced to %s\n' "$REMOTE:$REMOTE_PLUGIN_DIR"
