package identity

import (
	"context"
	"crypto/ecdh"
	"crypto/ed25519"
	"crypto/rand"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
)

func messagingFixture(t *testing.T) (*testClient, *testClient, Tokens, Tokens) {
	t.Helper()
	t.Setenv("SHANNON_M4_TRANSPORT", "1")
	a, b := setup(t), setup(t)
	at, bt := a.register(), b.register()
	invite := contactJSON(t, b.request("POST", "/api/v1/contacts/invitation", map[string]any{}, bt.Access))["invitation"].(string)
	expectCode(t, a.request("POST", "/api/v1/contacts/request", map[string]string{"invitation": invite, "target": bt.Identity}, at.Access), 200)
	expectCode(t, b.request("POST", "/api/v1/contacts/accept", map[string]string{"target": at.Identity}, bt.Access), 200)
	return a, b, at, bt
}
func testBundle(t *testing.T, c *testClient, tokens Tokens, n int) publicBundle {
	t.Helper()
	signing, secret, e := ed25519.GenerateKey(rand.Reader)
	if e != nil {
		t.Fatal(e)
	}
	curve, e := ecdh.X25519().GenerateKey(rand.Reader)
	if e != nil {
		t.Fatal(e)
	}
	b := publicBundle{Account: tokens.Identity, Device: tokens.Device, Suite: messagingSuite, Epoch: 1, Curve: encoding.EncodeToString(curve.PublicKey().Bytes()), Signing: encoding.EncodeToString(signing)}
	statement := []byte(bindingStatement("test-audience", b))
	b.AccountProof = encoding.EncodeToString(ed25519.Sign(c.root, statement))
	b.DeviceProof = encoding.EncodeToString(ed25519.Sign(c.device, statement))
	for i := 0; i < n; i++ {
		key, e := ecdh.X25519().GenerateKey(rand.Reader)
		if e != nil {
			t.Fatal(e)
		}
		p := publicPrekey{Key: encoding.EncodeToString(key.PublicKey().Bytes())}
		p.ID = p.Key
		p.Signature = encoding.EncodeToString(ed25519.Sign(secret, []byte(prekeyStatement(b, p))))
		b.Prekeys = append(b.Prekeys, p)
	}
	expectCode(t, c.request("PUT", "/api/v1/messaging/bundle", b, tokens.Access), 200)
	return b
}
func testEnvelope(target Tokens) envelopeInput {
	id := make([]byte, 16)
	_, _ = rand.Read(id)
	// Opaque transport fixture, explicitly NOT an encryption demonstration.
	return envelopeInput{Version: 1, ID: encoding.EncodeToString(id), Recipient: target.Identity, Device: target.Device, Suite: messagingSuite, Type: 0, Ciphertext: encoding.EncodeToString([]byte{9, 8, 7, 6, 5})}
}
func TestMessagingQueueAuthorizationDurabilityAndDedup(t *testing.T) {
	a, b, at, bt := messagingFixture(t)
	testBundle(t, a, at, 2)
	testBundle(t, b, bt, 2)
	in := testEnvelope(bt)
	expectCode(t, a.request("POST", "/api/v1/messaging/envelopes", in, ""), 401)
	expectCode(t, a.request("POST", "/api/v1/messaging/envelopes", in, at.Access), 202)
	expectCode(t, a.request("POST", "/api/v1/messaging/envelopes", in, at.Access), 200)
	changed := in
	changed.Ciphertext = encoding.EncodeToString([]byte{1, 2, 3})
	expectCode(t, a.request("POST", "/api/v1/messaging/envelopes", changed, at.Access), 409)
	page := contactJSON(t, b.request("GET", "/api/v1/messaging/envelopes", nil, bt.Access))
	items := page["items"].([]any)
	if len(items) != 1 {
		t.Fatal("duplicate queue entry")
	}
	item := items[0].(map[string]any)
	if item["sender"] != at.Identity || item["sender_device"] != at.Device || item["ciphertext"] != in.Ciphertext {
		t.Fatal("routing or opaque bytes changed")
	}
	var size int
	var maxRetention bool
	if err := a.db.QueryRow(context.Background(), `SELECT octet_length(q.ciphertext),r.expires_at<=r.accepted_at+interval '14 days' FROM messaging_queue q JOIN messaging_receipts r USING(sender_device,message_id) WHERE q.sender_device=$1 AND q.message_id=$2`, at.Device, in.ID).Scan(&size, &maxRetention); err != nil || size != 5 || !maxRetention {
		t.Fatal("storage contract", err)
	}
	// A fresh API instance over the same database simulates service restart.
	restarted := New(b.db, "test-audience", true)
	mux := http.NewServeMux()
	restarted.Mount(mux)
	old := b.handler
	b.handler = mux
	expectCode(t, b.request("GET", "/api/v1/messaging/envelopes", nil, bt.Access), 200)
	b.handler = old
	// A sender cannot acknowledge another device's queue.
	expectCode(t, a.request("POST", "/api/v1/messaging/ack", map[string]any{"sequences": []string{item["sequence"].(string)}}, at.Access), 204)
	if len(contactJSON(t, b.request("GET", "/api/v1/messaging/envelopes", nil, bt.Access))["items"].([]any)) != 1 {
		t.Fatal("foreign acknowledgement erased message")
	}
	ack := map[string]any{"sequences": []string{item["sequence"].(string)}}
	expectCode(t, b.request("POST", "/api/v1/messaging/ack", ack, bt.Access), 204)
	expectCode(t, b.request("POST", "/api/v1/messaging/ack", ack, bt.Access), 204)
	if len(contactJSON(t, b.request("GET", "/api/v1/messaging/envelopes", nil, bt.Access))["items"].([]any)) != 0 {
		t.Fatal("ack did not delete ciphertext")
	}
	status := contactJSON(t, a.request("GET", "/api/v1/messaging/status?id="+in.ID, nil, at.Access))
	if status["state"] != "accepted" {
		t.Fatal("ack must not expose read status")
	}
	expectCode(t, b.request("GET", "/api/v1/messaging/status?id="+in.ID, nil, bt.Access), 404)
}
func TestMessagingPrekeyClaimsAndIdentityReplacement(t *testing.T) {
	a, b, at, bt := messagingFixture(t)
	testBundle(t, a, at, 1)
	bundle := testBundle(t, b, bt, 2)
	if contactJSON(t, b.request("GET", "/api/v1/messaging/inventory", nil, bt.Access))["remaining"] != float64(2) {
		t.Fatal("published inventory count")
	}
	seen := map[string]bool{}
	for i := 0; i < 2; i++ {
		w := a.request("POST", "/api/v1/messaging/claim", map[string]string{"account": bt.Identity}, at.Access)
		expectCode(t, w, 200)
		got := contactJSON(t, w)
		keys := got["prekeys"].([]any)
		key := keys[0].(map[string]any)["id"].(string)
		if seen[key] {
			t.Fatal("one-time key reissued")
		}
		seen[key] = true
	}
	expectCode(t, a.request("POST", "/api/v1/messaging/claim", map[string]string{"account": bt.Identity}, at.Access), 409)
	if contactJSON(t, b.request("GET", "/api/v1/messaging/inventory", nil, bt.Access))["remaining"] != float64(0) {
		t.Fatal("claimed keys remained available")
	}
	// Republishing the same signed bundle cannot resurrect consumed keys.
	expectCode(t, b.request("PUT", "/api/v1/messaging/bundle", bundle, bt.Access), 200)
	expectCode(t, a.request("POST", "/api/v1/messaging/claim", map[string]string{"account": bt.Identity}, at.Access), 409)
	bundle.Curve = encoding.EncodeToString(make([]byte, 32))
	expectCode(t, b.request("PUT", "/api/v1/messaging/bundle", bundle, bt.Access), 400)
}
func TestMessagingBlockedRevokedAndExpired(t *testing.T) {
	a, b, at, bt := messagingFixture(t)
	testBundle(t, a, at, 1)
	testBundle(t, b, bt, 1)
	in := testEnvelope(bt)
	expectCode(t, a.request("POST", "/api/v1/messaging/envelopes", in, at.Access), 202)
	// Expiration changes only isolated test resources.
	if _, err := a.db.Exec(context.Background(), "UPDATE messaging_queue SET expires_at=now()-interval '1 second' WHERE sender_device=$1", at.Device); err != nil {
		t.Fatal(err)
	}
	if len(contactJSON(t, b.request("GET", "/api/v1/messaging/envelopes", nil, bt.Access))["items"].([]any)) != 0 {
		t.Fatal("expired ciphertext delivered")
	}
	expectCode(t, b.request("POST", "/api/v1/contacts/block", map[string]string{"target": at.Identity}, bt.Access), 200)
	expectCode(t, a.request("POST", "/api/v1/messaging/envelopes", testEnvelope(bt), at.Access), 403)
	expectCode(t, a.request("POST", "/api/v1/messaging/claim", map[string]string{"account": bt.Identity}, at.Access), 403)
	expectCode(t, b.request("DELETE", "/api/v1/devices/"+bt.Device, nil, bt.Access), 204)
	expectCode(t, b.request("GET", "/api/v1/messaging/envelopes", nil, bt.Access), 401)
}
func TestMessagingConcurrentCursors(t *testing.T) {
	a, b, at, bt := messagingFixture(t)
	testBundle(t, a, at, 1)
	testBundle(t, b, bt, 1)
	var wait sync.WaitGroup
	for i := 0; i < 8; i++ {
		wait.Go(func() {
			expectCode(t, a.request("POST", "/api/v1/messaging/envelopes", testEnvelope(bt), at.Access), 202)
		})
	}
	wait.Wait()
	items := contactJSON(t, b.request("GET", "/api/v1/messaging/envelopes", nil, bt.Access))["items"].([]any)
	if len(items) != 8 {
		t.Fatal("lost concurrent envelope")
	}
	for i, item := range items {
		if item.(map[string]any)["sequence"] != strconv.Itoa(i+1) {
			t.Fatal("cursor ordering")
		}
	}
}

