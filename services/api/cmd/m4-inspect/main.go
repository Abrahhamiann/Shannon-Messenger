// Test-only opaque queue inspection. Never logs envelopes, tokens or keys.
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"shannon.local/api/internal/database"
	"time"
)

func main() {
	if os.Getenv("SHANNON_INTEGRATION") != "1" {
		fmt.Println("isolated integration environment required")
		os.Exit(1)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	db, err := database.Open(ctx)
	if err != nil {
		fmt.Println("sandbox database unavailable")
		os.Exit(1)
	}
	defer db.Close()
	var queued, receipts, plaintext int
	if db.QueryRow(ctx, "SELECT count(*) FROM messaging_queue").Scan(&queued) != nil {
		os.Exit(1)
	}
	if db.QueryRow(ctx, "SELECT count(*) FROM messaging_receipts").Scan(&receipts) != nil {
		os.Exit(1)
	}
	for _, marker := range []string{"Hello from Shannon E2EE test", "Encrypted reply received", "M4 offline test", "M4 sender offline test", "M4 outage history test", "UX ribbon acceptance", "UX reply anchor", "UX edited reply", "UX offline ribbon", `"kind":"reaction"`, `"kind":"delete"`, `"event_ack"`} {
		var hits int
		if db.QueryRow(ctx, "SELECT count(*) FROM messaging_queue WHERE position($1::bytea in ciphertext)>0", []byte(marker)).Scan(&hits) != nil {
			os.Exit(1)
		}
		plaintext += hits
	}
	var deviceQueued, deviceReceipts int
	const testDevices = `SELECT d.id FROM devices d JOIN contact_profiles p ON p.identity_id=d.identity_id WHERE p.username IN ('m4_sam_a','m4_emu_b')`
	if db.QueryRow(ctx, "SELECT count(*) FROM messaging_queue WHERE sender_device IN ("+testDevices+")").Scan(&deviceQueued) != nil {
		os.Exit(1)
	}
	if db.QueryRow(ctx, "SELECT count(*) FROM messaging_receipts WHERE sender_device IN ("+testDevices+")").Scan(&deviceReceipts) != nil {
		os.Exit(1)
	}
	var accounts, roots, devices, curves, signing int
	if db.QueryRow(ctx, `SELECT count(DISTINCT i.id),count(DISTINCT i.root_key),count(DISTINCT m.device_id),count(DISTINCT m.curve_key),count(DISTINCT m.signing_key) FROM messaging_devices m JOIN identities i ON i.id=m.identity_id JOIN contact_profiles p ON p.identity_id=i.id WHERE p.username IN ('m4_sam_a','m4_emu_b')`).Scan(&accounts, &roots, &devices, &curves, &signing) != nil {
		os.Exit(1)
	}
	var minPrekeys, maxPrekeys int
	if db.QueryRow(ctx, `SELECT COALESCE(min(n),0),COALESCE(max(n),0) FROM (SELECT count(k.*) FILTER(WHERE k.claimed_at IS NULL) AS n FROM messaging_devices m JOIN contact_profiles p ON p.identity_id=m.identity_id LEFT JOIN messaging_prekeys k ON k.device_id=m.device_id WHERE p.username IN ('m4_sam_a','m4_emu_b') GROUP BY m.device_id) inventory`).Scan(&minPrekeys, &maxPrekeys) != nil {
		os.Exit(1)
	}
	_ = json.NewEncoder(os.Stdout).Encode(map[string]int{"pending_ciphertext_rows": queued, "submission_receipts": receipts, "plaintext_test_marker_hits": plaintext, "two_device_pending": deviceQueued, "two_device_receipts": deviceReceipts, "two_device_accounts": accounts, "two_device_distinct_roots": roots, "two_device_distinct_devices": devices, "two_device_distinct_curves": curves, "two_device_distinct_signing_keys": signing, "two_device_min_prekeys": minPrekeys, "two_device_max_prekeys": maxPrekeys})
	if plaintext != 0 {
		os.Exit(1)
	}
}
