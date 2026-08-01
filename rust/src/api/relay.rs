//! The relay transport, backed by `nostr-sdk`'s relay pool.
//!
//! Thin on purpose, and shaped by the Dart interface above it
//! (`NostrRelayBackend`): connect, subscribe, publish to **one** relay and
//! report what *that relay* said. Reliability — the outbox, per-relay
//! convergence, the resend sweep — stays in Dart, where it was won (PRs #77,
//! #78). This module must never quietly acquire an opinion about any of it.
//!
//! The one thing worth understanding here is [`relay_publish`]: it asks a
//! single relay to take the event and reports whether **that** relay accepted.
//! `nostr-sdk`'s relay handle hands us that verdict structured — an `OK: false`
//! surfaces as its own error, distinct from a socket that simply never answered
//! — precisely what the hand-rolled transport had to grow OK-tracking to learn.
//! Flattening it back into a pool-wide "it worked" would resurrect the
//! stale-scoreboard bug.

use std::sync::OnceLock;

use nostr_sdk::prelude::*;
use tokio::sync::broadcast;

use crate::api::crypto::{to_event, to_signed_data, SignedEventData};
use crate::frb_generated::StreamSink;

/// One pool for the process. The app has exactly one identity and one set of
/// relays; handing Dart an opaque handle to pass back and forth would buy
/// nothing but ceremony.
static CLIENT: OnceLock<Client> = OnceLock::new();

fn client() -> &'static Client {
    CLIENT.get_or_init(Client::default)
}

/// Relay status changes, fanned into one channel.
///
/// `nostr-sdk` reports status per relay, not pool-wide, so each relay's
/// notifications are forwarded here as it is added.
///
/// Both directions are reported, not just connections. The caller keeps its own
/// view of who is up — it has to, because it decides where to publish — and a
/// stream that only ever said "connected" would leave that view drifting
/// permanently optimistic: it would keep publishing into a relay that left.
static STATUS: OnceLock<broadcast::Sender<RelayStatusData>> = OnceLock::new();

fn status_tx() -> &'static broadcast::Sender<RelayStatusData> {
    STATUS.get_or_init(|| broadcast::channel(64).0)
}

/// A relay went up, or went down.
#[derive(Clone)]
pub struct RelayStatusData {
    pub url: String,
    pub connected: bool,
}

/// Every URL the caller has asked for, whether or not the pool holds it.
///
/// The pool is not this list: a relay whose re-add failed mid-reconnect is
/// gone from the pool, and a reconnect that rebuilds "whatever the pool has"
/// would never try it again — the relay would be silently gone until the
/// process restarts. This registry is what was *asked for*; the pool is what
/// *succeeded*. Reconnect rebuilds from the former.
static CONFIGURED: OnceLock<std::sync::Mutex<std::collections::BTreeSet<String>>> = OnceLock::new();

fn configured() -> &'static std::sync::Mutex<std::collections::BTreeSet<String>> {
    CONFIGURED.get_or_init(|| std::sync::Mutex::new(std::collections::BTreeSet::new()))
}

/// Serializes add, remove and reconnect, whole operations at a time.
///
/// Locking only the registry accesses is not enough: reconnect snapshots the
/// registry and then spends seconds rebuilding relays, and a `relay_remove`
/// landing inside that window would be undone — the rebuild re-adds the URL
/// the user just deleted, from its stale snapshot. Whole-operation
/// serialization makes the interleaving impossible instead of unlikely.
///
/// Ordering: this lock is taken first, and the `configured()` mutex is only
/// ever taken while holding it (and never across an await), so there is no
/// path to a deadlock. The public wrappers lock; `*_locked` variants do not,
/// and exist for reconnect to compose.
static OPS: OnceLock<tokio::sync::Mutex<()>> = OnceLock::new();

fn ops() -> &'static tokio::sync::Mutex<()> {
    OPS.get_or_init(|| tokio::sync::Mutex::new(()))
}

/// Which incarnation of each URL's relay is the live one.
///
/// Rebuilding a relay replaces its watcher, but tasks do not die in order: the
/// OLD watcher can still be draining its backlog — a `Terminated` from the
/// relay that was just torn down — after the NEW relay has already reported
/// `Connected`. Forwarded, that late word would clear the caller's connected
/// view of a relay that is in fact healthy, and nothing would correct it until
/// the relay next changed state. So every watcher is stamped with the
/// generation it was born under, and a watcher whose generation has passed
/// says nothing and exits.
static GENERATION: OnceLock<std::sync::Mutex<std::collections::HashMap<String, u64>>> =
    OnceLock::new();

