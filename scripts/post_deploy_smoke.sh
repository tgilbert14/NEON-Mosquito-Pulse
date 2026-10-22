#!/usr/bin/env bash
# Prove production serves this exact revision. The app writes the md5 of its
# manifest.json into <meta name="neon-app-revision">, so a match against the
# checked-out manifest.json means Connect rebuilt from this commit, not an
# older bundle that still answers 200.
set -euo pipefail
pages="https://tgilbert14.github.io/NEON-Mosquito-Pulse/"
app="https://019ef0b1-0099-c999-1edc-4d47826044cc.share.connect.posit.cloud/"
expected=$(md5sum manifest.json | cut -d' ' -f1)
[[ "$expected" =~ ^[0-9a-f]{32}$ ]] || { echo "::error::Could not compute the md5 of manifest.json."; exit 1; }
# htmltools writes void tags as <meta ... content="x"/>; accept that and the plain ">" form.
revision_tag="<meta name=\"neon-app-revision\" content=\"${expected}\" ?/?>"
echo "Expecting Connect revision $expected (md5 of manifest.json)."
for attempt in $(seq 1 90); do
  pages_body=$(curl --fail --silent --show-error --location --max-time 30 "$pages" || true)
  app_body=$(curl --fail --silent --show-error --location --max-time 60 "$app" || true)
  missing=()
  grep -q 'mosquito-pulse-poster-v1' <<<"$pages_body" || missing+=("Pages poster marker mosquito-pulse-poster-v1")
  grep -qE "$revision_tag" <<<"$app_body" || missing+=("Connect revision meta $expected")
  grep -qF '<title>NEON Mosquito Pulse</title>' <<<"$app_body" || missing+=("Connect <title>NEON Mosquito Pulse</title>")
  grep -qE '<html[^>]* lang="en"' <<<"$app_body" || missing+=("Connect <html lang=\"en\">")
  if [ "${#missing[@]}" -eq 0 ]; then
    echo "OK: Pages poster is live and Connect serves revision $expected with its title and lang=\"en\"."
    exit 0
  fi
  printf 'Attempt %s/90: still missing: %s\n' "$attempt" "$(printf '%s; ' "${missing[@]}")"
  sleep 30
done
echo "::error title=Production revision not live::After 45 minutes, still missing: $(printf '%s; ' "${missing[@]}")expected Connect revision $expected from manifest.json."
exit 1
