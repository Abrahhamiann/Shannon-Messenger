package identity

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
)

type messageStream struct {
	device string
	wake   chan struct{}
	cancel context.CancelFunc
}

func (a *API) notifyMessaging(device string) {
	a.streamMu.Lock()
	defer a.streamMu.Unlock()
	for stream := range a.streams {
		if stream.device == device {
			select {
			case stream.wake <- struct{}{}:
			default:
			}
		}
	}
}
func (a *API) CloseMessagingStreams() {
	a.streamMu.Lock()
	defer a.streamMu.Unlock()
	for stream := range a.streams {
		stream.cancel()
	}
}
func (a *API) messagingEvents(w http.ResponseWriter, r *http.Request, s session) {
	if r.URL.RawQuery != "" {
		fail(w, 400, "stream does not accept query parameters")
		return
	}
	token := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
	var expiry time.Time
	if err := a.db.QueryRow(r.Context(), "SELECT LEAST(access_expires_at,expires_at) FROM auth_sessions WHERE access_hash=$1", tokenHash(token)).Scan(&expiry); err != nil {
		fail(w, 401, "session unavailable")
		return
	}
	ctx, cancel := context.WithDeadline(r.Context(), expiry)
	defer cancel()
	stream := &messageStream{device: s.Device, wake: make(chan struct{}, 1), cancel: cancel}
	a.streamMu.Lock()
	count := 0
	for item := range a.streams {
		if item.device == s.Device {
			count++
		}
	}
	if count >= 2 || len(a.streams) >= 256 {
		a.streamMu.Unlock()
		fail(w, 429, "stream limit reached")
		return
	}
	if a.streams == nil {
		a.streams = make(map[*messageStream]struct{})
	}
	a.streams[stream] = struct{}{}
	a.streamMu.Unlock()
	defer func() { a.streamMu.Lock(); delete(a.streams, stream); a.streamMu.Unlock() }()
	conn, err := websocket.Accept(w, r, &websocket.AcceptOptions{CompressionMode: websocket.CompressionDisabled})
	if err != nil {
		return
	}
	defer conn.CloseNow()
	conn.SetReadLimit(256)
	ctx = conn.CloseRead(ctx)
	write := func() error {
		deadline, stop := context.WithTimeout(ctx, 5*time.Second)
		defer stop()
		return wsjson.Write(deadline, conn, map[string]string{"type": "sync_required", "version": "1"})
	}
	if write() != nil {
		return
	}
	check := time.NewTicker(5 * time.Second)
	defer check.Stop()
	heartbeat := time.NewTicker(30 * time.Second)
	defer heartbeat.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-stream.wake:
			if write() != nil {
				return
			}
		case <-check.C:
			checked, stop := context.WithTimeout(ctx, 3*time.Second)
			tx, _, e := a.authenticated(r.WithContext(checked), "")
			if e == nil {
				e = tx.Commit(checked)
			}
			stop()
			if e != nil {
				return
			}
		case <-heartbeat.C:
			// Periodic sync hints repair missed cross-instance notifications. No queue
			// polling and no presence/typing/read events are exposed to another account.
			deadline, stop := context.WithTimeout(ctx, 5*time.Second)
			err = conn.Ping(deadline)
			stop()
			if err != nil || write() != nil {
				return
			}
		}
	}
}
