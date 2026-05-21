#!/bin/sh
set -eu

url="${1:?URL required}"
max="${2:-60}"
attempt=0

while [ "$attempt" -lt "$max" ]; do
  if curl -sf "$url" >/dev/null; then
    exit 0
  fi
  attempt=$((attempt + 1))
  sleep 2
done

echo "Timeout: $url not ready after ${max} attempts" >&2
exit 1
