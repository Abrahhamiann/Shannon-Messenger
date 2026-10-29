package identity

import (
	"context"
	"net/http"
)

// Read identity authorization without consuming a one-time prekey. This is
// required to authenticate inbound peers and compare pins for existing sessions.
func (a *API) readBundle(w http.ResponseWriter, r *http.Request, s session) {
	target := r.URL.Query().Get("account")
	if len(target) != 48 {
		fail(w, 400, "invalid recipient")
		return
	}
	tx, err := a.db.Begin(r.Context())
	if err != nil {
		unavailable(w)
		return
	}
	defer tx.Rollback(context.Background())
	if err = messagingPolicy(r, tx, s.Identity, target); err != nil {
		fail(w, 403, "contact messaging unavailable")
		return
	}
	var b publicBundle
	var curve, signing, rp, dp, root, device []byte
	err = tx.QueryRow(r.Context(), `SELECT m.device_id,m.suite,m.epoch,m.curve_key,m.signing_key,m.account_proof,m.device_proof,i.root_key,d.public_key FROM messaging_devices m JOIN devices d ON d.id=m.device_id JOIN identities i ON i.id=m.identity_id WHERE m.identity_id=$1 AND d.revoked_at IS NULL`, target).Scan(&b.Device, &b.Suite, &b.Epoch, &curve, &signing, &rp, &dp, &root, &device)
	if err != nil {
		fail(w, 404, "recipient messaging not configured")
		return
	}
	b.Account = target
	b.Curve = encoding.EncodeToString(curve)
	b.Signing = encoding.EncodeToString(signing)
	b.AccountProof = encoding.EncodeToString(rp)
	b.DeviceProof = encoding.EncodeToString(dp)
	b.RootKey = encoding.EncodeToString(root)
	b.DeviceKey = encoding.EncodeToString(device)
	b.Prekeys = []publicPrekey{}
	if tx.Commit(r.Context()) != nil {
		unavailable(w)
		return
	}
	reply(w, 200, b)
}