fn generation() -> &'static std::sync::Mutex<std::collections::HashMap<String, u64>> {
    GENERATION.get_or_init(|| std::sync::Mutex::new(std::collections::HashMap::new()))
}

/// Invalidate every watcher spawned for [url] so far; returns the new
/// generation, for the watcher about to be spawned.
fn bump_generation(url: &str) -> u64 {
    let mut map = generation().lock().unwrap();
    let next = map.get(url).copied().unwrap_or(0) + 1;
    map.insert(url.to_string(), next);
    next
}

fn current_generation(url: &str) -> u64 {
    generation().lock().unwrap().get(url).copied().unwrap_or(0)
}

/// A NIP-01 `REQ` filter. Empty vectors and `None` mean "unconstrained" — the
/// same shape the Dart `Filter` has, so the mapping stays honest.
pub struct FilterData {
    pub kinds: Vec<u16>,
    pub authors: Vec<String>,
    pub ids: Vec<String>,
    pub since: Option<i64>,
    pub until: Option<i64>,
    pub limit: Option<u32>,
}

/// Register a relay with the pool and dial it.
pub async fn relay_add(url: String) -> Result<(), String> {
    let _ops = ops().lock().await;
    relay_add_locked(url).await
}

/// The body of [relay_add], for callers already holding [ops].
async fn relay_add_locked(url: String) -> Result<(), String> {
    client().add_relay(&url).await.map_err(|e| e.to_string())?;

    // Watch this relay's status so the caller learns when it (re)connects.
    //
    // The task holds the RECEIVER only, never the `Relay` itself. Capturing the
    // relay would keep its notification channel's senders alive after the pool
    // drops it, so `Closed` would never arrive: every resume (which rebuilds
    // relays) would leak one more immortal watcher, each still forwarding a
    // dead relay's word under a live relay's URL.
    //
    // It is also stamped with its generation, and checks it before every send:
    // watchers do not die in order, and one draining the torn-down relay's
    // backlog must not speak — its `Terminated` arriving after the replacement
    // relay's `Connected` would clear the caller's view of a healthy relay.
    let generation = bump_generation(&url);
    let mut notifications = client()
        .relay(&url)
        .await
        .map_err(|e| e.to_string())?
        .notifications();
    let relay_url = url.clone();
    tokio::spawn(async move {
        loop {
            if current_generation(&relay_url) != generation {
                break; // superseded: a newer incarnation is being watched
            }
            match notifications.recv().await {
                Ok(RelayNotification::RelayStatus { status }) => {
                    if current_generation(&relay_url) != generation {
                        break;
                    }
                    // No receivers yet is not an error: Dart may not have
                    // opened the stream, and the relay's status is what it is
                    // regardless.
                    let _ = status_tx().send(RelayStatusData {
                        url: relay_url.clone(),
                        connected: status == RelayStatus::Connected,
                    });
                }
                Ok(_) => {}
                // Fell behind and skipped notifications. `while let Ok` here
                // used to KILL the watcher — and a dead watcher is a Dart-side
                // connection view frozen until the process restarts. Report
                // the current status (looked up fresh, so a removed relay ends
                // the watch instead of being resurrected), and keep watching.
                Err(broadcast::error::RecvError::Lagged(_)) => {
                    if current_generation(&relay_url) != generation {
                        break;
                    }
                    match client().relay(&relay_url).await {
                        Ok(current) => {
                            let _ = status_tx().send(RelayStatusData {
                                url: relay_url.clone(),
                                connected: current.status() == RelayStatus::Connected,
                            });
                        }
                        Err(_) => break,
                    }
                }
                // The relay was removed from the pool; the watch is over.
                Err(broadcast::error::RecvError::Closed) => break,
            }
        }
    });

    // Connect this relay alone, so adding one later does not disturb the rest.
    client()
        .connect_relay(&url)
        .await
        .map_err(|e| e.to_string())?;

    // Registered only on success: a URL that never made it into the pool is
    // the caller's error to hear about, not something to keep redialing.
    configured().lock().unwrap().insert(url);
    Ok(())
}

pub async fn relay_remove(url: String) -> Result<(), String> {
    let _ops = ops().lock().await;
    // Out of the registry first, so a reconnect can never resurrect a relay
    // the user just removed — and the generation bump silences its watcher
    // before the teardown notifications it is about to receive.
    configured().lock().unwrap().remove(&url);
    bump_generation(&url);
    client().remove_relay(&url).await.map_err(|e| e.to_string())
}

