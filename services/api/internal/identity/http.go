package identity

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"io"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"
)

type API struct {
	db        *pgxpool.Pool
	audience  string
	localHTTP bool
	mu        sync.Mutex
	buckets   map[string]bucket
	global    bucket
}
type bucket struct {
	start time.Time
	count int
}

func New(db *pgxpool.Pool, audience string, localHTTP bool) *API {
	return &API{db: db, audience: audience, localHTTP: localHTTP, buckets: make(map[string]bucket)}
}
func (a *API) Mount(mux *http.ServeMux) {
	a.mountContacts(mux)
	mux.Handle("POST /api/v1/auth/challenge", a.guard(http.HandlerFunc(a.challenge)))
	mux.Handle("POST /api/v1/identities/register", a.guard(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { a.prove(w, r, "register") })))
	mux.Handle("POST /api/v1/auth/verify", a.guard(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { a.prove(w, r, "login") })))
	mux.Handle("POST /api/v1/auth/refresh", a.guard(http.HandlerFunc(a.refresh)))
	mux.Handle("POST /api/v1/auth/logout", a.guard(http.HandlerFunc(a.logout)))
	mux.Handle("GET /api/v1/identities/me", a.guard(http.HandlerFunc(a.me)))
	mux.Handle("GET /api/v1/devices", a.guard(http.HandlerFunc(a.devices)))
	mux.Handle("DELETE /api/v1/devices/{id}", a.guard(http.HandlerFunc(a.revoke)))
	mux.Handle("POST /api/v1/devices/link", a.guard(http.HandlerFunc(a.link)))
}
func (a *API) allow(ip string, now time.Time) bool {
	a.mu.Lock()
	defer a.mu.Unlock()
	for k, b := range a.buckets {
		if now.Sub(b.start) >= time.Minute {
			delete(a.buckets, k)
		}
	}
	if now.Sub(a.global.start) >= time.Minute {
		a.global = bucket{start: now}
	}
	if a.global.count >= 600 {
		return false
	}
	b, ok := a.buckets[ip]
	if !ok {
		if len(a.buckets) >= 2048 {
			return false
		}
		b = bucket{start: now}
	}
	if b.count >= 60 {
		return false
	}
	b.count++
	a.global.count++
	a.buckets[ip] = b
	return true
}
func (a *API) guard(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		w.Header().Set("Content-Type", "application/json")
		ip, _, err := net.SplitHostPort(r.RemoteAddr)
		parsed := net.ParseIP(ip)
		if r.TLS == nil && !(a.localHTTP && err == nil && parsed != nil && parsed.IsLoopback()) {
			fail(w, 426, "TLS required")
			return
		}
		if !a.allow(ip, time.Now()) {
			w.Header().Set("Retry-After", "60")
			fail(w, 429, "try later")
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()
		r = r.WithContext(ctx)
		r.Body = http.MaxBytesReader(w, r.Body, 8192)
		next.ServeHTTP(w, r)
	})
}
func decode(r *http.Request, v any) error {
	if ct := strings.Split(r.Header.Get("Content-Type"), ";")[0]; ct != "application/json" {
		return errors.New("JSON required")
	}
	d := json.NewDecoder(r.Body)
	d.DisallowUnknownFields()
	if err := d.Decode(v); err != nil {
		return err
	}
	if d.Decode(new(any)) != io.EOF {
		return errors.New("trailing JSON")
	}
	return nil
}
func reply(w http.ResponseWriter, code int, v any) {
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}
func fail(w http.ResponseWriter, code int, message string) {
	reply(w, code, map[string]string{"error": message})
}
func unavailable(w http.ResponseWriter) { fail(w, 503, "service unavailable") }

type challengeRequest struct {
	Purpose   string `json:"purpose"`
	RootKey   string `json:"root_key"`
	DeviceKey string `json:"device_key"`
}
type payload struct {
	Version   int    `json:"version"`
	Audience  string `json:"audience"`
	Purpose   string `json:"purpose"`
	Nonce     string `json:"nonce"`
	RootKey   string `json:"root_key"`
	DeviceKey string `json:"device_key"`
	Exp       int64  `json:"exp"`
}