func TestContactRemovalPreservesIdentityAndStopsMessaging(t *testing.T) {
	a, b, at, bt := messagingFixture(t)
	testBundle(t, a, at, 1)
	testBundle(t, b, bt, 1)
	c := setup(t)
	ct := c.register()
	expectCode(t, a.request("POST", "/api/v1/contacts/remove", map[string]string{"target": bt.Identity}, ""), 401)
	// Another participant cannot remove the A/B relationship.
	expectCode(t, c.request("POST", "/api/v1/contacts/remove", map[string]string{"target": bt.Identity}, ct.Access), 200)
	expectCode(t, a.request("POST", "/api/v1/messaging/envelopes", testEnvelope(bt), at.Access), 202)
	expectCode(t, a.request("POST", "/api/v1/contacts/remove", map[string]string{"target": bt.Identity}, at.Access), 200)
	expectCode(t, a.request("POST", "/api/v1/contacts/remove", map[string]string{"target": bt.Identity}, at.Access), 200)
	expectCode(t, a.request("POST", "/api/v1/messaging/envelopes", testEnvelope(bt), at.Access), 403)
	if len(contactJSON(t, b.request("GET", "/api/v1/messaging/envelopes", nil, bt.Access))["items"].([]any)) != 0 {
		t.Fatal("removed contact still delivered pending ciphertext")
	}
	var identities, devices int
	if a.db.QueryRow(context.Background(), "SELECT count(*) FROM identities WHERE id=$1 OR id=$2", at.Identity, bt.Identity).Scan(&identities) != nil || identities != 2 {
		t.Fatal("contact removal changed accounts")
	}
	if a.db.QueryRow(context.Background(), "SELECT count(*) FROM messaging_devices WHERE device_id=$1 OR device_id=$2", at.Device, bt.Device).Scan(&devices) != nil || devices != 2 {
		t.Fatal("contact removal changed messaging keys")
	}
}
func TestMessagingWebSocketWakeAndShutdown(t *testing.T) {
	a, b, at, bt := messagingFixture(t)
	testBundle(t, a, at, 1)
	testBundle(t, b, bt, 1)
	streamAPI := New(a.db, "test-audience", true)
	mux := http.NewServeMux()
	streamAPI.Mount(mux)
	a.handler = mux
	server := httptest.NewServer(mux)
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	conn, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http")+"/api/v1/messaging/events", &websocket.DialOptions{HTTPHeader: http.Header{"Authorization": []string{"Bearer " + bt.Access}}})
	if err != nil {
		t.Fatal(err)
	}
	defer conn.CloseNow()
	var hint map[string]string
	if err = wsjson.Read(ctx, conn, &hint); err != nil || hint["type"] != "sync_required" {
		t.Fatal("initial sync", err)
	}
	expectCode(t, a.request("POST", "/api/v1/messaging/envelopes", testEnvelope(bt), at.Access), 202)
	if err = wsjson.Read(ctx, conn, &hint); err != nil || hint["type"] != "sync_required" {
		t.Fatal("commit notification", err)
	}
	streamAPI.CloseMessagingStreams()
	if err = wsjson.Read(ctx, conn, &hint); err == nil {
		t.Fatal("stream survived server shutdown")
	}
}

