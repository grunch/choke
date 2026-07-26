//! Nostr cryptography, backed by the `nostr` crate.
//!
//! This is the whole Rust surface the app is allowed to see: a handful of
//! functions, not a re-export of the SDK. Keeping it thin is deliberate —
//! it bounds the binary, and an upstream API change lands in one file
//! instead of across the Dart codebase.
//!
//! Events cross the bridge as structs, not as JSON. The event id is a hash of
//! the event's canonical serialization, so letting each side serialize its own
//! JSON would put a second, silent canonicalization in the path — exactly the
//! divergence the differential tests exist to catch. Instead the fields travel,
//! and the `nostr` crate performs the only serialization that matters.

use std::str::FromStr;

use nostr::prelude::*;

/// An event assembled but not yet signed: no id and no signature, because
/// both are derived from these fields.
pub struct UnsignedEventData {
    pub pubkey: String,
    pub created_at: i64,
    pub kind: u16,
    pub tags: Vec<Vec<String>>,
    pub content: String,
}

/// A signed event, exactly as it goes to a relay.
pub struct SignedEventData {
    pub id: String,
    pub pubkey: String,
    pub created_at: i64,
    pub kind: u16,
    pub tags: Vec<Vec<String>>,
    pub content: String,
    pub sig: String,
}

/// A fresh secp256k1 private key, as lowercase hex.
#[flutter_rust_bridge::frb(sync)]
pub fn generate_secret_key() -> String {
    Keys::generate().secret_key().to_secret_hex()
}

/// The public key belonging to `secret_hex`, as lowercase hex.
#[flutter_rust_bridge::frb(sync)]
pub fn public_key_from_secret(secret_hex: String) -> Result<String, String> {
    let keys = Keys::parse(&secret_hex).map_err(|e| e.to_string())?;
    Ok(keys.public_key().to_hex())
}

/// NIP-19 bech32 encoding of a hex public key (`npub1…`).
#[flutter_rust_bridge::frb(sync)]
pub fn npub_encode(public_key_hex: String) -> Result<String, String> {
    let public_key = PublicKey::parse(&public_key_hex).map_err(|e| e.to_string())?;
    public_key.to_bech32().map_err(|e| e.to_string())
}

/// NIP-19 bech32 encoding of a hex private key (`nsec1…`).
#[flutter_rust_bridge::frb(sync)]
pub fn nsec_encode(secret_hex: String) -> Result<String, String> {
    let secret_key = SecretKey::parse(&secret_hex).map_err(|e| e.to_string())?;
    secret_key.to_bech32().map_err(|e| e.to_string())
}

/// The hex private key inside `nsec`, or `None` if it is not a valid nsec.
///
/// `None` rather than an error: a malformed nsec is something a user can type,
/// not a bug. An npub is rejected here too — it is bech32 of the same family,
/// and reading one as a private key would be a catastrophic confusion.
#[flutter_rust_bridge::frb(sync)]
pub fn nsec_decode(nsec: String) -> Option<String> {
    SecretKey::from_bech32(&nsec)
        .ok()
        .map(|secret_key| secret_key.to_secret_hex())
}

/// The hex public key inside `npub`, or `None` if it is not a valid npub.
///
/// `None` rather than an error, for the same reason as `nsec_decode`: an npub is
/// something a user pastes, and getting it wrong is not a bug.
///
/// Strictly bech32 — a bare hex key is *not* accepted here. Callers that take
/// either form decide which one they were handed before calling, because the two
/// cannot be told apart afterwards: any 64 hex characters parse as a public key,
/// including a private one.
#[flutter_rust_bridge::frb(sync)]
pub fn npub_decode(npub: String) -> Option<String> {
    PublicKey::from_bech32(&npub)
        .ok()
        .map(|public_key| public_key.to_hex())
}

/// Compute `event`'s id and sign it with `secret_hex`.
#[flutter_rust_bridge::frb(sync)]
pub fn finish_event(
    event: UnsignedEventData,
    secret_hex: String,
) -> Result<SignedEventData, String> {
    let keys = Keys::parse(&secret_hex).map_err(|e| e.to_string())?;
    let public_key = PublicKey::parse(&event.pubkey).map_err(|e| e.to_string())?;
    let tags = parse_tags(&event.tags)?;

    let created_at = u64::try_from(event.created_at)
        .map_err(|_| format!("created_at cannot be negative: {}", event.created_at))?;

    let unsigned = UnsignedEvent::new(
        public_key,
        Timestamp::from(created_at),
        Kind::from(event.kind),
        tags,
        event.content,
    );

    let signed = unsigned.sign_with_keys(&keys).map_err(|e| e.to_string())?;
    Ok(to_signed_data(&signed))
}

/// Whether `event`'s id hashes its own contents *and* its signature is the one
/// its pubkey would produce. Both must hold: an event whose content was
/// rewritten after signing still carries a valid signature over a now-wrong id.
#[flutter_rust_bridge::frb(sync)]
pub fn verify_event_data(event: SignedEventData) -> bool {
    match to_event(&event) {
        Ok(event) => event.verify().is_ok(),
        // Unparseable fields (a malformed pubkey, bad signature hex) mean this
        // is not a valid event — which is exactly what `false` says.
        Err(_) => false,
    }
}