/// Connect every registered relay.
pub async fn relay_connect() {
    client().connect().await;
}

pub async fn relay_disconnect() {
    client().disconnect().await;
}

/// Drop every socket and dial again.
///
/// The pool reconnects on its own eventually, but "eventually" is measured in
/// TCP timeouts. When the app resumes we already know the sockets are suspect —
/// the OS kills them without a close frame — and the referee's next tap must
/// not wait for the kernel to work that out.
///
/// ## Why this rebuilds the relays instead of calling disconnect + connect
///
/// `nostr-sdk` 0.44's revival races its own teardown, and losing that race
/// **strands the relay permanently**. `disconnect()` stores a termination
/// permit (a tokio `Notify`) and returns with the status already `Terminated`;
/// `connect()` then flips it to `Pending` and spawns a task — which sees the
/// OLD task still registered and declines. The old task meanwhile wakes from
/// `connect_and_run`, reads `Pending` (not terminated, so it keeps going),
/// marks the relay `Disconnected`, and dies in its backoff sleep by consuming
/// the stored permit. End state: status `Disconnected`, **no task**, and
/// `connect()` is a no-op on `Disconnected` — nothing dials again until the
/// process restarts. That is the app's "no connection until I kill it" bug,
/// reproduced by the `resume never strands the transport` drill.
///
/// Nudging stragglers back to life with more disconnect/connect pairs just
/// re-enters the same race (the drill stayed red under a 20-round nudge loop).
/// The only sequence that cannot lose it is the one with no revival in it at
/// all: **remove the relay and add it back**. A removed relay's watcher ends
/// (its channel closes), and `relay_add` builds a fresh `Relay` — new `Notify`
/// with no stored permit, no zombie task, a new watcher — and dials. Pool
/// subscriptions survive by design: a newly added relay inherits them
/// (`nostr-relay-pool` inherits pool subscriptions on `add_relay`).
pub async fn relay_reconnect_all() {
    // Held for the WHOLE rebuild: a remove landing between the snapshot below
    // and the re-adds would otherwise be undone — the user deletes a relay,
    // and the resume resurrects it from a stale snapshot.
    let _ops = ops().lock().await;

    // Rebuild from what was ASKED FOR, not from what the pool currently holds:
    // a relay whose previous re-add failed is absent from the pool, and a pool
    // snapshot would silently abandon it forever.
    let urls: Vec<String> = configured().lock().unwrap().iter().cloned().collect();

    for url in &urls {
        // Silence the outgoing watcher before the teardown it is about to
        // observe; the registry keeps the URL — this removal is a rebuild,
        // not a goodbye.
        bump_generation(url);
        let _ = client().remove_relay(url).await;
    }
    for url in urls {
        // Re-registers the status watcher too. A failed add is retried here a
        // couple of times (resume often races the network coming back up), and
        // a URL that still fails stays in the registry — the next resume tries
        // again, instead of the relay being quietly gone until app restart.
        for attempt in 0..3u8 {
            match relay_add_locked(url.clone()).await {
                Ok(()) => break,
                // Still failing after the retries is not a dead end: the URL
                // is in the registry, so the next resume starts over with it.
                Err(_) if attempt == 2 => {}
                Err(_) => {
                    tokio::time::sleep(std::time::Duration::from_millis(250)).await;
                }
            }
        }
    }
}

/// Publish to **one** relay and report that relay's verdict.
///
/// `true` = this relay accepted it. `false` = it rejected it (rate limits, an
/// invalid event, policy). `Err` = we never heard from it at all.
///
/// Publishing one relay at a time, rather than fanning out inside the pool, is
/// deliberate: the caller's convergence bookkeeping is per relay, and a
/// pool-level "it worked" would flatten exactly the distinction that matters.
pub async fn relay_publish(url: String, event: SignedEventData) -> Result<bool, String> {
    let event = to_event(&event)?;

    // Send to this one relay and wait for its verdict. Going through the relay
    // directly, rather than the pool's `send_event_to`, is what keeps that
    // verdict *structured*: the pool flattens every per-relay failure into an
    // opaque string in `Output.failed`, so a dead socket and an explicit `OK
    // false` would arrive indistinguishable — and collapsing "never answered"
    // into "refused" is exactly the confusion the caller's convergence
    // bookkeeping cannot survive (#78). Resolving the relay also fails cleanly
    // when it was never added, which is the honest answer to that call.
    let relay = client().relay(&url).await.map_err(|e| e.to_string())?;

    match relay.send_event(&event).await {
        // The relay accepted it.
        Ok(_) => Ok(true),
        // The relay answered, and its answer was no: an `OK: false`. This — a
        // rate limit, an invalid event, a policy refusal — is the *only* thing
        // that reads as a rejection.
        Err(nostr_sdk::pool::relay::Error::RelayMessage(_)) => Ok(false),
        // Anything else — not connected, timed out — means we never heard a
        // verdict at all, and the caller must be told so rather than shown a
        // refusal the relay never gave.
        Err(e) => Err(e.to_string()),
    }
}

