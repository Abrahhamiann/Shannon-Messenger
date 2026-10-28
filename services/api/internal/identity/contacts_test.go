package identity

import (
	"context"
	"encoding/json"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
)

func contactJSON(t *testing.T, w *httptest.ResponseRecorder) map[string]any {
	t.Helper()
	var v map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &v); err != nil {
		t.Fatal(err)
	}
	return v
}
func TestContactDiscoveryAndLifecycle(t *testing.T) {
	a, b := setup(t), setup(t)
	at, bt := a.register(), b.register()
	username := "u" + strings.ToLower(strings.ReplaceAll(strings.ReplaceAll(bt.Identity[5:24], "-", "a"), "_", "b"))
	call := func(c *testClient, token, method, op string, body any, code int) *httptest.ResponseRecorder {
		w := c.request(method, "/api/v1/contacts"+op, body, token)
		expectCode(t, w, code)
		return w
	}
	call(a, "", "GET", "", nil, 401)
	call(b, bt.Access, "PUT", "/profile", map[string]any{"username": username, "discoverable": false}, 200)
	call(a, at.Access, "POST", "/lookup", map[string]string{"username": username}, 404)
	call(b, bt.Access, "PUT", "/profile", map[string]any{"username": username, "discoverable": true}, 200)
	call(a, at.Access, "PUT", "/profile", map[string]any{"username": username}, 409)
	lookup := contactJSON(t, call(a, at.Access, "POST", "/lookup", map[string]string{"username": "@" + strings.ToUpper(username)}, 200))
	if lookup["id"] != bt.Identity || len(lookup) != 2 {
		t.Fatal("lookup must expose only stable ID and username")
	}
	body := map[string]string{"username": username, "target": bt.Identity}
	call(a, at.Access, "POST", "/request", map[string]string{"username": username, "target": at.Identity}, 409)
	call(a, at.Access, "POST", "/request", body, 200)
	call(a, at.Access, "POST", "/request", body, 200)
	call(a, at.Access, "POST", "/accept", map[string]string{"target": bt.Identity}, 404)
	incoming := contactJSON(t, call(b, bt.Access, "GET", "", nil, 200))["items"].([]any)
	if len(incoming) != 1 || incoming[0].(map[string]any)["kind"] != "incoming" {
		t.Fatal("missing incoming request")
	}
	call(b, bt.Access, "POST", "/decline", map[string]string{"target": at.Identity}, 200)
	call(a, at.Access, "POST", "/request", body, 200)
	call(b, bt.Access, "POST", "/accept", map[string]string{"target": at.Identity}, 200)
	for _, v := range []struct {
		c   *testClient
		tok string
	}{{a, at.Access}, {b, bt.Access}} {
		items := contactJSON(t, call(v.c, v.tok, "GET", "", nil, 200))["items"].([]any)
		if len(items) != 1 || items[0].(map[string]any)["kind"] != "accepted" {
			t.Fatal("mutual acceptance inconsistent")
		}
	}
	invite := contactJSON(t, call(b, bt.Access, "POST", "/invitation", map[string]string{}, 200))["invitation"].(string)
	call(b, bt.Access, "PUT", "/profile", map[string]any{"username": username + "x", "discoverable": false}, 200)
	call(a, at.Access, "POST", "/lookup", map[string]string{"username": username}, 404)
	resolved := contactJSON(t, call(a, at.Access, "POST", "/resolve", map[string]string{"invitation": invite}, 200))
	if resolved["id"] != bt.Identity {
		t.Fatal("rename changed account")
	}
	call(b, bt.Access, "POST", "/block", map[string]string{"target": at.Identity}, 200)
	call(a, at.Access, "POST", "/resolve", map[string]string{"invitation": invite}, 404)
	call(a, at.Access, "POST", "/request", map[string]string{"invitation": invite, "target": bt.Identity}, 404)
	call(a, at.Access, "POST", "/accept", map[string]string{"target": bt.Identity}, 404)
	call(b, bt.Access, "POST", "/unblock", map[string]string{"target": at.Identity}, 200)
	call(a, at.Access, "POST", "/request", map[string]string{"invitation": invite, "target": bt.Identity}, 200)
	call(b, bt.Access, "DELETE", "/invitation", nil, 200)
	call(a, at.Access, "POST", "/resolve", map[string]string{"invitation": invite}, 404)
	fresh := contactJSON(t, call(b, bt.Access, "POST", "/invitation", map[string]string{}, 200))["invitation"].(string)
	call(b, bt.Access, "POST", "/resolve", map[string]string{"invitation": fresh}, 404)
	if _, err := b.db.Exec(context.Background(), "UPDATE contact_invitations SET expires_at=now()-interval '1 second' WHERE owner_id=$1", bt.Identity); err != nil {
		t.Fatal(err)
	}
	call(a, at.Access, "POST", "/resolve", map[string]string{"invitation": fresh}, 404)
}
func TestContactBlockAcceptRace(t *testing.T) {
	a, b := setup(t), setup(t)
	at, bt := a.register(), b.register()
	inv := contactJSON(t, b.request("POST", "/api/v1/contacts/invitation", map[string]string{}, bt.Access))["invitation"].(string)
	expectCode(t, a.request("POST", "/api/v1/contacts/request", map[string]string{"invitation": inv, "target": bt.Identity}, at.Access), 200)
	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		defer wg.Done()
		expectCode(t, a.request("POST", "/api/v1/contacts/block", map[string]string{"target": bt.Identity}, at.Access), 200)
	}()
	go func() {
		defer wg.Done()
		w := b.request("POST", "/api/v1/contacts/accept", map[string]string{"target": at.Identity}, bt.Access)
		if w.Code != 200 && w.Code != 404 {
			t.Errorf("accept race %d", w.Code)
		}
	}()
	wg.Wait()
	var count int
	if err := a.db.QueryRow(context.Background(), "SELECT count(*) FROM contact_relationships WHERE low_id=LEAST($1::text,$2::text) AND high_id=GREATEST($1::text,$2::text)", at.Identity, bt.Identity).Scan(&count); err != nil {
		t.Fatal(err)
	}
	if count != 0 {
		t.Fatal("block lost to concurrent acceptance")
	}
}
func TestContactQuotaSurvivesMissingLookups(t *testing.T) {
	a := setup(t)
	tok := a.register()
	for i := 0; i < 30; i++ {
		expectCode(t, a.request("POST", "/api/v1/contacts/lookup", map[string]string{"username": "missing"}, tok.Access), 404)
	}
	expectCode(t, a.request("POST", "/api/v1/contacts/lookup", map[string]string{"username": "missing"}, tok.Access), 429)
}

func TestConcurrentContactReadsDoNotExhaustPool(t *testing.T) {
	c := setup(t)
	tok := c.register()
	var wg sync.WaitGroup
	for range 8 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			expectCode(t, c.request("GET", "/api/v1/contacts/profile", nil, tok.Access), 200)
		}()
	}
	wg.Wait()
}
