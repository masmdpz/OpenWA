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

Docker Compose forwards both variables. The Infrastructure page does not expose the CDP endpoint because a WebSocket endpoint can act as a bearer capability for the whole browser; configure it through a protected server environment or secret store. The browser must be reachable from the OpenWA process. When CDP connect mode is selected, OpenWA does not launch Chromium and does not create a separate LocalAuth profile; WhatsApp Web storage comes from the connected browser profile.

## Important limitations

- This connects to a browser on a machine/container that OpenWA can reach. It does not import a pairing code from a separate phone browser.
- Do not expose an unauthenticated CDP endpoint to the public internet. CDP grants control over the browser and its logged-in sessions. Keep it bound to loopback or behind a properly authenticated private network.
- Configure proxy/network settings on the connected browser itself. Per-session OpenWA proxy settings are not supported in this mode.
- OpenWA disconnect closes the page it created and detaches from CDP; it must not close the shared browser.
- Logout is disabled in shared-browser mode to protect the browser owner. Unlink the companion from WhatsApp's Linked Devices screen instead.
- The existing browser must be running with remote debugging enabled and must use the profile containing the desired WhatsApp Web login. A new tab is opened by whatsapp-web.js; the currently visible tab is not taken over.

This mode is currently experimental. Verify the exact Chromium deployment and session behavior before using it for an important account.
