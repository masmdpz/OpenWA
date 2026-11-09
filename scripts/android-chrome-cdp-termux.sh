#!/usr/bin/env bash
set -Eeuo pipefail

CDP_PORT="${CDP_PORT:-9222}"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

valid_port() {
  [[ "$1" =~ ^[0-9]{1,5}$ ]] && (( 10#$1 >= 1 && 10#$1 <= 65535 ))
}

command -v adb >/dev/null 2>&1 || fail "adb not found. Run: pkg install android-tools"
command -v curl >/dev/null 2>&1 || fail "curl not found. Run: pkg install curl"
valid_port "$CDP_PORT" || fail "CDP_PORT must be a valid TCP port number."

printf '%s\n' \
  "Open Android Settings > Developer options > Wireless debugging." \
  "Enable Wireless debugging, then open Pair device with pairing code." \
  "Keep that pairing screen visible while entering the code below." \
  ""

read -r -p "Pairing port shown in the pairing dialog: " PAIR_PORT
valid_port "$PAIR_PORT" || fail "Invalid pairing port."
read -r -s -p "Six-digit pairing code: " PAIR_CODE
printf '\n'
[[ "$PAIR_CODE" =~ ^[0-9]{6}$ ]] || fail "The pairing code must contain exactly six digits."

printf '\nPairing the local ADB service...\n'
adb pair "127.0.0.1:$PAIR_PORT" "$PAIR_CODE" || fail "ADB pairing failed. Reopen the pairing-code dialog and retry."

read -r -p "Connection port from the main Wireless debugging screen: " CONNECT_PORT
valid_port "$CONNECT_PORT" || fail "Invalid connection port."

printf '\nConnecting to this phone...\n'
adb connect "127.0.0.1:$CONNECT_PORT" || fail "ADB connection failed. Check that Wireless debugging is enabled."

printf "\nForwarding Chrome DevTools Protocol to localhost:%s...\n" "$CDP_PORT"
adb forward --remove "tcp:$CDP_PORT" >/dev/null 2>&1 || true
adb forward "tcp:$CDP_PORT" localabstract:chrome_devtools_remote || fail "Could not forward the Chrome DevTools socket."

VERSION_JSON="$(curl --fail --silent --show-error --max-time 8 "http://127.0.0.1:$CDP_PORT/json/version")" || fail "Chrome CDP did not answer. Open Chrome and keep the WhatsApp Web tab active."
[[ "$VERSION_JSON" == *'"webSocketDebuggerUrl"'* ]] || fail "The response is not a Chrome browser CDP endpoint."

WS_PATH="$(printf '%s' "$VERSION_JSON" | sed -n 's#.*"webSocketDebuggerUrl"[[:space:]]*:[[:space:]]*"[^"]*\(/devtools/browser/[^"]*\)".*#\1#p')"
[[ "$WS_PATH" == /devtools/browser/* ]] || fail "Could not read the browser WebSocket path from /json/version."

printf '\n%s\n' \
  "SUCCESS: Chrome CDP is reachable locally at http://127.0.0.1:$CDP_PORT" \
  "Browser WebSocket path: $WS_PATH" \
  "For OpenWA on this same phone, use PUPPETEER_BROWSER_URL=http://127.0.0.1:$CDP_PORT." \
  "Do not publish port 9222 or expose CDP without authentication." \
  ""

printf '%s\n' \
  "Remote OpenWA option: configure a named Cloudflare Tunnel with its origin set to" \
  "http://127.0.0.1:$CDP_PORT, then protect its public hostname with a Cloudflare Access" \
  "Service Auth policy and a Service Token. Do not start an unprotected public tunnel." \
  ""

if ! command -v cloudflared >/dev/null 2>&1; then
  printf '%s\n' "To install the official Termux package, run: pkg install cloudflared"
  exit 0
fi

read -r -p "Start an already-configured, Access-protected Cloudflare Tunnel now? [y/N]: " START_TUNNEL
case "$START_TUNNEL" in
  y|Y|yes|YES) ;;
  *) exit 0 ;;
esac

read -r -p "Public hostname configured for this tunnel (for example cdp.example.com): " CF_HOST
[[ "$CF_HOST" =~ ^[A-Za-z0-9.-]+$ ]] || fail "Enter only the Cloudflare public hostname, without a scheme or path."

printf '\nOpenWA WebSocket endpoint:\nwss://%s%s\n\n' "$CF_HOST" "$WS_PATH"
printf '%s\n' \
  "In the remote OpenWA environment, set:" \
  "PUPPETEER_BROWSER_WS_ENDPOINT=wss://$CF_HOST$WS_PATH" \
  'PUPPETEER_BROWSER_WS_HEADERS_JSON={"CF-Access-Client-Id":"<service-token-id>","CF-Access-Client-Secret":"<service-token-secret>"}' \
  "Store the header JSON as a secret. Never put the tunnel token or service-token secret in source code." \
  ""

read -r -s -p "Cloudflare Tunnel token: " TUNNEL_TOKEN
printf '\n'
[[ -n "$TUNNEL_TOKEN" ]] || fail "A tunnel token is required."

umask 077
TOKEN_FILE="$(mktemp "${TMPDIR:-$HOME}/openwa-cloudflared-token.XXXXXX")"
trap 'rm -f "$TOKEN_FILE"' EXIT
printf '%s' "$TUNNEL_TOKEN" > "$TOKEN_FILE"
unset TUNNEL_TOKEN

printf '\nStarting the protected Cloudflare Tunnel. Press Ctrl+C to stop it.\n'
cloudflared tunnel --no-autoupdate run --token-file "$TOKEN_FILE"
