#!/data/data/com.termux/files/usr/bin/bash
# Install OpenWA on Android using Termux + Debian PRoot.
# No root, Docker, VPS, or paid hosting required.
set -Eeuo pipefail

if [[ -z "${TERMUX_VERSION:-}" || -z "${PREFIX:-}" ]]; then
  echo "Run this script inside the official Termux app." >&2
  exit 1
fi

case "$(uname -m)" in
  aarch64|arm64) ;;
  *)
    echo "This installer currently supports 64-bit ARM Android only." >&2
    exit 1
    ;;
esac

echo "[1/4] Installing Termux tools..."
pkg update -y
pkg install -y proot-distro git curl cloudflared

echo "[2/4] Preparing Debian..."
if ! proot-distro login debian -- /bin/true >/dev/null 2>&1; then
  proot-distro install debian
fi

echo "[3/4] Installing OpenWA in Debian..."
proot-distro login debian -- bash -s <<'DEBIAN_SETUP'
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates curl git xz-utils python3 build-essential pkg-config patch ffmpeg

NODE_VERSION="24.22.2"
NODE_ARCHIVE="node-v${NODE_VERSION}-linux-arm64.tar.xz"
NODE_DIR="/opt/node-v${NODE_VERSION}-linux-arm64"

if [[ ! -x "${NODE_DIR}/bin/node" ]]; then
  cd /tmp
  curl -fSLO "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt"
  curl -fSLO "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_ARCHIVE}"
  grep " ${NODE_ARCHIVE}\$" SHASUMS256.txt | sha256sum -c -
  tar -xJf "${NODE_ARCHIVE}" -C /opt
  rm -f "${NODE_ARCHIVE}" SHASUMS256.txt
fi

ln -sfn "${NODE_DIR}/bin/node" /usr/local/bin/node
ln -sfn "${NODE_DIR}/bin/npm" /usr/local/bin/npm
ln -sfn "${NODE_DIR}/bin/npx" /usr/local/bin/npx

node --version
npm --version

if [[ ! -d /opt/openwa/.git ]]; then
  git clone --depth 1 --branch main https://github.com/masmdpz/OpenWA.git /opt/openwa
else
  git -C /opt/openwa pull --ff-only origin main
fi

cd /opt/openwa
export PUPPETEER_SKIP_DOWNLOAD=true
npm ci
npm run build:all

mkdir -p data
chmod 700 data
if [[ ! -f .env ]]; then
  cat > .env <<'OPENWA_ENV'
NODE_ENV=production
PORT=2785
TZ=Asia/Jakarta
DATABASE_TYPE=sqlite
OPENWA_ENV
  chmod 600 .env
fi

cat > /usr/local/bin/openwa-start <<'OPENWA_START'
#!/usr/bin/env bash
set -Eeuo pipefail
cd /opt/openwa
export NODE_ENV=production
export PORT=2785
export TZ=Asia/Jakarta
exec node dist/main
OPENWA_START
chmod 755 /usr/local/bin/openwa-start
DEBIAN_SETUP

echo "[4/4] Creating Termux commands..."
cat > "${PREFIX}/bin/openwa" <<'OPENWA_CMD'
#!/data/data/com.termux/files/usr/bin/bash
exec proot-distro login debian -- /usr/local/bin/openwa-start
OPENWA_CMD

cat > "${PREFIX}/bin/openwa-tunnel" <<'TUNNEL_CMD'
#!/data/data/com.termux/files/usr/bin/bash
exec cloudflared tunnel --url http://127.0.0.1:2785
TUNNEL_CMD

cat > "${PREFIX}/bin/openwa-key" <<'KEY_CMD'
#!/data/data/com.termux/files/usr/bin/bash
exec proot-distro login debian -- cat /opt/openwa/data/.api-key
KEY_CMD

cat > "${PREFIX}/bin/openwa-update" <<'UPDATE_CMD'
#!/data/data/com.termux/files/usr/bin/bash
set -e
proot-distro login debian -- bash -lc '
  set -e
  cd /opt/openwa
  git pull --ff-only origin main
  export PUPPETEER_SKIP_DOWNLOAD=true
  npm ci
  npm run build:all
'
UPDATE_CMD

chmod 755 "${PREFIX}/bin/openwa" "${PREFIX}/bin/openwa-tunnel" \
  "${PREFIX}/bin/openwa-key" "${PREFIX}/bin/openwa-update"

cat <<'DONE'

OpenWA has been installed.

Next:
  1. In this Termux session, run:  openwa
  2. Open a NEW Termux session and run:  openwa-tunnel
  3. Copy the https://....trycloudflare.com URL printed by cloudflared.
  4. After OpenWA finishes its first boot, get its admin API key with:  openwa-key

The OpenWA data directory is /opt/openwa/data inside Debian.
Keep the phone powered, online, and Termux allowed to run in the background.
DONE
