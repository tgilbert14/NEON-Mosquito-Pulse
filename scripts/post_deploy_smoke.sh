#!/usr/bin/env bash
set -euo pipefail
pages="https://tgilbert14.github.io/NEON-Mosquito-Pulse/"
app="https://019ef0b1-0099-c999-1edc-4d47826044cc.share.connect.posit.cloud/"
for attempt in $(seq 1 30); do
  pages_body=$(curl --fail --silent --show-error --location --max-time 30 "$pages" || true)
  app_body=$(curl --fail --silent --show-error --location --max-time 60 "$app" || true)
  if grep -q 'mosquito-pulse-poster-v1' <<<"$pages_body" && grep -q 'mosquito-pulse-v1' <<<"$app_body"; then
    echo "OK: Pages poster and Connect semantic marker are live."
    exit 0
  fi
  echo "Attempt $attempt/30: waiting for exact Pages and Connect revision..."
  sleep 30
done
echo "Production did not expose both semantic markers in 15 minutes." >&2
exit 1
