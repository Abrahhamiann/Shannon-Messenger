package database

import (
	"context"
	"strings"
	"testing"
)

func TestMissingConfiguration(t *testing.T) {
	t.Setenv("DATABASE_URL", "")
	t.Setenv("PGDATABASE", "")
	t.Setenv("PGUSER", "")
	pool, err := Open(context.Background())
	if pool != nil || err == nil {
		t.Fatal("missing configuration must fail")
	}
}

func TestInvalidConfigurationDoesNotExposeSecrets(t *testing.T) {
	t.Setenv("DATABASE_URL", "postgres://user:secret-value@localhost:invalid/database")
	pool, err := Open(context.Background())
	if pool != nil || err == nil {
		t.Fatal("invalid configuration must fail")
	}
	if strings.Contains(err.Error(), "secret-value") {
		t.Fatal("error leaked credentials")
	}
}