func (a *API) challenge(w http.ResponseWriter, r *http.Request) {
	var in challengeRequest
	if decode(r, &in) != nil || (in.Purpose != "register" && in.Purpose != "login") {
		fail(w, 400, "invalid request")
		return
	}
	root, e1 := ParseKey(in.RootKey)
	device, e2 := ParseKey(in.DeviceKey)
	if e1 != nil || e2 != nil || bytes.Equal(root, device) {
		fail(w, 400, "invalid keys")
		return
	}
	nonce := randomToken()
	expires := time.Now().Add(120 * time.Second).Truncate(time.Second)
	data, _ := json.Marshal(payload{1, a.audience, in.Purpose, nonce, in.RootKey, in.DeviceKey, expires.Unix()})
	_, err := a.db.Exec(r.Context(), "INSERT INTO auth_challenges(nonce,purpose,root_key,device_key,payload,expires_at) VALUES($1,$2,$3,$4,$5,$6)", nonce, in.Purpose, root, device, string(data), expires)
	if err != nil {
		unavailable(w)
		return
	}
	reply(w, 200, map[string]string{"nonce": nonce, "payload": string(data)})
}

type proofRequest struct {
	Nonce       string `json:"nonce"`
	DeviceProof string `json:"device_proof"`
	RootProof   string `json:"root_proof,omitempty"`
}
type Tokens struct {
	Access        string    `json:"access_token"`
	Refresh       string    `json:"refresh_token"`
	AccessExpires time.Time `json:"access_expires_at"`
	Expires       time.Time `json:"expires_at"`
	Identity      string    `json:"identity_id"`
	Device        string    `json:"device_id"`
}

func newTokens(id, device string, absolute time.Time) Tokens {
	return Tokens{randomToken(), randomToken(), time.Now().Add(15 * time.Minute), absolute, id, device}
}
func insertSession(ctx context.Context, tx pgx.Tx, t Tokens) error {
	_, err := tx.Exec(ctx, "INSERT INTO auth_sessions(access_hash,refresh_hash,identity_id,device_id,access_expires_at,expires_at) VALUES($1,$2,$3,$4,$5,$6)", tokenHash(t.Access), tokenHash(t.Refresh), t.Identity, t.Device, t.AccessExpires, t.Expires)
	return err
}
func (a *API) prove(w http.ResponseWriter, r *http.Request, purpose string) {
	var in proofRequest
	if decode(r, &in) != nil || !validToken(in.Nonce) {
		fail(w, 400, "invalid request")
		return
	}
	tx, err := a.db.Begin(r.Context())
	if err != nil {
		unavailable(w)
		return
	}
	defer tx.Rollback(context.Background())
	var storedPurpose, data string
	var root, device []byte
	var expires time.Time
	err = tx.QueryRow(r.Context(), "DELETE FROM auth_challenges WHERE nonce=$1 RETURNING purpose,payload,root_key,device_key,expires_at", in.Nonce).Scan(&storedPurpose, &data, &root, &device, &expires)
	if errors.Is(err, pgx.ErrNoRows) {
		fail(w, 401, "authentication failed")
		return
	}
	if err != nil {
		unavailable(w)
		return
	}
	if storedPurpose != purpose || !time.Now().Before(expires) || !VerifyJWS(in.DeviceProof, data, device) || (purpose == "register" && !VerifyJWS(in.RootProof, data, root)) || (purpose == "login" && in.RootProof != "") {
		if tx.Commit(r.Context()) != nil {
			unavailable(w)
			return
		}
		fail(w, 401, "authentication failed")
		return
	}
	id, did := PublicID(root, "shn1_"), PublicID(device, "dev1_")
	if purpose == "register" {
		_, err = tx.Exec(r.Context(), "INSERT INTO identities(id,root_key) VALUES($1,$2) ON CONFLICT DO NOTHING", id, root)
		if err != nil {
			unavailable(w)
			return
		}
		var storedRoot []byte
		if err = tx.QueryRow(r.Context(), "SELECT root_key FROM identities WHERE id=$1 FOR UPDATE", id).Scan(&storedRoot); err != nil {
			unavailable(w)
			return
		}
		var count int
		if err = tx.QueryRow(r.Context(), "SELECT count(*) FROM devices WHERE identity_id=$1", id).Scan(&count); err != nil {
			unavailable(w)
			return
		}
		if count == 0 {
			_, err = tx.Exec(r.Context(), "INSERT INTO devices(id,identity_id,public_key) VALUES($1,$2,$3) ON CONFLICT DO NOTHING", did, id, device)
			if err != nil {
				unavailable(w)
				return
			}
		}
	}
	var storedDevice []byte
	var revoked *time.Time
	err = tx.QueryRow(r.Context(), "SELECT public_key,revoked_at FROM devices WHERE id=$1 AND identity_id=$2 FOR UPDATE", did, id).Scan(&storedDevice, &revoked)
	if errors.Is(err, pgx.ErrNoRows) || (err == nil && (revoked != nil || !bytes.Equal(storedDevice, device))) {
		if tx.Commit(r.Context()) != nil {
			unavailable(w)
			return
		}
		fail(w, 401, "authentication failed")
		return
	}
	if err != nil {
		unavailable(w)
		return
	}
	// At most one live session per device; a fresh signed login rotates all old sessions.
	if _, err = tx.Exec(r.Context(), "DELETE FROM auth_sessions WHERE device_id=$1", did); err != nil {
		unavailable(w)
		return
	}
	tokens := newTokens(id, did, time.Now().Add(7*24*time.Hour))
	if insertSession(r.Context(), tx, tokens) != nil || tx.Commit(r.Context()) != nil {
		unavailable(w)
		return
	}
	reply(w, 200, tokens)
}

