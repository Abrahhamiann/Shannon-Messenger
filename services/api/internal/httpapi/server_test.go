package httpapi

import (
	"context"
	"errors"
	"net/http/httptest"
	"strings"
	"testing"
)

type fakeDB struct{ err error }

func (d fakeDB) Ping(context.Context) error { return d.err }
func TestHealth(t *testing.T) {
	for _, test := range []struct {
		name string
		err  error
		code int
		body string
	}{{"healthy", nil, 200, `"database":"up"`}, {"unavailable", errors.New("secret connection details"), 503, `"database":"down"`}} {
		t.Run(test.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			Handler(fakeDB{test.err}).ServeHTTP(w, httptest.NewRequest("GET", "/health", nil))
			if w.Code != test.code || !strings.Contains(w.Body.String(), test.body) || strings.Contains(w.Body.String(), "secret") {
				t.Fatalf("unexpected response: %d %s", w.Code, w.Body.String())
			}
		})
	}
}
func TestRouting(t *testing.T) {
	for _, test := range []struct {
		method, path string
		code         int
	}{{"POST", "/health", 405}, {"GET", "/missing", 404}} {
		w := httptest.NewRecorder()
		Handler(fakeDB{}).ServeHTTP(w, httptest.NewRequest(test.method, test.path, nil))
		if w.Code != test.code {
			t.Fatalf("got %d", w.Code)
		}
	}
}
