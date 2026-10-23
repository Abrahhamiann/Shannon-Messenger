package tests

import (
	"context"
	"net/http/httptest"
	"os"
	"shannon.local/api/internal/database"
	"shannon.local/api/internal/httpapi"
	"shannon.local/api/migrations"
	"testing"
	"time"
)

func TestPostgresMigrationsAndHealth(t *testing.T) {
	if os.Getenv("SHANNON_INTEGRATION") != "1" {
		t.Skip("set SHANNON_INTEGRATION=1 with local PG variables")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	db, err := database.Open(ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	for range 2 {
		if err := migrations.Apply(ctx, db); err != nil {
			t.Fatal(err)
		}
	}
	var count int
	if err := db.QueryRow(ctx, "SELECT count(*) FROM schema_migrations WHERE version='000001_foundation.sql'").Scan(&count); err != nil || count != 1 {
		t.Fatalf("migration not recorded once: %d %v", count, err)
	}
	w := httptest.NewRecorder()
	httpapi.Handler(db).ServeHTTP(w, httptest.NewRequest("GET", "/health", nil))
	if w.Code != 200 {
		t.Fatalf("health failed: %s", w.Body.String())
	}
}
