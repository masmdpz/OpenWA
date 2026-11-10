# Scheduled Notice for OpenWA

A small OpenWA extension that sends **one operator-authored, clearly labelled** WhatsApp notice at a specified date and time.

This package is intentionally not a WhatsApp account warmer, chat simulator, bulk sender, or anti-detection tool. It does not generate conversations, alternate between two accounts, place calls, or add reactions.

## Requirements

- OpenWA with the plugin runtime enabled.
- A connected sender session that is active in OpenWA.
- The plugin enabled for the sender session in the Plugins page.
- The recipient is an intended contact who expects the message.

## Install

Upload the plugin ZIP from the OpenWA **Plugins** page, then enable the plugin. The archive must contain `manifest.json`, `index.cjs`, and this README at the package root.

## Configure

In Plugins → Scheduled Notice, set:

- **Enable scheduled notice**: On.
- **Sender session ID**: the OpenWA session that will send the notice.
- **Recipient chat ID**: for example `6281234567890@c.us` (use the chat ID format shown by your OpenWA engine/API).
- **Send time**: ISO 8601 with an explicit timezone offset. Example: `2026-11-11T09:00:00+07:00` for 09:00 WIB.
- **Message**: the message written by the operator.

Also activate the plugin for the same sender session under its **Sessions** settings. The plugin adds `[PESAN OTOMATIS TERJADWAL]` to the beginning of the message so the recipient can recognize it as automated.

## Delivery behavior

- One-time delivery only; no recurring schedule and no message sequence.
- Schedule must be in the future and no more than 30 days ahead.
- The plugin stores a delivery claim before sending to avoid duplicate sends after a restart.
- Failed sends are logged and are **not** retried automatically.
- If a delivery is recorded as `sending` after a crash, edit the schedule or message to create a new explicit job after checking whether the original reached the recipient.
- OpenWA and the sender session must be running at the scheduled time. The plugin cannot deliver while the host/phone process is stopped.

## Notes

The currently documented sandbox plugin API exposes text and media sending, but not message reactions or WhatsApp calling. This plugin therefore does not attempt either operation.
