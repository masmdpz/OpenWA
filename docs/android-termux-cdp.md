# Chrome Android CDP from Termux

This helper forwards the DevTools Protocol (CDP) socket from Chrome for Android to a loopback TCP port on the same phone. It uses Android Wireless Debugging through Termux's ADB client. It does not need a PC, root access, or access to Chrome's private profile files.

## Prerequisites

- Termux with the `android-tools`, `curl`, and (for remote hosting) `cloudflared` packages.
- Chrome for Android open with the WhatsApp Web tab already logged in.
- Android Developer Options and Wireless Debugging enabled.

Install the packages:

```sh
pkg update
pkg install android-tools curl cloudflared
```

Run the helper from the OpenWA checkout:

```sh
bash scripts/android-chrome-cdp-termux.sh
```

The helper asks for the pairing port and six-digit code from Android's **Pair device with pairing code** screen, then the connection port from the main **Wireless debugging** screen. The same-device Termux ADB workflow uses `127.0.0.1`.

The helper then forwards Chrome's `localabstract:chrome_devtools_remote` socket to `127.0.0.1:9222` and checks `/json/version`. Chrome's documented manual CDP workflow uses this same ADB socket-forwarding method. <https://developer.chrome.com/docs/devtools/remote-debugging>

## Same-phone OpenWA

If OpenWA itself runs locally on the same phone, configure:

```dotenv
PUPPETEER_BROWSER_URL=http://127.0.0.1:9222
```

This is a local-only setup. A Hugging Face Space or other remote OpenWA host cannot reach the phone's `127.0.0.1`.

## Remote OpenWA through an authenticated tunnel

To keep OpenWA hosted remotely, use a **named, remotely managed Cloudflare Tunnel**. This requires a domain active in Cloudflare and a Cloudflare Zero Trust account.

1. In Cloudflare Zero Trust, create a remotely managed tunnel.
2. Add a published application route for a hostname such as `cdp.example.com`, with the service URL set to `http://127.0.0.1:9222`.
3. Create a Cloudflare Access **Self-hosted** application for that hostname. Add a **Service Auth** policy that allows only a dedicated Service Token. Do this before starting the tunnel. Do not leave the hostname publicly accessible without Access.
4. Create a Service Token for the Access policy. Keep its Client ID and Client Secret private.
5. Run the helper again and choose to start the already-configured, Access-protected tunnel. Enter the tunnel token when prompted. The script stores it in a temporary owner-only file and removes the file when the tunnel process exits.
6. In the remote OpenWA host's protected environment/secrets, set the WebSocket endpoint printed by the helper and the Access headers:

```dotenv
PUPPETEER_BROWSER_WS_ENDPOINT=wss://cdp.example.com/devtools/browser/REPLACE_WITH_BROWSER_ID
PUPPETEER_BROWSER_WS_HEADERS_JSON={"CF-Access-Client-Id":"<service-token-id>","CF-Access-Client-Secret":"<service-token-secret>"}
```

The endpoint path includes the browser ID read from the phone's local `/json/version` response. The header JSON must be entered as one environment value. Store it in the OpenWA host's secret manager, not in a committed `.env` file.

Cloudflare Tunnel creates an outbound connection from the phone and routes requests from the configured public hostname to the local service. Cloudflare Access Service Tokens authenticate service-to-service requests. Puppeteer 25 supports custom WebSocket handshake headers through `wsOptions.headers`; OpenWA forwards these only in CDP connect mode. <https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/> <https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/> <https://pptr.dev/api/puppeteer.connectoptions>

## Security and compatibility

- **Never expose CDP without authentication.** CDP grants control over Chrome and every logged-in tab. Use Cloudflare Access with a dedicated Service Token and keep the token secrets private.
- Keep the ADB-forwarded port loopback-only. Do not bind or publish port 9222 to Wi-Fi or the public internet.
- Keep Chrome and Termux running. Android battery management may stop background processes; exempt Termux from battery optimization and keep the phone powered while the session is needed.
- This is an experimental integration. Puppeteer does not officially support Chrome on Android as a target, so WhatsApp Web.js compatibility must be confirmed on the actual phone and Chrome version.
- If the OpenWA host is remote, it must be able to reach the protected Cloudflare hostname over the internet. This does not make the Chrome profile available to other devices directly.