/// Whether `event_json` is a well-formed Nostr event whose id and Schnorr
/// signature both check out.
///
/// Returns `Err` only when the input does not parse as an event; an event
/// that parses but fails verification is `Ok(false)`.
#[flutter_rust_bridge::frb(sync)]
pub fn verify_event(event_json: String) -> Result<bool, String> {
    let event = Event::from_json(&event_json).map_err(|e| e.to_string())?;
    Ok(event.verify().is_ok())
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

fn parse_tags(tags: &[Vec<String>]) -> Result<Vec<Tag>, String> {
    tags.iter()
        .map(|tag| Tag::parse(tag.clone()).map_err(|e| e.to_string()))
        .collect()
}

pub(crate) fn to_signed_data(event: &Event) -> SignedEventData {
    SignedEventData {
        id: event.id.to_hex(),
        pubkey: event.pubkey.to_hex(),
        created_at: event.created_at.as_secs() as i64,
        kind: event.kind.as_u16(),
        tags: event.tags.iter().map(|tag| tag.clone().to_vec()).collect(),
        content: event.content.clone(),
        sig: event.sig.to_string(),
    }
}

pub(crate) fn to_event(data: &SignedEventData) -> Result<Event, String> {
    let created_at =
        u64::try_from(data.created_at).map_err(|_| "negative created_at".to_string())?;

    Ok(Event::new(
        EventId::from_hex(&data.id).map_err(|e| e.to_string())?,
        PublicKey::parse(&data.pubkey).map_err(|e| e.to_string())?,
        Timestamp::from(created_at),
        Kind::from(data.kind),
        parse_tags(&data.tags)?,
        data.content.clone(),
        Signature::from_str(&data.sig).map_err(|e| e.to_string())?,
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn unsigned(pubkey: &str) -> UnsignedEventData {
        UnsignedEventData {
            pubkey: pubkey.to_string(),
            created_at: 1_700_000_000,
            kind: 31415,
            tags: vec![vec!["d".to_string(), "abcd".to_string()]],
            content: "choke".to_string(),
        }
    }

    /// A real signed event: the id and signature must both hold.
    fn signed_event() -> String {
        let keys = Keys::generate();
        EventBuilder::text_note("choke")
            .sign_with_keys(&keys)
            .expect("signing a note with generated keys cannot fail")
            .as_json()
    }

    #[test]
    fn accepts_a_correctly_signed_event() {
        assert_eq!(verify_event(signed_event()), Ok(true));
    }

    #[test]
    fn rejects_an_event_whose_content_was_tampered_with() {
        // Flip the content after signing: the id no longer matches its event.
        let tampered = signed_event().replace(r#""content":"choke""#, r#""content":"choked""#);
        assert_eq!(verify_event(tampered), Ok(false));
    }

    #[test]
    fn errors_on_input_that_is_not_an_event() {
        assert!(verify_event("{\"not\":\"an event\"}".to_string()).is_err());
    }

    #[test]
    fn signs_an_event_that_verifies() {
        let secret = generate_secret_key();
        let pubkey = public_key_from_secret(secret.clone()).unwrap();

        let event = finish_event(unsigned(&pubkey), secret).unwrap();

        assert!(verify_event_data(event));
    }

    #[test]
    fn signing_the_same_event_twice_gives_the_same_id() {
        // The id hashes the event, not the signing nonce.
        let secret = generate_secret_key();
        let pubkey = public_key_from_secret(secret.clone()).unwrap();

        let first = finish_event(unsigned(&pubkey), secret.clone()).unwrap();
        let second = finish_event(unsigned(&pubkey), secret).unwrap();

        assert_eq!(first.id, second.id);
    }

    #[test]
    fn rejects_an_event_whose_content_changed_after_signing() {
        let secret = generate_secret_key();
        let pubkey = public_key_from_secret(secret.clone()).unwrap();
        let mut event = finish_event(unsigned(&pubkey), secret).unwrap();

        event.content = "choked".to_string();

        assert!(!verify_event_data(event));
    }

    #[test]
    fn nsec_round_trips() {
        let secret = generate_secret_key();

        let nsec = nsec_encode(secret.clone()).unwrap();

        assert_eq!(nsec_decode(nsec), Some(secret));
    }

    #[test]
    fn nsec_decode_rejects_an_npub() {
        let secret = generate_secret_key();
        let pubkey = public_key_from_secret(secret).unwrap();
        let npub = npub_encode(pubkey).unwrap();

        assert_eq!(nsec_decode(npub), None);
    }

    #[test]
    fn nsec_decode_rejects_nonsense() {
        assert_eq!(nsec_decode("not an nsec".to_string()), None);
    }

    /// The vector published in NIP-19 itself.
    #[test]
    fn matches_the_nip19_test_vector() {
        const SECRET: &str = "67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa";
        const NSEC: &str = "nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5";

        assert_eq!(nsec_encode(SECRET.to_string()).unwrap(), NSEC);
        assert_eq!(nsec_decode(NSEC.to_string()), Some(SECRET.to_string()));
    }
}
