# Android Phone Hosting with Termux (Experimental)

This is a zero-VPS, zero-Docker-daemon option for testing OpenWA on an Android ARM64 phone. The phone itself runs the published ARM64 OpenWA image through Termux and PRoot-Distro.

**This is not cloud hosting.** The phone must remain powered on and connected to the internet. Android may suspend or terminate background processes, so this is best for personal testing or light use, not a production service.

## Requirements

- An Android ARM64 phone with several GB of free internal storage.
- Termux from [F-Droid](https://f-droid.org/packages/com.termux/) or the [official Termux GitHub releases](https://github.com/termux/termux-app/releases). Do not mix Termux and add-on apps from different installation sources.
- A stable Wi-Fi connection is recommended for the initial image download and normal hosting.

PRoot-Distro imports Docker/OCI images directly and runs them without root access or a Docker daemon. See the [PRoot-Distro documentation](https://github.com/termux/proot-distro).

## Install

Open Termux and run:

```sh
pkg update -y
pkg install -y curl
curl -fsSL https://raw.githubusercontent.com/masmdpz/OpenWA/main/scripts/termux-openwa.sh -o "$HOME/termux-openwa.sh"
chmod 700 "$HOME/termux-openwa.sh"
"$HOME/termux-openwa.sh" install
```

The helper installs PRoot-Distro, downloads the ARM64 image `ghcr.io/masmdpz/openwa:7f8d3fb`, and generates a random `API_MASTER_KEY`. The key is stored locally at `~/.config/openwa/api-master-key` with owner-only file permissions.

Then start OpenWA:

```sh
"$HOME/termux-openwa.sh" start
```

Open the dashboard on the same phone at:

`http://127.0.0.1:2785`

Read the generated key with:

```sh
"$HOME/termux-openwa.sh" key
```

Keep this key private. Do not paste it into public chats, screenshots, or GitHub commits.

## Commands

```sh
"$HOME/termux-openwa.sh" status
"$HOME/termux-openwa.sh" stop
"$HOME/termux-openwa.sh" start
"$HOME/termux-openwa.sh" backup
```

The container's `/app/data` directory lives inside the persistent PRoot-Distro installation. It holds OpenWA data, including linked-session credentials. The backup command archives the container root filesystem. Keep a backup somewhere outside the phone too.

**Do not run `proot-distro reset openwa` or `proot-distro remove openwa` unless you intend to erase the stored OpenWA data and linked sessions.**

## Optional remote access

To expose the dashboard/API outside the phone for a temporary test, run:

```sh
"$HOME/termux-openwa.sh" tunnel
```

This uses a Cloudflare Quick Tunnel. It creates a random public `trycloudflare.com` URL without requiring a Cloudflare account or a domain. Anyone who has that URL can reach the service, so keep the URL private and protect all API access with the generated key.

Quick Tunnels are for testing, not production: the URL changes when the process restarts, there is no uptime guarantee, they do not support Server-Sent Events, and each tunnel is limited to 200 in-flight requests. See [Cloudflare Quick Tunnels](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/).

## Android background limits

Termux is an ordinary Android app. One UI battery management may stop its background process. Set Termux's battery usage to **Unrestricted** in Android settings. If the phone stops the server while the screen is off, the Termux `termux-wake-lock` command can hold a partial wake lock, but this increases battery use and heat. Do not leave the phone hot or unattended while charging.

This setup does not guarantee 24/7 uptime. After a phone reboot, open Termux and run the `start` command again.

## WhatsApp risk

OpenWA uses unofficial, reverse-engineered WhatsApp clients; account restrictions are possible. The repository's risk guidance rates Baileys as having a higher account-restriction risk than `whatsapp-web.js`. Use only an account you are prepared to lose, and do not use this setup for unsolicited bulk messages. Phone-number pairing with Baileys avoids the specific existing-linked-device revocation issue documented for `whatsapp-web.js`, but it does not make the account risk-free.
