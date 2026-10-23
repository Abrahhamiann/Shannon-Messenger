# Architecture
Monorepo with Flutter Android client and Go modular monolith. Riverpod owns
theme and connection state; GoRouter owns routes. package:http is sufficient for
one bounded JSON request; a larger HTTP framework is unnecessary at this stage.
Shared Dart has no Android-specific network assumptions beyond a configurable
development default URL. Android minimum SDK is 26 (Android 8).

Go net/http exposes GET /health. pgxpool verifies PostgreSQL at startup and on
each health request. Five maximum pooled connections, zero required idle
connections. Startup fails if the database is unavailable; runtime failures
return HTTP 503. Interrupt initiates a five-second graceful shutdown.

SQL is embedded in a separate migration binary. Runners serialize on an advisory
transaction lock; schema tracking and SQL run atomically. Checksums detect edits.
No schema for users or messages is invented. Future feature modules will use
presentation/domain/data boundaries as their actual behavior is implemented.

Dependency versions are pinned in pubspec.yaml, pubspec.lock, go.mod, and go.sum.
Flutter 3.47.7, Riverpod 3.4.3, GoRouter 18.1.1, http 1.6.0, pgx v5.11.0.
Versions resolved against official registries; framework transitive pins retained.
