package identity

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/json"
	"github.com/jackc/pgx/v5/pgxpool"
	"net/http"
	"net/http/httptest"
	"os"
	"shannon.local/api/internal/database"
	"shannon.local/api/internal/httpapi"
	"shannon.local/api/migrations"
	"sync"
	"testing"
)

type testClient struct {
	t            *testing.T
	db           *pgxpool.Pool
	handler      http.Handler
	root, device ed25519.PrivateKey
}

func setup(t *testing.T) *testClient {
	t.Helper()
	if os.Getenv("SHANNON_INTEGRATION") != "1" {
		t.Skip("requires isolated PostgreSQL: scripts/Test-M3Database.ps1")
	}
	db, err := database.Open(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(db.Close)
	if err = migrations.Apply(context.Background(), db); err != nil {
		t.Fatal(err)
	}
	_, root, _ := ed25519.GenerateKey(rand.Reader)
	_, device, _ := ed25519.GenerateKey(rand.Reader)
	a := New(db, "test-audience", true)
	return &testClient{t, db, httpapi.Handler(db, a.Mount), root, device}
}
func (c *testClient) request(method, path string, body any, token string) *httptest.ResponseRecorder {
	b, _ := json.Marshal(body)
	r := httptest.NewRequest(method, path, bytes.NewReader(b))
	r.RemoteAddr = "127.0.0.1:12345"
	r.Header.Set("Content-Type", "application/json")
	if token != "" {
		r.Header.Set("Authorization", "Bearer "+token)
	}
	w := httptest.NewRecorder()
	c.handler.ServeHTTP(w, r)
	return w
}
func sign(key ed25519.PrivateKey, data string) string {
	input := headerPart + "." + encoding.EncodeToString([]byte(data))
	return input + "." + encoding.EncodeToString(ed25519.Sign(key, []byte(input)))
}
func (c *testClient) challenge(purpose string) proofRequest {
	c.t.Helper()
	body := challengeRequest{purpose, encoding.EncodeToString(c.root.Public().(ed25519.PublicKey)), encoding.EncodeToString(c.device.Public().(ed25519.PublicKey))}
	w := c.request("POST", "/api/v1/auth/challenge", body, "")
	if w.Code != 200 {
		c.t.Fatalf("challenge: %d", w.Code)
	}
	var result map[string]string
	if json.Unmarshal(w.Body.Bytes(), &result) != nil {
		c.t.Fatal("invalid challenge")
	}
	proof := proofRequest{Nonce: result["nonce"], DeviceProof: sign(c.device, result["payload"])}
	if purpose == "register" {
		proof.RootProof = sign(c.root, result["payload"])
	}
	return proof
}
func (c *testClient) register() Tokens {
	c.t.Helper()
	w := c.request("POST", "/api/v1/identities/register", c.challenge("register"), "")
	if w.Code != 200 {
		c.t.Fatalf("register: %d", w.Code)
	}
	var tok Tokens
	if json.Unmarshal(w.Body.Bytes(), &tok) != nil {
		c.t.Fatal("invalid tokens")
	}
	return tok
}
func expectCode(t *testing.T, w *httptest.ResponseRecorder, code int) {
	t.Helper()
	if w.Code != code {
		t.Fatalf("got HTTP %d, want %d", w.Code, code)
	}
}
func TestRegistrationSessionsAndRevocation(t *testing.T) {
	c := setup(t)
	expectCode(t, c.request("GET", "/health", nil, ""), 200)
	expectCode(t, c.request("GET", "/api/v1/identities/me", nil, ""), 401)
	tokens := c.register()
	expectCode(t, c.request("GET", "/api/v1/identities/me", nil, tokens.Access), 200)
	expectCode(t, c.request("GET", "/api/v1/devices", nil, tokens.Access), 200)
	expectCode(t, c.request("POST", "/api/v1/devices/link", map[string]string{}, tokens.Access), 501)
	expectCode(t, c.request("DELETE", "/api/v1/devices/dev1_other", nil, tokens.Access), 403)
	// Same keys + fresh proofs are idempotent; old sessions are superseded.
	next := c.register()
	if next.Identity != tokens.Identity || next.Device != tokens.Device {
		t.Fatal("idempotency violated")
	}
	expectCode(t, c.request("GET", "/api/v1/identities/me", nil, tokens.Access), 401)
	w := c.request("POST", "/api/v1/auth/refresh", map[string]string{"refresh_token": next.Refresh}, "")
	expectCode(t, w, 200)
	var refreshed Tokens
	_ = json.Unmarshal(w.Body.Bytes(), &refreshed)
	expectCode(t, c.request("POST", "/api/v1/auth/refresh", map[string]string{"refresh_token": next.Refresh}, ""), 401)
	expectCode(t, c.request("GET", "/api/v1/identities/me", nil, next.Access), 401)
	expectCode(t, c.request("POST", "/api/v1/auth/logout", nil, refreshed.Access), 204)
	expectCode(t, c.request("GET", "/api/v1/identities/me", nil, refreshed.Access), 401)
	login := c.request("POST", "/api/v1/auth/verify", c.challenge("login"), "")
	expectCode(t, login, 200)
	var signedIn Tokens
	_ = json.Unmarshal(login.Body.Bytes(), &signedIn)
	expectCode(t, c.request("DELETE", "/api/v1/devices/"+signedIn.Device, nil, signedIn.Access), 204)
	expectCode(t, c.request("GET", "/api/v1/identities/me", nil, signedIn.Access), 401)
	expectCode(t, c.request("POST", "/api/v1/auth/refresh", map[string]string{"refresh_token": signedIn.Refresh}, ""), 401)
	expectCode(t, c.request("POST", "/api/v1/identities/register", c.challenge("register"), ""), 401)
	expectCode(t, c.request("POST", "/api/v1/auth/verify", c.challenge("login"), ""), 401)
}
func TestInvalidExpiredAndConcurrentProofs(t *testing.T) {
	c := setup(t)
	expectCode(t, c.request("POST", "/api/v1/auth/challenge", challengeRequest{"register", "invalid", "invalid"}, ""), 400)
	proof := c.challenge("register")
	wrong := proof
	wrong.RootProof = proof.DeviceProof
	expectCode(t, c.request("POST", "/api/v1/identities/register", wrong, ""), 401)
	expectCode(t, c.request("POST", "/api/v1/identities/register", proof, ""), 401)
	expired := c.challenge("register")
	if _, err := c.db.Exec(context.Background(), "UPDATE auth_challenges SET expires_at=now()-interval '1 second' WHERE nonce=$1", expired.Nonce); err != nil {
		t.Fatal(err)
	}
	expectCode(t, c.request("POST", "/api/v1/identities/register", expired, ""), 401)
	replay := c.challenge("register")
	codes := make(chan int, 8)
	var wg sync.WaitGroup
	for range 8 {
		wg.Add(1)
		go func() { defer wg.Done(); codes <- c.request("POST", "/api/v1/identities/register", replay, "").Code }()
	}
	wg.Wait()
	close(codes)
	successes := 0
	for code := range codes {
		if code == 200 {
			successes++
		} else if code != 401 {
			t.Fatalf("unexpected race result %d", code)
		}
	}
	if successes != 1 {
		t.Fatalf("single-use violated: %d", successes)
	}
}
func TestDeviceEnrollmentBoundaryAndExpiry(t *testing.T) {
	c := setup(t)
	first := c.register()
	_, other, _ := ed25519.GenerateKey(rand.Reader)
	original := c.device
	c.device = other
	expectCode(t, c.request("POST", "/api/v1/identities/register", c.challenge("register"), ""), 401)
	expectCode(t, c.request("POST", "/api/v1/auth/verify", c.challenge("login"), ""), 401)
	c.device = original
	if _, err := c.db.Exec(context.Background(), "UPDATE auth_sessions SET access_expires_at=now()-interval '1 second' WHERE device_id=$1", first.Device); err != nil {
		t.Fatal(err)
	}
	expectCode(t, c.request("GET", "/api/v1/identities/me", nil, first.Access), 401)
	rotated := c.request("POST", "/api/v1/auth/refresh", map[string]string{"refresh_token": first.Refresh}, "")
	expectCode(t, rotated, 200)
	var rotatedTokens Tokens
	if err := json.Unmarshal(rotated.Body.Bytes(), &rotatedTokens); err != nil {
		t.Fatal(err)
	}
	if _, err := c.db.Exec(context.Background(), "UPDATE auth_sessions SET expires_at=now()-interval '1 second' WHERE device_id=$1", first.Device); err != nil {
		t.Fatal(err)
	}
	expectCode(t, c.request("GET", "/api/v1/identities/me", nil, rotatedTokens.Access), 401)
	expectCode(t, c.request("POST", "/api/v1/auth/refresh", map[string]string{"refresh_token": rotatedTokens.Refresh}, ""), 401)
	var count int
	if err := c.db.QueryRow(context.Background(), "SELECT count(*) FROM devices WHERE identity_id=$1", first.Identity).Scan(&count); err != nil || count != 1 {
		t.Fatal("unauthorized device inserted")
	}
}
func TestConcurrentRefreshAndRevoke(t *testing.T) {
	c := setup(t)
	tokens := c.register()
	// Atomic rotation: exactly one use of a refresh token succeeds.
	codes := make(chan int, 4)
	var wg sync.WaitGroup
	for range 4 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			codes <- c.request("POST", "/api/v1/auth/refresh", map[string]string{"refresh_token": tokens.Refresh}, "").Code
		}()
	}
	wg.Wait()
	close(codes)
	successes := 0
	for code := range codes {
		if code == 200 {
			successes++
		} else if code != 401 {
			t.Fatalf("refresh race: %d", code)
		}
	}
	if successes != 1 {
		t.Fatal("refresh token reused")
	}
	tokens = c.register()
	var refreshed Tokens
	var refreshCode, revokeCode int
	wg.Add(2)
	go func() {
		defer wg.Done()
		w := c.request("POST", "/api/v1/auth/refresh", map[string]string{"refresh_token": tokens.Refresh}, "")
		refreshCode = w.Code
		_ = json.Unmarshal(w.Body.Bytes(), &refreshed)
	}()
	go func() {
		defer wg.Done()
		revokeCode = c.request("DELETE", "/api/v1/devices/"+tokens.Device, nil, tokens.Access).Code
	}()
	wg.Wait()
	// A refresh that wins invalidates the old access token; then a new authenticated
	// revoke must use the rotated token. No false successful revocation is allowed.
	if revokeCode == 401 && refreshCode == 200 {
		expectCode(t, c.request("DELETE", "/api/v1/devices/"+tokens.Device, nil, refreshed.Access), 204)
	} else if revokeCode != 204 {
		t.Fatalf("revoke race: %d/%d", revokeCode, refreshCode)
	}
	expectCode(t, c.request("GET", "/api/v1/identities/me", nil, refreshed.Access), 401)
	var count int
	_ = c.db.QueryRow(context.Background(), "SELECT count(*) FROM auth_sessions WHERE device_id=$1", tokens.Device).Scan(&count)
	if count != 0 {
		t.Fatal("session survived device revocation")
	}
}
