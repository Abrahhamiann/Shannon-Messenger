package identity

import (
	"context"
	"encoding/base64"
	"errors"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

var usernamePattern = regexp.MustCompile(`^[a-z][a-z0-9_]{2,31}$`)

var errInvitationInvalid = errors.New("invitation_invalid")
var errInvitationExpired = errors.New("invitation_expired")
var errInvitationRevoked = errors.New("invitation_revoked")

func discoveryFailure(w http.ResponseWriter, err error) bool {
	code := ""
	switch {
	case errors.Is(err, errInvitationInvalid):
		code = "invitation_invalid"
	case errors.Is(err, errInvitationExpired):
		code = "invitation_expired"
	case errors.Is(err, errInvitationRevoked):
		code = "invitation_revoked"
	case errors.Is(err, pgx.ErrNoRows):
		code = "contact_not_found"
	}
	if code == "" {
		return false
	}
	reply(w, 404, map[string]string{"error": "contact unavailable", "code": code})
	return true
}

func normalizeUsername(v string) string {
	return strings.ToLower(strings.TrimPrefix(strings.TrimSpace(v), "@"))
}

type contactInput struct {
	Username     string `json:"username"`
	Discoverable bool   `json:"discoverable"`
	Invitation   string `json:"invitation"`
	Target       string `json:"target"`
}
type contactProfile struct {
	ID       string `json:"id"`
	Username string `json:"username"`
}

func (a *API) mountContacts(mux *http.ServeMux) {
	for _, route := range []string{
		"GET /api/v1/contacts", "GET /api/v1/contacts/profile", "PUT /api/v1/contacts/profile",
		"POST /api/v1/contacts/lookup", "POST /api/v1/contacts/resolve",
		"POST /api/v1/contacts/invitation", "DELETE /api/v1/contacts/invitation",
		"POST /api/v1/contacts/request", "POST /api/v1/contacts/accept", "POST /api/v1/contacts/decline",
		"POST /api/v1/contacts/block", "POST /api/v1/contacts/unblock", "POST /api/v1/contacts/remove",
	} {
		mux.Handle(route, a.guard(http.HandlerFunc(a.contacts)))
	}
}

// All social mutations lock both account rows in lexical order. This serializes
// request/accept/block with discovery changes and invitation rotation/revocation.
func lockContactAccounts(r *http.Request, tx pgx.Tx, self, target string) error {
	rows, err := tx.Query(r.Context(), "SELECT id FROM identities WHERE id=$1 OR id=$2 ORDER BY id FOR UPDATE", self, target)
	if err != nil {
		return err
	}
	defer rows.Close()
	count := 0
	for rows.Next() {
		count++
	}
	if rows.Err() != nil {
		return rows.Err()
	}
	if count != 2 {
		return pgx.ErrNoRows
	}
	return nil
}
func contactBlocked(r *http.Request, tx pgx.Tx, self, target string) (bool, error) {
	var blocked bool
	err := tx.QueryRow(r.Context(), `SELECT EXISTS(SELECT 1 FROM contact_blocks WHERE (owner_id=$1 AND target_id=$2) OR (owner_id=$2 AND target_id=$1))`, self, target).Scan(&blocked)
	return blocked, err
}
func (a *API) contacts(w http.ResponseWriter, r *http.Request) {
	tx, s, err := a.authenticated(r, "")
	if err != nil {
		authError(w, err)
		return
	}
	defer tx.Rollback(context.Background())
	// Release the authentication connection before the independently committed
	// quota write. Holding it while acquiring a second connection can exhaust a
	// small pool when concurrent requests wait on the same device/session lock.
	if tx.Commit(r.Context()) != nil {
		unavailable(w)
		return
	}
	// Durable account-wide quota survives process restarts and multiple API replicas.
	// Commit quota independently, including malformed, hidden, and missing lookups.
	var attempts int
	err = a.db.QueryRow(r.Context(), `INSERT INTO contact_limits(identity_id,window_start,attempts) VALUES($1,clock_timestamp(),1)
 ON CONFLICT(identity_id) DO UPDATE SET attempts=CASE WHEN contact_limits.window_start < clock_timestamp()-interval '1 minute' THEN 1 ELSE contact_limits.attempts+1 END,
 window_start=CASE WHEN contact_limits.window_start < clock_timestamp()-interval '1 minute' THEN clock_timestamp() ELSE contact_limits.window_start END RETURNING attempts`, s.Identity).Scan(&attempts)
	if err != nil {
		unavailable(w)
		return
	}
	if attempts > 30 {
		w.Header().Set("Retry-After", "60")
		fail(w, 429, "try later")
		return
	}
	// Re-check revocation and retain the M3 session lock for the actual operation.
	tx, s, err = a.authenticated(r, "")
	if err != nil {
		authError(w, err)
		return
	}
	defer tx.Rollback(context.Background())
	var in contactInput
	if r.Method == "POST" || r.Method == "PUT" {
		if decode(r, &in) != nil {
			fail(w, 400, "invalid request")
			return
		}
	}
	in.Username = normalizeUsername(in.Username)
	op := strings.TrimPrefix(r.URL.Path, "/api/v1/contacts")
	finish := func(v any) {
		if tx.Commit(r.Context()) != nil {
			unavailable(w)
			return
		}
		reply(w, 200, v)
	}
	ok := map[string]bool{"ok": true}
	if op == "/profile" {
		if r.Method == "PUT" {
			if in.Username != "" && !usernamePattern.MatchString(in.Username) {
				fail(w, 400, "invalid username")
				return
			}
			if _, err = tx.Exec(r.Context(), "SELECT id FROM identities WHERE id=$1 FOR UPDATE", s.Identity); err != nil {
				unavailable(w)
				return
			}
			_, err = tx.Exec(r.Context(), `INSERT INTO contact_profiles(identity_id,username,discoverable) VALUES($1,NULLIF($2,''),$3) ON CONFLICT(identity_id) DO UPDATE SET username=EXCLUDED.username,discoverable=EXCLUDED.discoverable`, s.Identity, in.Username, in.Discoverable && in.Username != "")
			if err != nil {
				var pe *pgconn.PgError
				if errors.As(err, &pe) && pe.Code == "23505" {
					fail(w, 409, "username unavailable")
				} else {
					unavailable(w)
				}
				return
			}
		}
		name := ""
		visible := false
		err = tx.QueryRow(r.Context(), "SELECT COALESCE(username,''),discoverable FROM contact_profiles WHERE identity_id=$1", s.Identity).Scan(&name, &visible)
		if err != nil && !errors.Is(err, pgx.ErrNoRows) {
			unavailable(w)
			return
		}
		finish(map[string]any{"username": name, "discoverable": visible})
		return
	}
	if op == "/invitation" {
		if _, err = tx.Exec(r.Context(), "SELECT id FROM identities WHERE id=$1 FOR UPDATE", s.Identity); err != nil {
			unavailable(w)
			return
		}
		// Preserve a bounded, owner-free capability tombstone before replacement
		// or revocation, so a bearer can distinguish it from a malformed QR.
		_, err = tx.Exec(r.Context(), `INSERT INTO contact_invitation_history(token_hash,expires_at,revoked_at) SELECT token_hash,expires_at,clock_timestamp() FROM contact_invitations WHERE owner_id=$1 ON CONFLICT(token_hash) DO NOTHING`, s.Identity)
		if err != nil {
			unavailable(w)
			return
		}
		if r.Method == "DELETE" {
			_, err = tx.Exec(r.Context(), "DELETE FROM contact_invitations WHERE owner_id=$1", s.Identity)
			if err != nil {
				unavailable(w)
				return
			}
			finish(ok)
			return
		}
		token := randomToken()
		expires := time.Now().Add(24 * time.Hour)
		_, err = tx.Exec(r.Context(), `INSERT INTO contact_invitations(owner_id,token_hash,expires_at) VALUES($1,$2,$3) ON CONFLICT(owner_id) DO UPDATE SET token_hash=EXCLUDED.token_hash,expires_at=EXCLUDED.expires_at`, s.Identity, tokenHash(token), expires)
		if err != nil {
			unavailable(w)
			return
		}
		finish(map[string]any{"invitation": token, "expires_at": expires})
		return
	}
	if op == "" {
		a.listContacts(w, r, tx, s.Identity)
		return
	}
	target := in.Target
	if op == "/lookup" || op == "/resolve" || op == "/request" {
		// Requests need a current username or invitation, never a bare enumerable ID.
		if (in.Invitation == "") == (in.Username == "") {
			fail(w, 400, "provide one discovery method")
			return
		}
		resolve := func() (contactProfile, error) {
			var p contactProfile
			if in.Invitation != "" {
				if !validToken(in.Invitation) {
					return p, errInvitationInvalid
				}
				var expires time.Time
				e := tx.QueryRow(r.Context(), `SELECT i.owner_id,COALESCE(p.username,''),i.expires_at FROM contact_invitations i LEFT JOIN contact_profiles p ON p.identity_id=i.owner_id WHERE i.token_hash=$1`, tokenHash(in.Invitation)).Scan(&p.ID, &p.Username, &expires)
				if errors.Is(e, pgx.ErrNoRows) {
					var revoked *time.Time
					e = tx.QueryRow(r.Context(), `SELECT expires_at,revoked_at FROM contact_invitation_history WHERE token_hash=$1`, tokenHash(in.Invitation)).Scan(&expires, &revoked)
					if errors.Is(e, pgx.ErrNoRows) {
						return p, errInvitationInvalid
					}
					if e != nil {
						return p, e
					}
					if revoked != nil {
						return p, errInvitationRevoked
					}
					return p, errInvitationExpired
				}
				if e == nil && !expires.After(time.Now()) {
					return p, errInvitationExpired
				}
				return p, e
			}
			if !usernamePattern.MatchString(in.Username) {
				return p, pgx.ErrNoRows
			}
			e := tx.QueryRow(r.Context(), `SELECT identity_id,username FROM contact_profiles WHERE username=$1 AND discoverable`, in.Username).Scan(&p.ID, &p.Username)
			return p, e
		}
		p, e := resolve()
		// Missing/hidden usernames and blocked accounts share one diagnosis.
		if discoveryFailure(w, e) {
			return
		}
		if e == nil && p.ID == s.Identity {
			code := "own_contact"
			if in.Invitation != "" {
				code = "own_invitation"
			}
			reply(w, 404, map[string]string{"error": "contact unavailable", "code": code})
			return
		}
		if e != nil {
			unavailable(w)
			return
		}
		target = p.ID
		if err = lockContactAccounts(r, tx, s.Identity, target); err != nil {
			unavailable(w)
			return
		}
		// Re-read after locks: concurrent rename, hiding, or revocation wins safely.
		p, e = resolve()
		if discoveryFailure(w, e) {
			return
		}
		if e == nil && p.ID != target {
			fail(w, 404, "contact unavailable")
			return
		}
		if e != nil {
			unavailable(w)
			return
		}
		blocked, e := contactBlocked(r, tx, s.Identity, target)
		if e != nil {
			unavailable(w)
			return
		}
		if blocked {
			reply(w, 404, map[string]string{"error": "contact unavailable", "code": "contact_not_found"})
			return
		}
		if op != "/request" {
			finish(p)
			return
		}
		// Bind the confirmation to the previewed stable account, avoiding name reuse races.
		if in.Target != target {
			fail(w, 409, "preview changed; search again")
			return
		}
		_, err = tx.Exec(r.Context(), `INSERT INTO contact_relationships(low_id,high_id,sender_id,state) VALUES(LEAST($1::text,$2::text),GREATEST($1::text,$2::text),$1,'pending') ON CONFLICT DO NOTHING`, s.Identity, target)
		if err != nil {
			unavailable(w)
			return
		}
		var kind string
		err = tx.QueryRow(r.Context(), `SELECT CASE WHEN state='accepted' THEN 'accepted' WHEN sender_id=$1 THEN 'outgoing' ELSE 'incoming' END FROM contact_relationships WHERE low_id=LEAST($1::text,$2::text) AND high_id=GREATEST($1::text,$2::text)`, s.Identity, target).Scan(&kind)
		if err != nil {
			unavailable(w)
			return
		}
		finish(map[string]string{"kind": kind})
		return
	}
	if target == s.Identity || len(target) != 48 || !strings.HasPrefix(target, "shn1_") {
		fail(w, 400, "invalid contact")
		return
	}
	if _, e := base64.RawURLEncoding.DecodeString(strings.TrimPrefix(target, "shn1_")); e != nil {
		fail(w, 400, "invalid contact")
		return
	}
	if err = lockContactAccounts(r, tx, s.Identity, target); errors.Is(err, pgx.ErrNoRows) {
		fail(w, 404, "contact unavailable")
		return
	} else if err != nil {
		unavailable(w)
		return
	}
	switch op {
	case "/remove":
		// A participant may end this mutual relationship, never another account.
		// Public identities, messaging keys/history and blocks remain untouched.
		_, err = tx.Exec(r.Context(), "DELETE FROM contact_relationships WHERE low_id=LEAST($1::text,$2::text) AND high_id=GREATEST($1::text,$2::text) AND state='accepted'", s.Identity, target)
	case "/block":
		_, err = tx.Exec(r.Context(), "INSERT INTO contact_blocks(owner_id,target_id) VALUES($1,$2) ON CONFLICT DO NOTHING", s.Identity, target)
		if err == nil {
			_, err = tx.Exec(r.Context(), "DELETE FROM contact_relationships WHERE low_id=LEAST($1::text,$2::text) AND high_id=GREATEST($1::text,$2::text)", s.Identity, target)
		}
	case "/unblock":
		_, err = tx.Exec(r.Context(), "DELETE FROM contact_blocks WHERE owner_id=$1 AND target_id=$2", s.Identity, target)
	case "/accept", "/decline":
		blocked, e := contactBlocked(r, tx, s.Identity, target)
		if e != nil {
			unavailable(w)
			return
		}
		if blocked {
			fail(w, 404, "contact unavailable")
			return
		}
		sql := `UPDATE contact_relationships SET state='accepted' WHERE low_id=LEAST($1::text,$2::text) AND high_id=GREATEST($1::text,$2::text) AND sender_id=$2 AND state='pending'`
		if op == "/decline" {
			sql = `DELETE FROM contact_relationships WHERE low_id=LEAST($1::text,$2::text) AND high_id=GREATEST($1::text,$2::text) AND sender_id=$2 AND state='pending'`
		}
		var result pgconn.CommandTag
		result, err = tx.Exec(r.Context(), sql, s.Identity, target)
		if err == nil && result.RowsAffected() != 1 {
			fail(w, 404, "request unavailable")
			return
		}
	default:
		fail(w, 404, "not found")
		return
	}
	if err != nil {
		unavailable(w)
		return
	}
	finish(ok)
}

func (a *API) listContacts(w http.ResponseWriter, r *http.Request, tx pgx.Tx, self string) {
	// Keyset pagination for every relation category; no global directory endpoint.
	cursor := r.URL.Query().Get("after")
	rows, err := tx.Query(r.Context(), `SELECT x.id,COALESCE(p.username,''),x.kind FROM (
 SELECT CASE WHEN low_id=$1 THEN high_id ELSE low_id END AS id,
 CASE WHEN state='accepted' THEN 'accepted' WHEN sender_id=$1 THEN 'outgoing' ELSE 'incoming' END AS kind FROM contact_relationships WHERE low_id=$1 OR high_id=$1
 UNION ALL SELECT target_id,'blocked' FROM contact_blocks WHERE owner_id=$1
 ) x LEFT JOIN contact_profiles p ON p.identity_id=x.id WHERE x.id>$2 ORDER BY x.id LIMIT 101`, self, cursor)
	if err != nil {
		unavailable(w)
		return
	}
	type item struct {
		ID       string `json:"id"`
		Username string `json:"username"`
		Kind     string `json:"kind"`
	}
	items := []item{}
	for rows.Next() {
		var v item
		if err = rows.Scan(&v.ID, &v.Username, &v.Kind); err != nil {
			break
		}
		items = append(items, v)
	}
	rows.Close()
	if err != nil || rows.Err() != nil {
		unavailable(w)
		return
	}
	next := ""
	if len(items) > 100 {
		items = items[:100]
		next = items[99].ID
	}
	if tx.Commit(r.Context()) != nil {
		unavailable(w)
		return
	}
	reply(w, 200, map[string]any{"items": items, "next": next})
}