/// Whether `url` answers a relay's WebSocket handshake within `timeout_ms`.
///
/// Settings vets a URL with this before saving it. The question is "is
/// something listening there", nothing more — success is the handshake
/// completing, not any Nostr traffic — which mirrors what the app accepted
/// before this probe existed.
///
/// Runs on a throwaway client, never the app's pool: the candidate joins no
/// registry, inherits none of the pool's subscriptions, and a URL the user
/// then decides not to save leaves nothing behind. `shutdown` reaps the
/// throwaway's tasks whichever way the probe went.
pub async fn relay_probe(url: String, timeout_ms: u32) -> bool {
    let probe = Client::default();

    // A URL that cannot be parsed is unreachable by definition. The caller
    // hears `false` rather than an error, because "can this be my relay?"
    // has exactly two answers.
    //
    // Written as one expression so `shutdown` below is on every path,
    // including this one. Dropping the client would very likely be enough —
    // nothing is connected when `add_relay` fails — but "very likely enough"
    // is a worse thing to leave behind than one branch.
    let connected = if probe.add_relay(&url).await.is_err() {
        false
    } else {
        probe
            .try_connect_relay(
                &url,
                std::time::Duration::from_millis(u64::from(timeout_ms)),
            )
            .await
            .is_ok()
    };

    probe.shutdown().await;
    connected
}

pub async fn relay_subscribe(subscription_id: String, filter: FilterData) -> Result<(), String> {
    let mut f = Filter::new();

    if !filter.kinds.is_empty() {
        f = f.kinds(filter.kinds.into_iter().map(Kind::from));
    }
    if !filter.authors.is_empty() {
        let authors: Result<Vec<PublicKey>, String> = filter
            .authors
            .iter()
            .map(|a| PublicKey::parse(a).map_err(|e| e.to_string()))
            .collect();
        f = f.authors(authors?);
    }
    if !filter.ids.is_empty() {
        let ids: Result<Vec<EventId>, String> = filter
            .ids
            .iter()
            .map(|i| EventId::from_hex(i).map_err(|e| e.to_string()))
            .collect();
        f = f.ids(ids?);
    }
    if let Some(since) = filter.since {
        f = f.since(Timestamp::from(since.max(0) as u64));
    }
    if let Some(until) = filter.until {
        f = f.until(Timestamp::from(until.max(0) as u64));
    }
    if let Some(limit) = filter.limit {
        f = f.limit(limit as usize);
    }

    client()
        .subscribe_with_id(SubscriptionId::new(subscription_id), f, None)
        .await
        .map_err(|e| e.to_string())?;
    Ok(())
}

pub async fn relay_unsubscribe(subscription_id: String) {
    client()
        .unsubscribe(&SubscriptionId::new(subscription_id))
        .await;
}

/// Every registered relay, connected or not. Convergence is measured against
/// this list, so it must not quietly drop the relays that are currently down.
pub async fn relay_urls() -> Vec<String> {
    client()
        .relays()
        .await
        .keys()
        .map(|url| url.to_string())
        .collect()
}

/// The subset currently connected.
pub async fn relay_connected() -> Vec<String> {
    client()
        .relays()
        .await
        .iter()
        .filter(|(_, relay)| relay.status() == RelayStatus::Connected)
        .map(|(url, _)| url.to_string())
        .collect()
}

