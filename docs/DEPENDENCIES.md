# Dependency verification

M3 additions (2026-10-24): cryptography 2.9.0 (Apache-2.0),
flutter_secure_storage 11.2.0 (BSD-3-Clause), filippo.io/edwards25519 v1.2.0
(BSD-3-Clause). Versions resolved against official package registries; no
independent audit of the exact integration is claimed. Sources:
https://pub.dev/packages/cryptography,
https://pub.dev/packages/flutter_secure_storage,
https://pkg.go.dev/filippo.io/edwards25519.

Resolved and pinned on 2026-10-23 using installed SDKs and official registries:

| Dependency | Pin | Source |
| --- | --- | --- |
| Flutter / Dart | 3.47.7 / 3.13.5 | Local flutter --version |
| flutter_riverpod | 3.4.3 | https://pub.dev/packages/flutter_riverpod/versions |
| go_router | 18.1.1 | https://pub.dev/packages/go_router/versions |
| http | 1.6.0 | https://pub.dev/packages/http |
| Go | 1.27.3 | Local go version |
| pgx | v5.11.0 | https://pkg.go.dev/github.com/jackc/pgx/v5/pgxpool |

Riverpod and GoRouter satisfy the specified stack. package:http supplies the
single health request without Dio's additional surface. pgx is the specified
PostgreSQL driver. No cryptographic dependencies were selected. Direct versions
and resolved transitive versions are committed through manifest/lock files once
the user commits the repository; no commit has been created automatically.
