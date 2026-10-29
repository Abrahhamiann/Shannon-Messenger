package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"shannon.local/api/internal/database"
	"shannon.local/api/internal/httpapi"
	"shannon.local/api/internal/identity"
	"time"
)

func run() error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()
	db, err := database.Open(ctx)
	if err != nil {
		return err
	}
	defer db.Close()
	addr := os.Getenv("HTTP_ADDR")
	if addr == "" {
		addr = "127.0.0.1:8080"
	}
	audience := os.Getenv("SHANNON_AUTH_AUDIENCE")
	if audience == "" {
		audience = "shannon.local"
	}
	auth := identity.New(db, audience, os.Getenv("SHANNON_ALLOW_INSECURE_LOCAL_AUTH") == "1")
	defer auth.CloseMessagingStreams()
	go auth.Cleanup(ctx)
	server := &http.Server{Addr: addr, Handler: httpapi.Handler(db, auth.Mount), ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 10 * time.Second, WriteTimeout: 10 * time.Second, IdleTimeout: 60 * time.Second, MaxHeaderBytes: 16 << 10}
	failures := make(chan error, 1)
	cert, key := os.Getenv("TLS_CERT_FILE"), os.Getenv("TLS_KEY_FILE")
	if (cert == "") != (key == "") {
		return errors.New("TLS_CERT_FILE and TLS_KEY_FILE must be configured together")
	}
	go func() {
		if cert != "" {
			failures <- server.ListenAndServeTLS(cert, key)
		} else {
			failures <- server.ListenAndServe()
		}
	}()
	slog.Info("API starting", "address", addr)
	select {
	case err := <-failures:
		if !errors.Is(err, http.ErrServerClosed) {
			return err
		}
	case <-ctx.Done():
		auth.CloseMessagingStreams()
		shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := server.Shutdown(shutdown); err != nil {
			_ = server.Close()
			return err
		}
	}
	return nil
}
func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
	if err := run(); err != nil {
		slog.Error("API stopped", "error", err)
		os.Exit(1)
	}
}
