# API
GET /health has no authentication in M1.
200: {"status":"ok","service":"shannon-api","database":"up"}
503: {"status":"degraded","service":"shannon-api","database":"down"}
Content-Type: application/json; Cache-Control: no-store.
Database ping deadline: 2 seconds. POST is 405; unknown paths are 404.
This is dependency readiness, not a pure process liveness endpoint.
No CORS configuration is needed for native Android.
