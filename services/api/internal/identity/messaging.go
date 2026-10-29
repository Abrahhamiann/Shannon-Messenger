package identity

import (
	"bytes"
	"context"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

const messagingSuite = "olm.v1"

type publicPrekey struct {
	ID        string `json:"id"`
	Key       string `json:"key"`
	Signature string `json:"signature"`
}
type publicBundle struct {
	Account      string         `json:"account"`
	Device       string         `json:"device"`
	Suite        string         `json:"suite"`
	Epoch        int64          `json:"epoch"`
	Curve        string         `json:"curve"`
	Signing      string         `json:"signing"`
	AccountProof string         `json:"account_proof"`
	DeviceProof  string         `json:"device_proof"`
	RootKey      string         `json:"root_key,omitempty"`
	DeviceKey    string         `json:"device_key,omitempty"`
	Prekeys      []publicPrekey `json:"prekeys"`
}

func bindingStatement(audience string, b publicBundle) string {
	return strings.Join([]string{"shannon-messaging-key-v1", audience, b.Account, b.Device, b.Suite, strconv.FormatInt(b.Epoch, 10), b.Curve, b.Signing}, "\n")
}
func prekeyStatement(b publicBundle, p publicPrekey) string {
	return strings.Join([]string{"shannon-messaging-prekey-v1", b.Account, b.Device, strconv.FormatInt(b.Epoch, 10), b.Curve, b.Signing, p.ID, p.Key}, "\n")
}
func decodeSized(s string, n int) ([]byte, bool) {
	b, e := encoding.DecodeString(s)
	return b, e == nil && len(b) == n && encoding.EncodeToString(b) == s
}

func (a *API) mountMessaging(mux *http.ServeMux, enabled bool) {
	for _, pattern := range []string{"GET /api/v1/messaging/inventory", "GET /api/v1/messaging/bundle", "PUT /api/v1/messaging/bundle", "POST /api/v1/messaging/claim", "POST /api/v1/messaging/envelopes", "GET /api/v1/messaging/envelopes", "POST /api/v1/messaging/ack", "GET /api/v1/messaging/status", "GET /api/v1/messaging/events"} {
		mux.Handle(pattern, a.messagingGuard(enabled, http.HandlerFunc(a.messaging)))
	}
}
func (a *API) messagingGuard(enabled bool, next http.Handler) http.Handler {
	// Reuse the existing HTTPS/loopback and IP quota boundary, but preserve
	// streaming context and allow the bounded opaque envelope body.
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !enabled {
			reply(w, 503, map[string]string{"error": "messaging unavailable", "code": "messaging_not_enabled"})
			return
		}
		// guard's short request context is deliberately limited to authorization.
		authorized := false
		a.guard(http.HandlerFunc(func(w http.ResponseWriter, checked *http.Request) {
			tx, _, err := a.authenticated(checked, "")
			if err != nil {
				authError(w, err)
				return
			}
			if tx.Commit(checked.Context()) != nil {
				unavailable(w)
				return
			}
			authorized = true
		})).ServeHTTP(w, r.Clone(r.Context()))
		if !authorized {
			return
		}
		if r.URL.RawQuery != "" && strings.Contains(r.URL.RawQuery, "token") {
			fail(w, 400, "credentials must use Authorization header")
			return
		}
		r.Body = http.MaxBytesReader(w, r.Body, 100000)
		if r.URL.Path != "/api/v1/messaging/events" {
			ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
			defer cancel()
			r = r.WithContext(ctx)
		}
		next.ServeHTTP(w, r)
	})
}

