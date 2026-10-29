# M4 peer trust contract

Status: gated verification screen implemented and exercised between two isolated
validation accounts. Normal-account deployment remains pending.

Persist stable account/root identity, authorized device, messaging signing/DH
keys, epoch and explicit user verification state. Validate identity hashes and
root/device binding proofs plus messaging prekey signatures before key exchange.
A username match or directory reply never sets verified=true.

First contact is TOFU until users compare the full fingerprint over the binding
transcript out of band. The implemented Shannon fingerprint is SHA-256 over the
sorted, LF-separated binding transcripts with domain `shannon-verify-v1`, shown
as 16 groups of four hexadecimal characters. It is symmetric and includes both
account/device identities, suite, epoch and messaging public keys. It is not a
Signal safety number. A malicious first-contact server
can substitute another account before pins/out-of-band comparison exist.

Changed device/messaging keys block outgoing encryption and show a key-change
warning. Automatic replacement is not implemented. A future reviewed transition
must show the old/new identity and require explicit user resolution; the current
verification button cannot overwrite the stored pin or bypass this block. A
detected change is latched in encrypted native trust storage before reporting
the rejection; it survives process/storage reopen and directory rollback to the
old bundle. Re-verification of the old fingerprint cannot clear the latch.
Refresh/logout/network failure must never reset trust. A server cannot silently
replace an already verified pin. Revocation cannot erase previously decrypted
messages. Future fanout requires authenticated complete device lists and a
per-device trust policy; unsupported additional devices must fail explicitly.
