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

command -v adb >/dev/null 2>&1 || fail "adb not found. In Termux run: pkg install android-tools"
command -v curl >/dev/null 2>&1 || fail "curl not found. In Termux run: pkg install curl"
valid_port "$CDP_PORT" || fail "CDP_PORT must be a valid TCP port number."

printf '%s\n'   "Open Android Settings > Developer options > Wireless debugging."   "Turn Wireless debugging on, then open 'Pair device with pairing code'."   "Keep that Android screen visible (split-screen works)."   ""

read -r -p "Pairing port shown in the pairing dialog: " PAIR_PORT
valid_port "$PAIR_PORT" || fail "Invalid pairing port."
read -r -s -p "6-digit pairing code: " PAIR_CODE
printf '\n'
[[ "$PAIR_CODE" =~ ^[0-9]{6}$ ]] || fail "Pairing code must contain exactly six digits."

printf '\nPairing this phone's local ADB service...\n'
adb pair "127.0.0.1:$PAIR_PORT" "$PAIR_CODE" || fail "ADB pairing failed. Re-open the pairing-code dialog and try again."

read -r -p "Connection port shown on the main Wireless debugging screen: " CONNECT_PORT
valid_port "$CONNECT_PORT" || fail "Invalid connection port."

printf '\nConnecting to this phone...\n'
adb connect "127.0.0.1:$CONNECT_PORT" || fail "ADB connection failed. Check that Wireless debugging is still enabled."

printf '\nForwarding Chrome DevTools Protocol to localhost:$CDP_PORT...\n'
adb forward --remove "tcp:$CDP_PORT" >/dev/null 2>&1 || true
adb forward "tcp:$CDP_PORT" localabstract:chrome_devtools_remote || fail "Could not forward Chrome's DevTools socket."

VERSION_JSON="$(curl --fail --silent --show-error --max-time 8 "http://127.0.0.1:$CDP_PORT/json/version")" || fail "Chrome CDP did not answer. Open Chrome and keep its WhatsApp Web tab active."
[[ "$VERSION_JSON" == *'"webSocketDebuggerUrl"'* ]] || fail "The response is not a Chrome browser CDP endpoint."

printf '\n%s\n'   "SUCCESS: Chrome CDP is reachable on this phone at http://127.0.0.1:$CDP_PORT"   "OpenWA must run on this same phone to use that localhost endpoint."   "Do not expose this port to Wi-Fi or the public internet; CDP can control the browser."
