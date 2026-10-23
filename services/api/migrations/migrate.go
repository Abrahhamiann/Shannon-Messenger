package migrations

import (
	"context"
	"crypto/sha256"
	"embed"
	"fmt"
	"github.com/jackc/pgx/v5/pgxpool"
)

//go:embed *.sql
var files embed.FS

// Apply serializes runners and atomically applies the ordered SQL files.
// Applied files are immutable; their checksum is verified on subsequent runs.
func Apply(ctx context.Context, pool *pgxpool.Pool) error {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(context.Background())
	if _, err = tx.Exec(ctx, "SELECT pg_advisory_xact_lock(736426001)"); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `CREATE TABLE IF NOT EXISTS schema_migrations (version text PRIMARY KEY, checksum text NOT NULL, applied_at timestamptz NOT NULL DEFAULT now())`); err != nil {
		return err
	}
	entries, err := files.ReadDir(".")
	if err != nil {
		return err
	}
	for _, entry := range entries {
		data, err := files.ReadFile(entry.Name())
		if err != nil {
			return err
		}
		hash := fmt.Sprintf("%x", sha256.Sum256(data))
		var existing string
		rows, err := tx.Query(ctx, "SELECT checksum FROM schema_migrations WHERE version=$1", entry.Name())
		if err != nil {
			return err
		}
		found := rows.Next()
		if found {
			err = rows.Scan(&existing)
		}
		rows.Close()
		if err != nil {
			return err
		}
		if rows.Err() != nil {
			return rows.Err()
		}
		if found {
			if existing != hash {
				return fmt.Errorf("migration checksum mismatch: %s", entry.Name())
			}
			continue
		}
		if _, err = tx.Exec(ctx, string(data)); err != nil {
			return fmt.Errorf("migration %s failed: %w", entry.Name(), err)
		}
		if _, err = tx.Exec(ctx, "INSERT INTO schema_migrations(version,checksum) VALUES($1,$2)", entry.Name(), hash); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}
