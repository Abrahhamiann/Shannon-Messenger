# Notification privacy preparation

The settings page persists one enum preference in notification_preview_v1:
contentHidden, senderOnly, anonymous (default), disabled. It explicitly describes
future behavior. There is no message transport, notification permission request,
channel creation or notification delivery in this build. Preference persistence
does not constitute implemented push delivery.

Future Android integration contract:

- contentHidden: private notification with a redacted public version; never put
  message content in the lock-screen public version.
- senderOnly: sender-only content even when unlocked; private visibility with a
  sender-only public version only when user and OS policy permit.
- anonymous: generic notification text without sender/message in either version;
  private visibility by default.
- disabled: no preview text and secret lock-screen visibility; offer disabling
  the channel entirely through Android settings. OS behavior remains authoritative.

Create versioned channels only with real messaging, default private visibility,
and Android 13+ permission requested in context. Existing channel/user settings
cannot be silently overridden. Test OEM lock-screen rendering and changes to
system settings. Define notification tap routing through App Lock before release.

Push payloads must be opaque wake-up/envelope identifiers, never plaintext
messages, sender names or recovery material. Fetch authenticated encrypted
envelopes, validate and decrypt locally under the reviewed messaging protocol.
Use bounded retention and replay protection. No analytics or diagnostic uploads.
Do not include message keys in push registration. Test locked-device delivery,
logout/revocation, token rotation, OS restrictions and stale notifications before
enabling the feature. The same policy must cover wearable/connected-device
mirroring, which may reveal notification contents outside the handset.
