# API

M3 identity/auth routes, response policies and Windows setup are documented in
M3_REPORT.md. Proof encoding is specified in security/M3_IDENTITY_DESIGN.md.
No route accepts private seeds or recovery phrases. /devices/link is an
authenticated unavailable endpoint, and revocation is self-device-only in M3.
GET /health has no authentication in M1.
200: {"status":"ok","service":"shannon-api","database":"up"}
503: {"status":"degraded","service":"shannon-api","database":"down"}
Content-Type: application/json; Cache-Control: no-store.
Database ping deadline: 2 seconds. POST is 405; unknown paths are 404.
This is dependency readiness, not a pure process liveness endpoint.
No CORS configuration is needed for native Android.
