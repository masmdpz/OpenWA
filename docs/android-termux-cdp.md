# Chrome Android CDP from Termux (experimental)

This helper forwards the Chrome Android DevTools Protocol (CDP) socket to a loopback TCP port on the **same phone**. It uses Android Wireless Debugging through Termux's ADB client; it does not need a PC, root, or access to Chrome's private profile files.

## Prerequisites

- Termux with the `android-tools` and `curl` packages.
- Chrome for Android open, with the WhatsApp Web tab already logged in.
- Android Developer Options and Wireless Debugging enabled.

In Termux, install the required command-line tools:

```sh
pkg install android-tools curl
```

Run the helper from the OpenWA checkout:

```sh
bash scripts/android-chrome-cdp-termux.sh
```

When prompted, enter the **pairing port + six-digit pairing code** from Android's "Pair device with pairing code" screen. Then enter the separate **IP address & port** shown on the main Wireless Debugging screen. For a same-phone ADB connection, the script uses `127.0.0.1`.

The script forwards Chrome's `localabstract:chrome_devtools_remote` socket to `127.0.0.1:9222` and checks `/json/version`. This follows Chrome's documented CDP socket-forwarding mechanism; the same-phone localhost ADB pairing method is an experimental Termux workflow.

## Important limitations

- **This only makes CDP available locally on the phone.** OpenWA must also run on that same phone and use `PUPPETEER_BROWSER_URL=http://127.0.0.1:9222`. A Hugging Face Space or other remote OpenWA server cannot reach the phone's `127.0.0.1`.
- To keep OpenWA hosted remotely, a separate authenticated reverse-tunnel service is required. This helper does not create that tunnel.
- Puppeteer's support for Chrome on Android is experimental; the WhatsApp Web.js integration still needs a real-device test.
- Keep the forwarded port loopback-only. CDP grants control over the browser and every logged-in tab. Never publish port 9222 or an unauthenticated CDP endpoint.

References:
- [Chrome DevTools: Remote debug Android devices](https://developer.chrome.com/docs/devtools/remote-debugging) — documents forwarding `localabstract:chrome_devtools_remote`.
- [Termux ADB localhost pairing notes](https://gist.github.com/avoidik/94aa216d2777da0a878e24de0186c534) — community-documented same-device Wireless Debugging workflow.
