#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

readonly APP_NAME="openwa"
readonly IMAGE="ghcr.io/masmdpz/openwa:7f8d3fb"
readonly CONFIG_DIR="${HOME}/.config/openwa"
readonly KEY_FILE="${CONFIG_DIR}/api-master-key"
readonly HEALTH_URL="http://127.0.0.1:2785/api/health/ready"

fail() {
  printf 'ERROR: %s\\n' "$*" >&2
  exit 1
}

info() {
  printf '[OpenWA] %s\\n' "$*"
}

require_termux() {
  [[ -n "${PREFIX:-}" && -x "${PREFIX}/bin/pkg" ]] || fail "Jalankan skrip ini dari aplikasi Termux, bukan terminal Linux biasa."
}

ensure_host_tools() {
  if ! command -v proot-distro >/dev/null 2>&1 || ! command -v openssl >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    info "Memasang PRoot-Distro, OpenSSL, dan curl..."
    pkg update -y
    pkg install -y proot-distro openssl curl
  fi
  command -v proot-distro >/dev/null 2>&1 || fail "proot-distro belum tersedia setelah instalasi."
}

container_exists() {
  proot-distro list --quiet | grep -Fxq "$APP_NAME"
}

require_container() {
  command -v proot-distro >/dev/null 2>&1 || fail "Jalankan perintah install terlebih dahulu."
  container_exists || fail "Image OpenWA belum dipasang. Jalankan: $0 install"
}

ensure_key() {
  umask 077
  mkdir -p "$CONFIG_DIR"
  if [[ ! -s "$KEY_FILE" ]]; then
    openssl rand -hex 32 > "${KEY_FILE}.tmp"
    mv "${KEY_FILE}.tmp" "$KEY_FILE"
  fi
  chmod 600 "$KEY_FILE"
}

api_ready() {
  curl -fsS --max-time 3 -o /dev/null "$HEALTH_URL"
}

env_args() {
  local api_key
  api_key="$(cat "$KEY_FILE")"
  ENV_ARGS=(
    --env "NODE_ENV=production"
    --env "PORT=2785"
    --env "API_MASTER_KEY=${api_key}"
    --env "ENGINE_TYPE=baileys"
    --env "DATABASE_TYPE=sqlite"
    --env "TZ=Asia/Jakarta"
  )
}

cmd_install() {
  require_termux
  ensure_host_tools
  ensure_key
  if container_exists; then
    info "Image OpenWA sudah terpasang. Data yang ada tidak diubah."
  else
    info "Mengunduh image ARM64 OpenWA dari GHCR. Ini bisa memerlukan beberapa GB ruang penyimpanan."
    proot-distro install "$IMAGE" --name "$APP_NAME" --architecture aarch64
  fi
  info "Instalasi selesai. Jalankan: $0 start"
  info "API key disimpan secara lokal di: $KEY_FILE"
}

cmd_start() {
  require_termux
  require_container
  ensure_key
  if api_ready; then
    info "OpenWA sudah berjalan di http://127.0.0.1:2785"
    return 0
  fi
  env_args
  info "Menyalakan OpenWA di latar belakang..."
  proot-distro run --detach "${ENV_ARGS[@]}" "$APP_NAME"
  for _ in {1..45}; do
    if api_ready; then
      info "OpenWA siap di http://127.0.0.1:2785"
      info "Lihat API key dengan: $0 key"
      return 0
    fi
    sleep 2
  done
  info "Belum menerima respons health-check. Detail proses:"
  proot-distro ps || true
  info "Untuk melihat log langsung, jalankan: $0 foreground"
  return 1
}

cmd_foreground() {
  require_termux
  require_container
  ensure_key
  env_args
  info "Menjalankan OpenWA di depan terminal. Tekan Ctrl+C untuk menghentikannya."
  proot-distro run "${ENV_ARGS[@]}" "$APP_NAME"
}

cmd_status() {
  require_termux
  if api_ready; then
    info "OpenWA merespons di http://127.0.0.1:2785"
  else
    info "OpenWA tidak merespons pada port 2785. Sesi PRoot yang aktif:"
    if command -v proot-distro >/dev/null 2>&1; then
      proot-distro ps || true
    else
      info "Termux belum memasang PRoot-Distro."
    fi
  fi
}

cmd_stop() {
  require_termux
  require_container
  proot-distro kill "$APP_NAME" || true
  info "Semua proses PRoot untuk OpenWA sudah dihentikan. Data /app/data tetap tersimpan."
}

cmd_key() {
  require_termux
  [[ -s "$KEY_FILE" ]] || fail "API key belum dibuat. Jalankan: $0 install"
  cat "$KEY_FILE"
  printf '\\n'
}

cmd_tunnel() {
  require_termux
  require_container
  api_ready || fail "OpenWA belum berjalan. Jalankan: $0 start"
  info "Menyiapkan Cloudflare Quick Tunnel. URL bersifat sementara dan siapa pun yang memiliki URL dapat mencobanya."
  proot-distro login "$APP_NAME" -- /bin/sh -lc '
    set -eu
    if [ ! -x /usr/local/bin/cloudflared ]; then
      curl -fL --retry 3 https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -o /usr/local/bin/cloudflared
      chmod 755 /usr/local/bin/cloudflared
    fi
    exec /usr/local/bin/cloudflared tunnel --url http://127.0.0.1:2785
  '
}

cmd_backup() {
  require_termux
  require_container
  local backup_file
  backup_file="${HOME}/openwa-backup-$(date +%Y%m%d-%H%M%S).tar.xz"
  info "Membuat arsip rootfs beserta data sesi. Pastikan ruang penyimpanan cukup."
  proot-distro backup "$APP_NAME" --output "$backup_file" --compress xz
  chmod 600 "$backup_file"
  info "Backup tersimpan di: $backup_file"
}

usage() {
  cat <<USAGE
Penggunaan: $0 {install|start|foreground|status|stop|key|tunnel|backup}

  install     Pasang PRoot-Distro dan image OpenWA ARM64.
  start       Jalankan OpenWA di latar belakang.
  foreground  Jalankan OpenWA dan tampilkan log langsung.
  status      Periksa health-check dan proses PRoot.
  stop        Hentikan proses OpenWA tanpa menghapus datanya.
  key         Tampilkan API_MASTER_KEY lokal.
  tunnel      Buka URL sementara Cloudflare untuk akses jarak jauh.
  backup      Arsipkan container, konfigurasi, dan data sesi.
USAGE
}

main() {
  local action="${1:-help}"
  case "$action" in
    install) cmd_install ;;
    start) cmd_start ;;
    foreground) cmd_foreground ;;
    status) cmd_status ;;
    stop) cmd_stop ;;
    key) cmd_key ;;
    tunnel) cmd_tunnel ;;
    backup) cmd_backup ;;
    help|-h|--help) usage ;;
    *) usage >&2; fail "Perintah tidak dikenal: $action" ;;
  esac
}

main "$@"