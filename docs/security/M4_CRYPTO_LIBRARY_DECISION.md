# M4 library decision — 2026-10-28

Owner constraint: keep Shannon proprietary. No protocol dependency is approved
for normal-app deployment yet. Evaluation candidate: **vodozemac = 0.11.1**,
Apache-2.0, Rust minimum 1.89, standardized Olm v1 only.

| Candidate | Result |
|---|---|
| Official libsignal; release listing observed v0.104.0 | Maintained native Java/Swift/TypeScript bridges, asynchronous Signal protocol; AGPL-3.0-only and unsupported external APIs. Excluded absent separate rights. |
| Legacy libsignal-protocol-java / C | Archived/copyleft; unsuitable maintenance/licensing. |
| vodozemac 0.11.1 | Apache-2.0, maintained Rust Olm/Double Ratchet with historical independent audit. Best permissive evaluation candidate. Not Signal-wire-compatible or post-quantum. |
| famedly/dart-vodozemac | Wrapper is AGPL-3.0 despite permissive underlying Rust. Do not copy/link/vendor it. |
| open-e2ee/signal-protocol-js | MIT/Apache; assurance document says engineering tests are private/not publicly reproducible. No demonstrated reviewed native Flutter integration. Not selected. |
| Matrix Rust SDK | Higher-level maintained option if Matrix protocol/server semantics are adopted; not a drop-in replacement for Shannon's Go API. |

Olm v1 uses classical asynchronous 3DH and a Double Ratchet, with a truncated
64-bit authentication tag. Do not enable experimental Olm v2 to change that
margin. Historical audit and 2026 maintainer discussion require consideration;
the pinned 0.11.1 source exposes NonContributoryKey failures for establishment
and ratchet operations, which must be tested. No PQXDH or blanket Signal-level
security claim. The historical audit does not cover a new Shannon bridge.

Integration candidate: separately authored Rust JNI, later C ABI/Swift or a
permissive generated FFI for iOS/Desktop. Account/session serialization stays
private and is encrypted at rest in the native adapter. Exact dependency pins,
Cargo.lock/transitive license inventory, arm64/x86_64 builds, protocol tests,
transaction fault tests and identity-binding review must pass before activation.
Future platforms are design targets, not tested support. No fallback package.

This is an engineering compatibility screen, not a legal clearance of all
notice, patent, export or distribution obligations.

Primary evidence:

- [Official libsignal policy](https://github.com/signalapp/libsignal) and [releases](https://github.com/signalapp/libsignal/releases).
- [Pinned vodozemac manifest](https://github.com/matrix-org/vodozemac/blob/0.11.1/Cargo.toml), [Olm API](https://github.com/matrix-org/vodozemac/blob/0.11.1/src/olm/mod.rs), [account code](https://github.com/matrix-org/vodozemac/blob/0.11.1/src/olm/account/mod.rs).
- [Independent audit announcement](https://matrix.org/blog/2022/05/16/independent-public-audit-of-vodozemac-a-native-rust-reference-implementation-of-matrix-end-to-end-encryption/) and [2026 maintainer analysis](https://matrix.org/blog/2026/02/analysis-of-reported-issues-in-vodozemac/).
- [Dart wrapper license](https://github.com/famedly/dart-vodozemac/blob/main/LICENSE).
- [JS assurance statement](https://github.com/open-e2ee/signal-protocol-js/blob/main/docs/ASSURANCE.md).