// Authorization is a point-in-time decision. Subsequent fetches re-check both
// endpoint devices and current contact policy; revocation cannot recall data.
func (a *API) messaging(w http.ResponseWriter, r *http.Request) {
	tx, s, err := a.authenticated(r, "")
	if err != nil {
		authError(w, err)
		return
	}
	if tx.Commit(r.Context()) != nil {
		unavailable(w)
		return
	}
	if strings.HasSuffix(r.URL.Path, "/events") {
		a.messagingEvents(w, r, s)
		return
	}
	var attempts int
	err = a.db.QueryRow(r.Context(), `INSERT INTO messaging_limits(device_id,window_start,attempts) VALUES($1,clock_timestamp(),1) ON CONFLICT(device_id) DO UPDATE SET attempts=CASE WHEN messaging_limits.window_start<clock_timestamp()-interval '1 minute' THEN 1 ELSE messaging_limits.attempts+1 END,window_start=CASE WHEN messaging_limits.window_start<clock_timestamp()-interval '1 minute' THEN clock_timestamp() ELSE messaging_limits.window_start END RETURNING attempts`, s.Device).Scan(&attempts)
	if err != nil {
		unavailable(w)
		return
	}
	if attempts > 120 {
		fail(w, 429, "messaging quota exceeded")
		return
	}
	switch strings.TrimPrefix(r.URL.Path, "/api/v1/messaging/") {
	case "inventory":
		var remaining int
		if err = a.db.QueryRow(r.Context(), "SELECT count(*) FROM messaging_prekeys WHERE device_id=$1 AND claimed_at IS NULL", s.Device).Scan(&remaining); err != nil {
			unavailable(w)
			return
		}
		reply(w, 200, map[string]int{"remaining": remaining, "target": 50})
	case "bundle":
		if r.Method == "GET" {
			a.readBundle(w, r, s)
		} else {
			a.publishBundle(w, r, s)
		}
	case "claim":
		a.claimBundle(w, r, s)
	case "envelopes":
		if r.Method == "POST" {
			a.submitEnvelope(w, r, s)
		} else {
			a.fetchEnvelopes(w, r, s)
		}
	case "ack":
		a.ackEnvelopes(w, r, s)
	case "status":
		a.envelopeStatus(w, r, s)
	}
}
func (a *API) publishBundle(w http.ResponseWriter, r *http.Request, s session) {
	var b publicBundle
	if decode(r, &b) != nil || b.Account != s.Identity || b.Device != s.Device || b.Suite != messagingSuite || b.Epoch != 1 || len(b.Prekeys) > 50 || b.RootKey != "" || b.DeviceKey != "" {
		fail(w, 400, "invalid messaging bundle")
		return
	}
	curve, cok := decodeSized(b.Curve, 32)
	signing, sok := decodeSized(b.Signing, 32)
	rootProof, rok := decodeSized(b.AccountProof, 64)
	deviceProof, dok := decodeSized(b.DeviceProof, 64)
	if !cok || !sok || !rok || !dok || bytes.Equal(curve, make([]byte, 32)) {
		fail(w, 400, "invalid public material")
		return
	}
	var root, device []byte
	err := a.db.QueryRow(r.Context(), `SELECT i.root_key,d.public_key FROM identities i JOIN devices d ON d.identity_id=i.id WHERE i.id=$1 AND d.id=$2 AND d.revoked_at IS NULL`, s.Identity, s.Device).Scan(&root, &device)
	statement := []byte(bindingStatement(a.audience, b))
	if err != nil || !ed25519.Verify(root, statement, rootProof) || !ed25519.Verify(device, statement, deviceProof) {
		fail(w, 401, "invalid messaging authorization")
		return
	}
	seen := map[string]bool{}
	for _, p := range b.Prekeys {
		key, ok := decodeSized(p.Key, 32)
		sig, valid := decodeSized(p.Signature, 64)
		if !ok || !valid || p.ID != p.Key || seen[p.ID] || bytes.Equal(key, make([]byte, 32)) || !ed25519.Verify(signing, []byte(prekeyStatement(b, p)), sig) {
			fail(w, 400, "invalid signed prekey")
			return
		}
		seen[p.ID] = true
	}
	tx, err := a.db.Begin(r.Context())
	if err != nil {
		unavailable(w)
		return
	}
	defer tx.Rollback(context.Background())
	// Serialize publication for this existing account. No old keys are replaced.
	if _, err = tx.Exec(r.Context(), "SELECT id FROM devices WHERE id=$1 FOR KEY SHARE", s.Device); err != nil {
		unavailable(w)
		return
	}
	if _, err = tx.Exec(r.Context(), "SELECT id FROM identities WHERE id=$1 FOR UPDATE", s.Identity); err != nil {
		unavailable(w)
		return
	}
	var other bool
	err = tx.QueryRow(r.Context(), "SELECT EXISTS(SELECT 1 FROM messaging_devices WHERE identity_id=$1 AND device_id<>$2)", s.Identity, s.Device).Scan(&other)
	if err != nil {
		unavailable(w)
		return
	}
	if other {
		fail(w, 409, "additional messaging devices are not supported in M4")
		return
	}
	_, err = tx.Exec(r.Context(), `INSERT INTO messaging_devices(device_id,identity_id,suite,epoch,curve_key,signing_key,account_proof,device_proof) VALUES($1,$2,$3,$4,$5,$6,$7,$8) ON CONFLICT(device_id) DO NOTHING`, s.Device, s.Identity, b.Suite, b.Epoch, curve, signing, rootProof, deviceProof)
	if err != nil {
		unavailable(w)
		return
	}
	var oldCurve, oldSigning []byte
	if err = tx.QueryRow(r.Context(), "SELECT curve_key,signing_key FROM messaging_devices WHERE device_id=$1 FOR UPDATE", s.Device).Scan(&oldCurve, &oldSigning); err != nil {
		unavailable(w)
		return
	}
	if !bytes.Equal(curve, oldCurve) || !bytes.Equal(signing, oldSigning) {
		fail(w, 409, "messaging identity replacement is not authorized")
		return
	}
	var count int
	if err = tx.QueryRow(r.Context(), "SELECT count(*) FROM messaging_prekeys WHERE device_id=$1", s.Device).Scan(&count); err != nil {
		unavailable(w)
		return
	}
	// Claimed records remain as anti-reuse tombstones. A bounded account fails
	// explicitly rather than forgetting consumed keys and accepting their reuse.
	if count+len(b.Prekeys) > 10000 {
		fail(w, 429, "prekey inventory lifetime limit reached")
		return
	}
	for _, p := range b.Prekeys {
		key, _ := decodeSized(p.Key, 32)
		sig, _ := decodeSized(p.Signature, 64)
		if _, err = tx.Exec(r.Context(), `INSERT INTO messaging_prekeys(device_id,key_id,public_key,signature) VALUES($1,$2,$3,$4) ON CONFLICT(device_id,key_id) DO NOTHING`, s.Device, p.ID, key, sig); err != nil {
			unavailable(w)
			return
		}
	}
	if tx.Commit(r.Context()) != nil {
		unavailable(w)
		return
	}
	reply(w, 200, map[string]bool{"ok": true})
}

