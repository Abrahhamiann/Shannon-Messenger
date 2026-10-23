package database

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5/pgxpool"
	"os"
	"time"
)

// Open uses standard PG* variables or DATABASE_URL, without logging secrets.
func Open(ctx context.Context) (*pgxpool.Pool, error) {
	if os.Getenv("DATABASE_URL") == "" && (os.Getenv("PGDATABASE") == "" || os.Getenv("PGUSER") == "") {
		return nil, errors.New("set PGDATABASE and PGUSER, or DATABASE_URL")
	}
	cfg, err := pgxpool.ParseConfig(os.Getenv("DATABASE_URL"))
	if err != nil {
		return nil, errors.New("invalid database configuration")
	}
	cfg.MaxConns = 5
	cfg.MinConns = 0
	cfg.ConnConfig.ConnectTimeout = 5 * time.Second
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, errors.New("could not create database pool")
	}
	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := pool.Ping(pingCtx); err != nil {
		pool.Close()
		return nil, errors.New("database connection failed; check PostgreSQL and PG environment variables")
	}
	return pool, nil
}
