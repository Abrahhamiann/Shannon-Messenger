package identity

import (
	"bytes"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"filippo.io/edwards25519"
	"strings"
)

var encoding = base64.RawURLEncoding

const Header = `{"alg":"Ed25519","typ":"shannon-auth-v1"}`

var headerPart = encoding.EncodeToString([]byte(Header))
var errDenied = errors.New("authentication failed")

func ParseKey(s string) ([]byte, error) {
	b, err := encoding.DecodeString(s)
	if err != nil || len(b) != 32 || encoding.EncodeToString(b) != s {
		return nil, errDenied
	}
	p, err := new(edwards25519.Point).SetBytes(b)
	if err != nil || !bytes.Equal(p.Bytes(), b) || new(edwards25519.Point).MultByCofactor(p).Equal(edwards25519.NewIdentityPoint()) == 1 {
		return nil, errDenied
	}
	return b, nil
}

// PublicID implements the RFC 7638 thumbprint of an RFC 8037 OKP JWK.
func PublicID(key []byte, prefix string) string {
	canonical := `{"crv":"Ed25519","kty":"OKP","x":"` + encoding.EncodeToString(key) + `"}`
	h := sha256.Sum256([]byte(canonical))
	return prefix + encoding.EncodeToString(h[:])
}
func VerifyJWS(jws, payload string, key []byte) bool {
	parts := strings.Split(jws, ".")
	if len(parts) != 3 || parts[0] != headerPart || parts[1] != encoding.EncodeToString([]byte(payload)) {
		return false
	}
	sig, err := encoding.DecodeString(parts[2])
	return err == nil && len(sig) == 64 && encoding.EncodeToString(sig) == parts[2] && ed25519.Verify(key, []byte(parts[0]+"."+parts[1]), sig)
}
func randomToken() string {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		panic("system randomness unavailable")
	}
	return encoding.EncodeToString(b)
}
func tokenHash(s string) []byte { h := sha256.Sum256([]byte(s)); return h[:] }
func validToken(s string) bool {
	b, e := encoding.DecodeString(s)
	return e == nil && len(b) == 32 && encoding.EncodeToString(b) == s
}