func TestMessagingWebSocketExpiryAndRevocation(t *testing.T) {
	for _, mode := range []string{"expiry", "revocation"} {
		t.Run(mode, func(t *testing.T) {
			a, b, _, bt := messagingFixture(t)
			if mode == "expiry" {
				if _, err := a.db.Exec(context.Background(), "UPDATE auth_sessions SET access_expires_at=clock_timestamp()+interval '1 second' WHERE device_id=$1", bt.Device); err != nil {
					t.Fatal(err)
				}
			}
			streamAPI := New(a.db, "test-audience", true)
			defer streamAPI.CloseMessagingStreams()
			mux := http.NewServeMux()
			streamAPI.Mount(mux)
			server := httptest.NewServer(mux)
			defer server.Close()
			ctx, cancel := context.WithTimeout(context.Background(), 9*time.Second)
			defer cancel()
			url := "ws" + strings.TrimPrefix(server.URL, "http") + "/api/v1/messaging/events"
			if conn, response, err := websocket.Dial(ctx, url, nil); err == nil {
				conn.CloseNow()
				t.Fatal("unauthenticated stream accepted")
			} else if response == nil || response.StatusCode != 401 {
				t.Fatal("missing stream authentication rejection")
			}
			conn, _, err := websocket.Dial(ctx, url, &websocket.DialOptions{HTTPHeader: http.Header{"Authorization": []string{"Bearer " + bt.Access}}})
			if err != nil {
				t.Fatal(err)
			}
			defer conn.CloseNow()
			var hint map[string]string
			if wsjson.Read(ctx, conn, &hint) != nil {
				t.Fatal("initial hint unavailable")
			}
			if mode == "revocation" {
				expectCode(t, b.request("DELETE", "/api/v1/devices/"+bt.Device, nil, bt.Access), 204)
			}
			if err := wsjson.Read(ctx, conn, &hint); err == nil {
				t.Fatal("unauthorized stream remained open")
			}
			if ctx.Err() != nil {
				t.Fatal("stream did not close before test deadline")
			}
		})
	}
}
