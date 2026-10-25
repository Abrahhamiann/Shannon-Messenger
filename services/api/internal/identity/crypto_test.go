package identity

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestRFC8032AndProfile(t *testing.T) {
	seed, _ := hex.DecodeString("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60")
	// RFC 8032 section 7.1 test 1: public, published TEST seed only.
	vector := ed25519.NewKeyFromSeed(seed)
	if hex.EncodeToString(vector.Public().(ed25519.PublicKey)) != "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a" {
		t.Fatal("RFC public key mismatch")
	}
	expected := "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
	if hex.EncodeToString(ed25519.Sign(vector, nil)) != expected {
		t.Fatal("RFC signature mismatch")
	}
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	parsed, err := ParseKey(encoding.EncodeToString(pub))
	if err != nil || len(parsed) != 32 {
		t.Fatal("valid key rejected")
	}
	data := "test-only-payload"
	input := headerPart + "." + encoding.EncodeToString([]byte(data))
	proof := input + "." + encoding.EncodeToString(ed25519.Sign(priv, []byte(input)))
	if !VerifyJWS(proof, data, pub) {
		t.Fatal("valid proof rejected")
	}
	if VerifyJWS(proof, data+"modified", pub) {
		t.Fatal("payload substitution accepted")
	}
	other, _, _ := ed25519.GenerateKey(rand.Reader)
	if VerifyJWS(proof, data, other) {
		t.Fatal("wrong key accepted")
	}
	if VerifyJWS("e30."+encoding.EncodeToString([]byte(data))+"."+encoding.EncodeToString(make([]byte, 64)), data, pub) {
		t.Fatal("wrong header accepted")
	}
	for _, key := range []string{"bad", encoding.EncodeToString(make([]byte, 32)), encoding.EncodeToString(append([]byte{1}, make([]byte, 31)...)), encoding.EncodeToString(pub) + "="} {
		if _, err := ParseKey(key); err == nil {
			t.Fatal("invalid key accepted")
		}
	}
	if PublicID(pub, "shn1_") == PublicID(pub, "dev1_") {
		t.Fatal("role labels missing")
	}
}
func TestTransportAndRateBounds(t *testing.T) {
	a := New(nil, "test", false)
	mux := http.NewServeMux()
	a.Mount(mux)
	req := httptest.NewRequest("POST", "/api/v1/auth/challenge", nil)
	req.RemoteAddr = "127.0.0.1:1234"
	req.Header.Set("X-Forwarded-Proto", "https")
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)
	if w.Code != 426 {
		t.Fatal("forwarded headers bypassed TLS")
	}
	now := time.Now()
	for range 60 {
		if !a.allow("127.0.0.1", now) {
			t.Fatal("early limit")
		}
	}
	if a.allow("127.0.0.1", now) {
		t.Fatal("missing IP limit")
	}
	if !a.allow("127.0.0.1", now.Add(time.Minute)) {
		t.Fatal("limit did not expire")
	}
}