type session struct {
	Identity, Device string
	AccessHash       []byte
	Expires          time.Time
}

func (a *API) authenticated(r *http.Request, refresh string) (pgx.Tx, session, error) {
	token := refresh
	column := "refresh_hash"
	expiry := "s.expires_at"
	if refresh == "" {
		auth := r.Header.Get("Authorization")
		if !strings.HasPrefix(auth, "Bearer ") {
			return nil, session{}, errDenied
		}
		token = strings.TrimPrefix(auth, "Bearer ")
		column = "access_hash"
		expiry = "LEAST(s.access_expires_at,s.expires_at)"
	}
	if !validToken(token) {
		return nil, session{}, errDenied
	}
	tx, err := a.db.Begin(r.Context())
	if err != nil {
		return nil, session{}, err
	}
	var s session
	err = tx.QueryRow(r.Context(), "SELECT s.identity_id,s.device_id,s.access_hash,s.expires_at FROM auth_sessions s JOIN devices d ON d.id=s.device_id WHERE s."+column+"=$1 AND "+expiry+">clock_timestamp() AND d.revoked_at IS NULL FOR UPDATE OF d,s", tokenHash(token)).Scan(&s.Identity, &s.Device, &s.AccessHash, &s.Expires)
	if err != nil {
		tx.Rollback(context.Background())
		if errors.Is(err, pgx.ErrNoRows) {
			err = errDenied
		}
		return nil, session{}, err
	}
	return tx, s, nil
}
func authError(w http.ResponseWriter, err error) {
	if errors.Is(err, errDenied) {
		fail(w, 401, "authentication failed")
	} else {
		unavailable(w)
	}
}
func (a *API) refresh(w http.ResponseWriter, r *http.Request) {
	var in struct {
		Refresh string `json:"refresh_token"`
	}
	if decode(r, &in) != nil || !validToken(in.Refresh) {
		fail(w, 400, "invalid request")
		return
	}
	tx, s, err := a.authenticated(r, in.Refresh)
	if err != nil {
		authError(w, err)
		return
	}
	defer tx.Rollback(context.Background())
	t := newTokens(s.Identity, s.Device, s.Expires)
	if t.AccessExpires.After(t.Expires) {
		t.AccessExpires = t.Expires
	}
	if _, err = tx.Exec(r.Context(), "DELETE FROM auth_sessions WHERE access_hash=$1", s.AccessHash); err != nil {
		unavailable(w)
		return
	}
	if insertSession(r.Context(), tx, t) != nil || tx.Commit(r.Context()) != nil {
		unavailable(w)
		return
	}
	reply(w, 200, t)
}
func (a *API) logout(w http.ResponseWriter, r *http.Request) {
	// A refresh credential can revoke the session even when its short-lived
	// access credential has expired. This never mints a new session.
	var in struct {
		Refresh string `json:"refresh_token"`
	}
	if r.ContentLength > 0 {
		if decode(r, &in) != nil || (in.Refresh != "" && !validToken(in.Refresh)) {
			fail(w, 400, "invalid request")
			return
		}
	}
	tx, s, err := a.authenticated(r, in.Refresh)
	if err != nil {
		authError(w, err)
		return
	}
	defer tx.Rollback(context.Background())
	if _, err = tx.Exec(r.Context(), "DELETE FROM auth_sessions WHERE access_hash=$1", s.AccessHash); err != nil {
		unavailable(w)
		return
	}
	if tx.Commit(r.Context()) != nil {
		unavailable(w)
		return
	}
	w.WriteHeader(204)
}
func (a *API) me(w http.ResponseWriter, r *http.Request) {
	tx, s, err := a.authenticated(r, "")
	if err != nil {
		authError(w, err)
		return
	}
	defer tx.Rollback(context.Background())
	if tx.Commit(r.Context()) != nil {
		unavailable(w)
		return
	}
	reply(w, 200, map[string]string{"identity_id": s.Identity, "device_id": s.Device})
}
func (a *API) devices(w http.ResponseWriter, r *http.Request) {
	tx, s, err := a.authenticated(r, "")
	if err != nil {
		authError(w, err)
		return
	}
	defer tx.Rollback(context.Background())
	rows, err := tx.Query(r.Context(), "SELECT id,created_at,revoked_at FROM devices WHERE identity_id=$1 ORDER BY created_at LIMIT 100", s.Identity)
	if err != nil {
		unavailable(w)
		return
	}
	type deviceView struct {
		ID      string     `json:"id"`
		Created time.Time  `json:"created_at"`
		Revoked *time.Time `json:"revoked_at"`
	}
	items := []deviceView{}
	for rows.Next() {
		var v deviceView
		if err = rows.Scan(&v.ID, &v.Created, &v.Revoked); err != nil {
			break
		}
		items = append(items, v)
	}
	rows.Close()
	if err != nil || rows.Err() != nil || tx.Commit(r.Context()) != nil {
		unavailable(w)
		return
	}
	reply(w, 200, map[string]any{"devices": items})
}
func (a *API) revoke(w http.ResponseWriter, r *http.Request) {
	tx, s, err := a.authenticated(r, "")
	if err != nil {
		authError(w, err)
		return
	}
	defer tx.Rollback(context.Background())
	// M3 supports self-revocation only. Cross-device authority requires linking review.
	if r.PathValue("id") != s.Device {
		fail(w, 403, "only this device can be revoked")
		return
	}
	if _, err = tx.Exec(r.Context(), "UPDATE devices SET revoked_at=COALESCE(revoked_at,clock_timestamp()) WHERE id=$1 AND identity_id=$2", s.Device, s.Identity); err != nil {
		unavailable(w)
		return
	}
	if _, err = tx.Exec(r.Context(), "DELETE FROM auth_sessions WHERE device_id=$1", s.Device); err != nil {
		unavailable(w)
		return
	}
	if tx.Commit(r.Context()) != nil {
		unavailable(w)
		return
	}
	w.WriteHeader(204)
}
func (a *API) link(w http.ResponseWriter, r *http.Request) {
	tx, _, err := a.authenticated(r, "")
	if err != nil {
		authError(w, err)
		return
	}
	defer tx.Rollback(context.Background())
	fail(w, 501, "device linking is not available")
}

// Cleanup has no request logging and only removes expired ephemeral authentication state.
func (a *API) Cleanup(ctx context.Context) {
	ticker := time.NewTicker(time.Minute)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			c, cancel := context.WithTimeout(ctx, 5*time.Second)
			_, _ = a.db.Exec(c, "DELETE FROM auth_challenges WHERE expires_at<now()")
			_, _ = a.db.Exec(c, "DELETE FROM auth_sessions WHERE expires_at<now()")
			_, _ = a.db.Exec(c, `WITH expired AS (DELETE FROM contact_invitations WHERE expires_at<now() RETURNING token_hash,expires_at) INSERT INTO contact_invitation_history(token_hash,expires_at) SELECT token_hash,expires_at FROM expired ON CONFLICT(token_hash) DO NOTHING`)
			_, _ = a.db.Exec(c, "DELETE FROM contact_invitation_history WHERE expires_at<now()-interval '7 days'")
			cancel()
		}
	}
}
