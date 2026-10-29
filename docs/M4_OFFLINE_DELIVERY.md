# M4 offline delivery contract

Send first commits exact library ciphertext, advanced session state and encrypted
local history/outbox in one SQLite transaction. An established pinned session
can encrypt while transport is offline. A first session still requires an
authenticated public prekey; failure keeps the draft and never queues plaintext.

Retry uses the identical ciphertext and ID. Server lost-response retries are
idempotent. Server acceptance changes local state to accepted, never read/seen.
Explicit failed states require retry of the same message; transport outages keep
the encrypted outbox queued with bounded reconnect backoff. Queued content older
than 14 local days expires locally so it cannot outlive the dedup contract.

Receiving validates the pinned identity and library authentication, validates
decrypted routing/ID fields, and atomically stores ratchet/account/prekey state,
dedup/history before acknowledgement. Injected failure before commit must leave
both history and protocol state unchanged. Duplicate acceptance does not decrypt
or present a second copy. Invalid ciphertext is not acknowledged or downgraded;
the UI reports a failure while bounded cursor paging can continue other records.

The server queue survives API restart in PostgreSQL. Pending expiry is enforced
even if cleanup has not run. Blocks, device revocation and identity changes stop
future unauthorized use; they cannot revoke plaintext already received. Outbox,
inbox and history keys are independent of access-token lifetime. Logout retains
all encrypted local files and authentication identities.

Native storage tests have passed rollback/reopen/duplicate/ciphertext-at-rest
checks on isolated Samsung storage. Two-device validation has demonstrated a
real encrypted round trip, recipient-offline queue survival across API restart,
sender-offline encryption and process restart, opening local history during an
API/PostgreSQL outage, and automatic retry after transport restoration. Retry
also resumes a retained offline session after cold start, without signing up or
undoing logout. Native App Lock/visibility gates suspend sync while locked or
backgrounded. See M4_ANDROID_ACCEPTANCE.md for observed results and pending gates.
