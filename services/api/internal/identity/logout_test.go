package identity

import (
	"context"
	"testing"
)

func TestLogoutWithExpiredAccessUsesRefreshWithoutMintingTokens(t *testing.T) {
	c := setup(t)
	tokens := c.register()
	if _, err := c.db.Exec(context.Background(), "UPDATE auth_sessions SET access_expires_at=now()-interval '1 second' WHERE identity_id=$1", tokens.Identity); err != nil {
		t.Fatal(err)
	}
	expectCode(t, c.request("POST", "/api/v1/auth/logout", map[string]string{"refresh_token": tokens.Refresh}, ""), 204)
	expectCode(t, c.request("POST", "/api/v1/auth/refresh", map[string]string{"refresh_token": tokens.Refresh}, ""), 401)
	expectCode(t, c.request("POST", "/api/v1/auth/verify", c.challenge("login"), ""), 200)
}