/// Every event arriving from any relay.
///
/// Deliberately built on the pool's raw `Message` notifications rather than its
/// de-duplicated `Event` ones: those drop events this client sent itself, and
/// events it has seen before. The app needs the relay's echo of its own matches
/// — that echo is how a second device learns the score. Filtering (NIP-40
/// expiry, addressable replacement) is the caller's job either way.
pub async fn relay_event_stream(sink: StreamSink<SignedEventData>) {
    let mut notifications = client().notifications();

    loop {
        match notifications.recv().await {
            Ok(RelayPoolNotification::Message {
                message: RelayMessage::Event { event, .. },
                ..
            }) => {
                if sink.add(to_signed_data(&event)).is_err() {
                    // Dart dropped the stream; nobody is listening any more.
                    break;
                }
            }
            Ok(_) => {}
            // Fell behind: some events were skipped and a broadcast channel
            // cannot replay them. The relays can, though — re-issuing every
            // live REQ makes them resend what they hold, and for addressable
            // events the latest state is the only state that matters. What
            // must not happen is the old behavior: the stream dying here.
            //
            // Taking one filter per subscription is exact, not lossy: every
            // subscription in this pool is single-filter by construction —
            // [relay_subscribe] is the only writer, and `subscribe_with_id`
            // takes exactly one `Filter` — and pool-level subscriptions carry
            // that same filter to every relay. (Re-issuing per filter with the
            // same id would be wrong anyway: a repeated REQ id REPLACES, so
            // only the last filter would survive.)
            Err(broadcast::error::RecvError::Lagged(_)) => {
                for (id, per_relay) in client().subscriptions().await {
                    if let Some(filter) = per_relay.into_values().flatten().next() {
                        let _ = client().subscribe_with_id(id, filter, None).await;
                    }
                }
            }
            Err(broadcast::error::RecvError::Closed) => break,
        }
    }
}

/// Fires whenever a relay goes up or down.
///
/// A connection is the caller's cue to push state that relay missed while it
/// was away; a disconnection is its cue to stop counting on it.
pub async fn relay_status_stream(sink: StreamSink<RelayStatusData>) {
    let mut status = status_tx().subscribe();

    loop {
        match status.recv().await {
            Ok(change) => {
                if sink.add(change).is_err() {
                    break;
                }
            }
            // Missed some transitions — and this channel's lag is independent
            // of the per-relay watchers' lag, so nobody else re-reports them.
            // Skipping here would leave Dart's connection view wrong until a
            // relay happens to change state again; instead, send the current
            // status of every registered relay straight into the sink. It is
            // the same truth the missed notifications were carrying, minus the
            // history nobody needs.
            Err(broadcast::error::RecvError::Lagged(_)) => {
                for (url, relay) in client().relays().await {
                    let snapshot = RelayStatusData {
                        url: url.to_string(),
                        connected: relay.status() == RelayStatus::Connected,
                    };
                    if sink.add(snapshot).is_err() {
                        return;
                    }
                }
            }
            Err(broadcast::error::RecvError::Closed) => break,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // The probe's failure paths are testable without any relay: garbage, a
    // refused port, and a socket that accepts and then says nothing. The
    // success path needs a live WebSocket server, which the Dart side already
    // owns — `rust_relay_probe_test.dart` runs it against this same binary.

    #[tokio::test]
    async fn probe_rejects_a_url_that_does_not_parse() {
        assert!(!relay_probe("not a relay url".to_string(), 1_000).await);
    }

    #[tokio::test]
    async fn probe_reports_a_refused_connection_as_unreachable() {
        // A port this test held and let go, rather than a low one assumed to
        // be free: the kernel hands out one nothing is listening on, and
        // dropping the listener leaves it refusing. A hardcoded port is only
        // unused until the machine running the tests disagrees.
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        let port = listener.local_addr().unwrap().port();
        drop(listener);

        assert!(!relay_probe(format!("ws://127.0.0.1:{port}"), 2_000).await);
    }

    #[tokio::test]
    async fn probe_times_out_on_a_socket_that_never_completes_the_handshake() {
        // A TCP listener that is never accepted from: the kernel completes
        // the TCP handshake out of the backlog, and then nothing ever
        // answers the WebSocket upgrade — the timeout is the only way out.
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        let port = listener.local_addr().unwrap().port();

        // The outer deadline is the point: if the probe's own timeout ever
        // stops firing, this fails in three seconds instead of hanging the
        // suite until CI gives up on the whole job.
        let result = tokio::time::timeout(
            std::time::Duration::from_secs(3),
            relay_probe(format!("ws://127.0.0.1:{port}"), 1_500),
        )
        .await
        .expect("relay probe exceeded the outer test deadline");

        assert!(!result);
    }
}
