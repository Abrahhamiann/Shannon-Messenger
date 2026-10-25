# Latest checkpoint — 2026-10-25

M3 single-device authentication and local profile flows are implemented and
integration-tested, including the isolated Android avatar/storage path. Recovery
and device linking are not implemented; production security review is pending.
The resumed UI pass implements new early-access layouts across main routes.
M4 is still unimplemented. See [resume report](RESUME_REPORT.md) for acceptance
results, remaining work and exact continuation. Historical roadmap follows.

# Roadmap
## Current assignment — 2026-10-24

The latest user request supersedes the historical sequence below: M1 foundation,
M2 existing UI, M3 private identity and authentication. M2 local changes are
preserved. M3 development authentication is implemented and tested; full acceptance
remains gated on reviewed recovery, linking/rotation policy and independent review.
Recommended M4 work is listed in M3_REPORT.md. No M4 implementation started.

## Historical M1 plan
Current: M1 project foundation, including the backend/theme work explicitly
requested for this milestone. Do not proceed until the real Android → Go →
PostgreSQL acceptance test succeeds.
Next: M2 full reference design-system refinement, then M3 expanded navigation
and screens. Existing backend foundation fulfills part of original M4; reconcile
remaining backend work there. Identity, QR invitations, encrypted messaging,
offline sync, media, groups, devices, backups, calls, and security review follow
the supplied master milestone sequence. No later milestone is authorized here.
