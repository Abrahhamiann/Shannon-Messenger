# M4 WebSocket protocol

Gated route: GET /api/v1/messaging/events. Authorization uses the current access
token in the HTTP header; no query credentials. Production uses WSS. Only the
existing loopback debug exception permits WS during authorized local testing.

Server event: `{"type":"sync_required","version":"1"}`. This is a bounded
notification hint, not a message, presence event or proof of delivery. Cursor
fetch and durable local acceptance/ack remain authoritative. No typing, online,
last-seen or read events are sent to another account.

At most two streams/device and 256 total. Wake buffer is one coalesced event;
writes/pings have five-second deadlines. Frames from clients are limited to
256 bytes and application data is not accepted. Default origin checks remain
enabled. Compression is disabled. Ping and repair hint every 30 seconds repair
missed notifications between API instances. Revocation/logout is rechecked every
five seconds, and a deadline closes the stream at exact access-token expiry.
The client refreshes/reauthenticates through M3 before reconnecting.

API shutdown explicitly cancels hijacked streams. Client background/logout
closes its socket and clears displayed plaintext caches; foreground reconnects
and resynchronizes. Jittered exponential retry is bounded, with no hot reconnect
loop or battery-intensive client polling. Stream disconnects never delete keys,
history or pending ciphertext.
