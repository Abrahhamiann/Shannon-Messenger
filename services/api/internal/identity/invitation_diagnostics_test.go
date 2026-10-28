package identity

import (
	"context"
	"net/http/httptest"
	"testing"
)

func TestInvitationDiagnostics(t *testing.T) {
	a, b := setup(t), setup(t)
	at, bt := a.register(), b.register()
	call := func(c *testClient, token, op string, body any) *httptest.ResponseRecorder {
		return c.request("POST", "/api/v1/contacts"+op, body, token)
	}
	check := func(token, want string) {
		t.Helper()
		w := call(a, at.Access, "/resolve", map[string]string{"invitation": token})
		expectCode(t, w, 404)
		if got := contactJSON(t, w)["code"]; got != want {
			t.Fatalf("code=%v, want %s", got, want)
		}
	}
	own := contactJSON(t, call(a, at.Access, "/invitation", map[string]string{}))["invitation"].(string)
	check(own, "own_invitation")
	check("invalid", "invitation_invalid")
	old := contactJSON(t, call(b, bt.Access, "/invitation", map[string]string{}))["invitation"].(string)
	fresh := contactJSON(t, call(b, bt.Access, "/invitation", map[string]string{}))["invitation"].(string)
	check(old, "invitation_revoked")
	w := call(a, at.Access, "/resolve", map[string]string{"invitation": fresh})
	expectCode(t, w, 200)
	if contactJSON(t, w)["id"] != bt.Identity {
		t.Fatal("valid invitation resolved to wrong account")
	}
	if _, err := b.db.Exec(context.Background(), "UPDATE contact_invitations SET expires_at=now()-interval '1 second' WHERE owner_id=$1", bt.Identity); err != nil {
		t.Fatal(err)
	}
	check(fresh, "invitation_expired")
	revoked := contactJSON(t, call(b, bt.Access, "/invitation", map[string]string{}))["invitation"].(string)
	expectCode(t, b.request("DELETE", "/api/v1/contacts/invitation", nil, bt.Access), 200)
	check(revoked, "invitation_revoked")
	w = call(a, at.Access, "/lookup", map[string]string{"username": "missing_probe"})
	expectCode(t, w, 404)
	if contactJSON(t, w)["code"] != "contact_not_found" {
		t.Fatal("missing username diagnosis")
	}
}
