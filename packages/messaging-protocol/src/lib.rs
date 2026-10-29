//! Controlled upstream-library evaluation. Not connected to the normal app.
//! No proprietary ratchet or plaintext fallback is implemented here.

pub const EVALUATION_SUITE: &str = "olm.v1";
pub mod adapter;

#[unsafe(no_mangle)]
pub extern "system" fn Java_dev_shannon_shannon_MessagingNative_invoke(
    mut env: jni::JNIEnv,
    _class: jni::objects::JClass,
    input: jni::objects::JString,
) -> jni::sys::jstring {
    static HOOK: std::sync::Once = std::sync::Once::new();
    HOOK.call_once(|| std::panic::set_hook(Box::new(|_| {})));
    let output = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        let text: String = env.get_string(&input).map_err(|_| ())?.into();
        Ok::<String, ()>(adapter::invoke(&text))
    })).ok().and_then(Result::ok).unwrap_or_else(|| "{\"error\":\"protocol_failure\"}".into());
    env.new_string(output).map(|s| s.into_raw()).unwrap_or(std::ptr::null_mut())
}

#[cfg(test)]
mod tests {
    use vodozemac::{Curve25519PublicKey, olm::{Account, AccountPickle, OlmMessage, Session, SessionConfig, SessionPickle}};

    #[test]
    fn low_order_keys_and_wrong_pickle_key_fail_closed() {
        let account = Account::new();
        let zero = Curve25519PublicKey::from_bytes([0; 32]);
        assert!(account.create_outbound_session(SessionConfig::version_1(), zero, zero).is_err());
        let encrypted = account.pickle().encrypt(&[7; 32]);
        assert!(AccountPickle::from_encrypted(&encrypted, &[8; 32]).is_err());
        let restored = Account::from_pickle(AccountPickle::from_encrypted(&encrypted, &[7; 32]).expect("authenticated pickle"));
        assert_eq!(restored.identity_keys(), account.identity_keys());
    }

    #[test]
    fn restored_ratchets_reject_tampering_without_losing_honest_packet() {
        let alice = Account::new();
        let mut bob = Account::new();
        bob.generate_one_time_keys(1);
        let prekey = *bob.one_time_keys().values().next().expect("prekey");
        let mut sending = alice.create_outbound_session(SessionConfig::version_1(), bob.curve25519_key(), prekey).expect("session");
        let OlmMessage::PreKey(first) = sending.encrypt("first").expect("encrypt") else { panic!("prekey") };
        let mut receiving = bob.create_inbound_session(SessionConfig::version_1(), alice.curve25519_key(), &first).expect("inbound").session;
        let reply = receiving.encrypt("reply").expect("reply");
        sending.decrypt(&reply).expect("established");
        let saved = serde_json::to_string(&receiving.pickle()).expect("serialize");
        let packet = sending.encrypt("after restart").expect("encrypt");
        let (kind,mut bytes) = packet.to_parts();
        let last = bytes.len()-1; bytes[last] ^= 1;
        let tampered = OlmMessage::from_parts(kind, &bytes).expect("structurally valid corruption");
        let mut reloaded = Session::from_pickle(serde_json::from_str::<SessionPickle>(&saved).expect("restore"));
        assert!(reloaded.decrypt(&tampered).is_err());
        assert_eq!(reloaded.decrypt(&packet).expect("honest packet after tampering"), b"after restart");
    }

    #[test]
    fn independent_accounts_exchange_and_reject_replay() {
        let initiator = Account::new();
        let mut recipient = Account::new();
        assert_ne!(initiator.identity_keys(), recipient.identity_keys());
        recipient.generate_one_time_keys(1);
        let prekey = *recipient.one_time_keys().values().next().expect("public prekey");
        let mut outgoing = initiator.create_outbound_session(
            SessionConfig::version_1(), recipient.curve25519_key(), prekey,
        ).expect("upstream session establishment");
        recipient.mark_keys_as_published();
        let packet = outgoing.encrypt(b"controlled test only").expect("encrypt");
        let OlmMessage::PreKey(first) = packet else { panic!("initial packet must be prekey") };
        let inbound = recipient.create_inbound_session(
            SessionConfig::version_1(), initiator.curve25519_key(), &first,
        ).expect("authenticated inbound");
        assert_eq!(inbound.plaintext, b"controlled test only");
        let mut incoming = inbound.session;
        let reply = incoming.encrypt("Հայերեն · Русский · reply").expect("reply");
        assert_eq!(outgoing.decrypt(&reply).expect("decrypt reply"), "Հայերեն · Русский · reply".as_bytes());
        assert!(outgoing.decrypt(&reply).is_err(), "replay must fail");
        let later = outgoing.encrypt(b"later").expect("encrypt later");
        let earliest = outgoing.encrypt(b"earliest delivered second").expect("encrypt reordered");
        assert_eq!(incoming.decrypt(&earliest).expect("out of order"), b"earliest delivered second");
        assert_eq!(incoming.decrypt(&later).expect("skipped key"), b"later");
    }
}