func messagingPolicy(r *http.Request, tx pgx.Tx, self, target string) error {
	if self == target {
		return errDenied
	}
	if err := lockContactAccounts(r, tx, self, target); err != nil {
		return err
	}
	var allowed bool
	err := tx.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM contact_relationships WHERE low_id=LEAST($1::text,$2::text) AND high_id=GREATEST($1::text,$2::text) AND state='accepted') AND NOT EXISTS(SELECT 1 FROM contact_blocks WHERE (owner_id=$1 AND target_id=$2) OR (owner_id=$2 AND target_id=$1))`, self, target).Scan(&allowed)
	if err == nil && !allowed {
		return errDenied
	}
	return err
}
func (a *API) claimBundle(w http.ResponseWriter, r *http.Request, s session) {
	var in struct {
		Account string `json:"account"`
	}
	if decode(r, &in) != nil || len(in.Account) != 48 {
		fail(w, 400, "invalid recipient")
		return
	}
	tx, err := a.db.Begin(r.Context())
	if err != nil {
		unavailable(w)
		return
	}
	defer tx.Rollback(context.Background())
	if err = messagingPolicy(r, tx, s.Identity, in.Account); err != nil {
		fail(w, 403, "contact messaging unavailable")
		return
	}
	var b publicBundle
	var curve, signing, rp, dp, root, device []byte
	err = tx.QueryRow(r.Context(), `SELECT m.device_id,m.suite,m.epoch,m.curve_key,m.signing_key,m.account_proof,m.device_proof,i.root_key,d.public_key FROM messaging_devices m JOIN devices d ON d.id=m.device_id JOIN identities i ON i.id=m.identity_id WHERE m.identity_id=$1 AND d.revoked_at IS NULL FOR UPDATE OF m`, in.Account).Scan(&b.Device, &b.Suite, &b.Epoch, &curve, &signing, &rp, &dp, &root, &device)
	if errors.Is(err, pgx.ErrNoRows) {
		fail(w, 404, "recipient messaging not configured")
		return
	}
	if err != nil {
		unavailable(w)
		return
	}
	var p publicPrekey
	var key, sig []byte
	err = tx.QueryRow(r.Context(), `UPDATE messaging_prekeys SET claimed_at=clock_timestamp() WHERE (device_id,key_id)=(SELECT device_id,key_id FROM messaging_prekeys WHERE device_id=$1 AND claimed_at IS NULL ORDER BY key_id LIMIT 1 FOR UPDATE) RETURNING key_id,public_key,signature`, b.Device).Scan(&p.ID, &key, &sig)
	if errors.Is(err, pgx.ErrNoRows) {
		reply(w, 409, map[string]string{"error": "recipient has no unused prekeys", "code": "prekeys_exhausted"})
		return
	}
	if err != nil {
		unavailable(w)
		return
	}
	b.Account = in.Account
	b.Curve = encoding.EncodeToString(curve)
	b.Signing = encoding.EncodeToString(signing)
	b.AccountProof = encoding.EncodeToString(rp)
	b.DeviceProof = encoding.EncodeToString(dp)
	b.RootKey = encoding.EncodeToString(root)
	b.DeviceKey = encoding.EncodeToString(device)
	p.Key = encoding.EncodeToString(key)
	p.Signature = encoding.EncodeToString(sig)
	b.Prekeys = []publicPrekey{p}
	if tx.Commit(r.Context()) != nil {
		unavailable(w)
		return
	}
	reply(w, 200, b)
}

type envelopeInput struct {
	Version    int    `json:"version"`
	ID         string `json:"id"`
	Recipient  string `json:"recipient"`
	Device     string `json:"recipient_device"`
	Suite      string `json:"suite"`
	Type       int    `json:"type"`
	Ciphertext string `json:"ciphertext"`
}

func validMessageID(id string) bool { b, ok := decodeSized(id, 16); return ok && len(b) == 16 }
func (a *API) submitEnvelope(w http.ResponseWriter, r *http.Request, s session) {
	var in envelopeInput
	if decode(r, &in) != nil || in.Version != 1 || !validMessageID(in.ID) || in.Suite != messagingSuite || (in.Type != 0 && in.Type != 1) || len(in.Recipient) != 48 || len(in.Device) != 48 {
		fail(w, 400, "invalid envelope")
		return
	}
	data, e := encoding.DecodeString(in.Ciphertext)
	if e != nil || len(data) < 1 || len(data) > 65536 || encoding.EncodeToString(data) != in.Ciphertext {
		fail(w, 400, "invalid ciphertext encoding or size")
		return
	}
	canonical, _ := json.Marshal(in)
	digest := sha256.Sum256(canonical)
	tx, err := a.db.Begin(r.Context())
	if err != nil {
		unavailable(w)
		return
	}
	defer tx.Rollback(context.Background())
	if _, err = tx.Exec(r.Context(), "SELECT id FROM devices WHERE id=$1 OR id=$2 ORDER BY id FOR KEY SHARE", s.Device, in.Device); err != nil {
		unavailable(w)
		return
	}
	if err = messagingPolicy(r, tx, s.Identity, in.Recipient); err != nil {
		fail(w, 403, "contact messaging unavailable")
		return
	}
	var sequence int64
	err = tx.QueryRow(r.Context(), `SELECT m.next_sequence FROM messaging_devices m JOIN devices d ON d.id=m.device_id WHERE m.device_id=$1 AND m.identity_id=$2 AND d.revoked_at IS NULL FOR UPDATE OF m`, in.Device, in.Recipient).Scan(&sequence)
	if err != nil {
		fail(w, 404, "recipient device unavailable")
		return
	}
	var configured bool
	if err = tx.QueryRow(r.Context(), "SELECT EXISTS(SELECT 1 FROM messaging_devices WHERE device_id=$1)", s.Device).Scan(&configured); err != nil {
		unavailable(w)
		return
	}
	if !configured {
		fail(w, 409, "publish messaging identity first")
		return
	}
	var old []byte
	var accepted, expires time.Time
	err = tx.QueryRow(r.Context(), "SELECT digest,accepted_at,expires_at FROM messaging_receipts WHERE sender_device=$1 AND message_id=$2", s.Device, in.ID).Scan(&old, &accepted, &expires)
	if err == nil {
		if !bytes.Equal(old, digest[:]) {
			fail(w, 409, "message ID already binds different ciphertext")
			return
		}
		reply(w, 200, map[string]any{"id": in.ID, "state": expiryState(expires), "accepted_at": accepted, "expires_at": expires})
		return
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		unavailable(w)
		return
	}
	var count int
	var size int64
	err = tx.QueryRow(r.Context(), "SELECT count(*),COALESCE(sum(octet_length(ciphertext)),0) FROM messaging_queue WHERE recipient_device=$1 AND expires_at>clock_timestamp()", in.Device).Scan(&count, &size)
	if err != nil {
		unavailable(w)
		return
	}
	if count >= 1000 || size+int64(len(data)) > 16*1024*1024 {
		fail(w, 429, "recipient encrypted queue is full")
		return
	}
	accepted = time.Now().UTC()
	expires = accepted.Add(14 * 24 * time.Hour)
	if _, err = tx.Exec(r.Context(), `INSERT INTO messaging_receipts(sender_device,message_id,recipient_device,digest,accepted_at,expires_at) VALUES($1,$2,$3,$4,$5,$6)`, s.Device, in.ID, in.Device, digest[:], accepted, expires); err != nil {
		unavailable(w)
		return
	}
	// This per-recipient row lock orders cursor allocation and COMMIT, avoiding
	// the sequence-allocation/commit inversion of a global BIGSERIAL queue.
	sequence++
	if _, err = tx.Exec(r.Context(), "UPDATE messaging_devices SET next_sequence=$2 WHERE device_id=$1", in.Device, sequence); err != nil {
		unavailable(w)
		return
	}
	if _, err = tx.Exec(r.Context(), `INSERT INTO messaging_queue(recipient_device,sequence,sender_identity,sender_device,message_id,message_type,ciphertext,expires_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8)`, in.Device, sequence, s.Identity, s.Device, in.ID, in.Type, data, expires); err != nil {
		unavailable(w)
		return
	}
	if tx.Commit(r.Context()) != nil {
		unavailable(w)
		return
	}
	a.notifyMessaging(in.Device)
	reply(w, 202, map[string]any{"id": in.ID, "state": "accepted", "accepted_at": accepted, "expires_at": expires})
}
func expiryState(expires time.Time) string {
	if !expires.After(time.Now()) {
		return "expired"
	}
	return "accepted"
}
func (a *API) fetchEnvelopes(w http.ResponseWriter, r *http.Request, s session) {
	after, err := strconv.ParseInt(r.URL.Query().Get("after"), 10, 64)
	if r.URL.Query().Get("after") == "" {
		after = 0
		err = nil
	}
	if err != nil || after < 0 {
		fail(w, 400, "invalid cursor")
		return
	}
	rows, err := a.db.Query(r.Context(), `SELECT q.sequence,q.sender_identity,q.sender_device,q.message_id,q.message_type,q.ciphertext,q.expires_at FROM messaging_queue q JOIN devices d ON d.id=q.sender_device WHERE q.recipient_device=$1 AND q.sequence>$2 AND q.expires_at>clock_timestamp() AND d.revoked_at IS NULL AND EXISTS(SELECT 1 FROM contact_relationships c WHERE c.low_id=LEAST($3::text,q.sender_identity) AND c.high_id=GREATEST($3::text,q.sender_identity) AND c.state='accepted') AND NOT EXISTS(SELECT 1 FROM contact_blocks b WHERE (b.owner_id=$3 AND b.target_id=q.sender_identity) OR (b.owner_id=q.sender_identity AND b.target_id=$3)) ORDER BY q.sequence LIMIT 50`, s.Device, after, s.Identity)
	if err != nil {
		unavailable(w)
		return
	}
	defer rows.Close()
	items := []map[string]any{}
	next := after
	for rows.Next() {
		var seq int64
		var sender, device, id string
		var kind int
		var ciphertext []byte
		var expiry time.Time
		if err = rows.Scan(&seq, &sender, &device, &id, &kind, &ciphertext, &expiry); err != nil {
			unavailable(w)
			return
		}
		items = append(items, map[string]any{"sequence": strconv.FormatInt(seq, 10), "sender": sender, "sender_device": device, "id": id, "type": kind, "suite": messagingSuite, "version": 1, "ciphertext": encoding.EncodeToString(ciphertext), "expires_at": expiry})
		next = seq
	}
	if rows.Err() != nil {
		unavailable(w)
		return
	}
	reply(w, 200, map[string]any{"items": items, "next": strconv.FormatInt(next, 10)})
}
func (a *API) ackEnvelopes(w http.ResponseWriter, r *http.Request, s session) {
	var in struct {
		Sequences []string `json:"sequences"`
	}
	if decode(r, &in) != nil || len(in.Sequences) < 1 || len(in.Sequences) > 50 {
		fail(w, 400, "invalid acknowledgement")
		return
	}
	seq := []int64{}
	for _, value := range in.Sequences {
		n, e := strconv.ParseInt(value, 10, 64)
		if e != nil || n < 1 {
			fail(w, 400, "invalid sequence")
			return
		}
		seq = append(seq, n)
	}
	// Recipient identity is never supplied by the caller. Exact ack is idempotent;
	// a client's highest observed cursor cannot delete unaccepted gaps.
	if _, err := a.db.Exec(r.Context(), "DELETE FROM messaging_queue WHERE recipient_device=$1 AND sequence=ANY($2::bigint[])", s.Device, seq); err != nil {
		unavailable(w)
		return
	}
	w.WriteHeader(204)
}
func (a *API) envelopeStatus(w http.ResponseWriter, r *http.Request, s session) {
	id := r.URL.Query().Get("id")
	if !validMessageID(id) {
		fail(w, 400, "invalid message ID")
		return
	}
	var accepted, expires time.Time
	err := a.db.QueryRow(r.Context(), "SELECT accepted_at,expires_at FROM messaging_receipts WHERE sender_device=$1 AND message_id=$2", s.Device, id).Scan(&accepted, &expires)
	if errors.Is(err, pgx.ErrNoRows) {
		fail(w, 404, "message unavailable")
		return
	}
	if err != nil {
		unavailable(w)
		return
	}
	reply(w, 200, map[string]any{"id": id, "state": expiryState(expires), "accepted_at": accepted, "expires_at": expires})
}
func (a *API) CleanupMessaging(ctx context.Context) {
	// Queue content disappears at 14 days. Receipt tombstones survive another
	// day to bound dedup/status metadata; IDs are scoped to a sender device.
	_, _ = a.db.Exec(ctx, "DELETE FROM messaging_queue WHERE expires_at<=clock_timestamp()")
	_, _ = a.db.Exec(ctx, "DELETE FROM messaging_receipts WHERE expires_at<clock_timestamp()-interval '1 day'")
}
