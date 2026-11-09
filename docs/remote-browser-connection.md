# Connecting the WhatsApp Web.js engine to an existing browser

The built-in `whatsapp-web.js` engine can connect to a Chromium browser that is already running with Chrome DevTools Protocol (CDP) enabled. This is an advanced deployment mode for operators who control both OpenWA and that browser.

## Configuration

Set exactly one of these fields in the built-in `whatsapp-web.js` engine configuration:

```json
{
  "puppeteer": {
    "browserURL": "http://127.0.0.1:9222"
  }
}
```

Or use a WebSocket endpoint:

```json
{
  "puppeteer": {
    "browserWSEndpoint": "ws://127.0.0.1:9222/devtools/browser/..."
  }
}
```

For environment-based deployments, set exactly one of:

```dotenv
PUPPETEER_BROWSER_URL=http://127.0.0.1:9222
# or
PUPPETEER_BROWSER_WS_ENDPOINT=ws://127.0.0.1:9222/devtools/browser/...
```

Docker Compose forwards both variables. With Helm, put the non-secret `PUPPETEER_BROWSER_URL` in the chart's `env` map; put `PUPPETEER_BROWSER_WS_ENDPOINT` in an externally managed Secret referenced by `existingSecret`, not directly in Helm values. The Infrastructure page does not expose the CDP endpoint because a WebSocket endpoint can act as a bearer capability for the whole browser; configure it through a protected server environment or secret store. The browser must be reachable from the OpenWA process. When CDP connect mode is selected, OpenWA does not launch Chromium and does not create a separate LocalAuth profile; WhatsApp Web storage comes from the connected browser profile.

### Browser setup and deployment topology

The browser process must have CDP enabled when it starts. For a dedicated Chrome/Chromium profile, launch the browser with a remote debugging port and a persistent user-data directory, for example:

```bash
google-chrome --remote-debugging-port=9222 --user-data-dir=/path/to/openwa-profile
```

Open WhatsApp Web in that profile and complete its normal login once. Keep that browser process running while OpenWA connects. The profile must be a regular persistent browser context, not an incognito window. OpenWA opens another tab in that same browser profile; it does not adopt the already-visible tab.

If OpenWA runs in Docker, a cloud container, or a Hugging Face Space while Chrome runs on a different device, `127.0.0.1` points to the OpenWA container—not the other device. Use a private network or authenticated tunnel so the OpenWA process can reach the browser's CDP endpoint. Do not publish port 9222 directly to the internet. A normal Chrome instance started without remote debugging cannot be attached retroactively; restart a browser process with CDP enabled and the profile you intend to use.

## Important limitations

- This connects to a browser on a machine/container that OpenWA can reach. It does not import a pairing code from a separate phone browser.
- Do not expose an unauthenticated CDP endpoint to the public internet. CDP grants control over the browser and its logged-in sessions. Keep it bound to loopback or behind a properly authenticated private network.
- Configure proxy/network settings on the connected browser itself. Per-session OpenWA proxy settings are not supported in this mode.
- OpenWA disconnect closes the page it created and detaches from CDP; it must not close the shared browser.
- Logout is disabled in shared-browser mode to protect the browser owner. Unlink the companion from WhatsApp's Linked Devices screen instead.
- The existing browser must be running with remote debugging enabled and must use the profile containing the desired WhatsApp Web login. A new tab is opened by whatsapp-web.js; the currently visible tab is not taken over.

This mode is currently experimental. Verify the exact Chromium deployment and session behavior before using it for an important account.


### Chrome on Android using Termux (same-phone, experimental)

For a phone-only local setup, see [Chrome Android CDP from Termux](android-termux-cdp.md). The helper uses Android Wireless Debugging to forward Chrome's local DevTools socket to `127.0.0.1:9222`.

This is **not** a remote bridge to a cloud-hosted OpenWA instance: the OpenWA process must run on the same phone for that loopback endpoint to work. A cloud deployment needs a separate authenticated reverse tunnel, which this helper does not provide. Puppeteer's Android Chrome support is experimental and requires a real-device compatibility test.
