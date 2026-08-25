use std::fmt;

use flutter_rust_bridge::frb;

use crate::frb_generated::StreamSink;

const BRIDGE_PROTOCOL_VERSION: u32 = 1;

/// Request sent by a presentation process when validating bridge connectivity.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct BridgeHandshakeRequest {
    /// Non-empty presentation process label retained for diagnostics.
    pub client_name: String,
    /// Protocol version understood by the presentation process.
    pub protocol_version: u32,
}

/// Successful bridge negotiation returned to the presentation process.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct BridgeHandshake {
    /// Client label accepted by the Rust adapter.
    pub client_name: String,
    /// Protocol version accepted by both sides.
    pub protocol_version: u32,
    /// Rust package version used to build the loaded native library.
    pub bridge_version: String,
}

/// Stable categories for bridge-boundary failures.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum BridgeErrorCode {
    /// The presentation process did not provide an identity.
    InvalidClientName,
    /// The presentation and native bridge protocols do not match.
    UnsupportedProtocol,
    /// A Rust-to-Dart event could not be delivered.
    EventDeliveryFailed,
}

/// Structured failure crossing the generated FRB boundary.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct BridgeError {
    /// Stable category used by presentation control flow.
    pub code: BridgeErrorCode,
    /// Diagnostic cause retained for structured development logs.
    pub diagnostic: String,
}

impl fmt::Display for BridgeError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.diagnostic.fmt(formatter)
    }
}

impl std::error::Error for BridgeError {}

/// Kinds emitted by the deterministic bridge event stream.
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum BridgeEventKind {
    /// The stream accepted a protocol and will emit samples.
    Ready,
    /// One ordered bridge sample.
    Sample,
    /// The stream emitted every promised sample.
    Finished,
}

/// Deterministic event proving ordered Rust-to-Dart stream delivery.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct BridgeEvent {
    /// Discriminator controlling which payload field is meaningful.
    pub kind: BridgeEventKind,
    /// Negotiated version for `Ready`, otherwise zero.
    pub protocol_version: u32,
    /// Sample position for `Sample`, otherwise zero.
    pub sequence: u32,
    /// Caller seed plus sample position for `Sample`, otherwise zero.
    pub value: u64,
    /// Emitted sample total for `Finished`, otherwise zero.
    pub sample_count: u32,
}

/// Initializes FRB process utilities before any generated API call.
#[frb(init)]
pub fn initialize_bridge() {
    flutter_rust_bridge::setup_default_user_utils();
}

/// Validates the presentation process and returns the native bridge identity.
///
/// # Errors
///
/// Returns [`BridgeErrorCode::InvalidClientName`] for a blank client label or
/// [`BridgeErrorCode::UnsupportedProtocol`] when the protocol does not match.
pub fn negotiate_bridge(request: BridgeHandshakeRequest) -> Result<BridgeHandshake, BridgeError> {
    let BridgeHandshakeRequest {
        client_name,
        protocol_version,
    } = request;
    let client_name = client_name.trim();
    if client_name.is_empty() {
        return Err(BridgeError {
            code: BridgeErrorCode::InvalidClientName,
            diagnostic: "bridge client name must not be blank".to_owned(),
        });
    }
    if protocol_version != BRIDGE_PROTOCOL_VERSION {
        return Err(BridgeError {
            code: BridgeErrorCode::UnsupportedProtocol,
            diagnostic: format!(
                "unsupported bridge protocol {protocol_version}; expected {BRIDGE_PROTOCOL_VERSION}"
            ),
        });
    }

    Ok(BridgeHandshake {
        client_name: client_name.to_owned(),
        protocol_version: BRIDGE_PROTOCOL_VERSION,
        bridge_version: env!("CARGO_PKG_VERSION").to_owned(),
    })
}

/// Emits a finite ordered sequence and closes after the terminal event.
///
/// # Errors
///
/// Returns [`BridgeErrorCode::EventDeliveryFailed`] if Dart closes the stream
/// before Rust delivers the complete sequence.
pub fn bridge_event_stream(seed: u64, sink: StreamSink<BridgeEvent>) -> Result<(), BridgeError> {
    for event in bridge_events(seed) {
        sink.add(event).map_err(|error| BridgeError {
            code: BridgeErrorCode::EventDeliveryFailed,
            diagnostic: format!("could not deliver bridge event: {error}"),
        })?;
    }
    // Side Effect: dropping the producer closes Dart's finite stream after the terminal event.
    drop(sink);
    Ok(())
}

fn bridge_events(seed: u64) -> [BridgeEvent; 4] {
    [
        BridgeEvent {
            kind: BridgeEventKind::Ready,
            protocol_version: BRIDGE_PROTOCOL_VERSION,
            sequence: 0,
            value: 0,
            sample_count: 0,
        },
        BridgeEvent {
            kind: BridgeEventKind::Sample,
            protocol_version: 0,
            sequence: 0,
            value: seed,
            sample_count: 0,
        },
        BridgeEvent {
            kind: BridgeEventKind::Sample,
            protocol_version: 0,
            sequence: 1,
            value: seed.saturating_add(1),
            sample_count: 0,
        },
        BridgeEvent {
            kind: BridgeEventKind::Finished,
            protocol_version: 0,
            sequence: 0,
            value: 0,
            sample_count: 2,
        },
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn handshake_normalizes_identity_and_rejects_protocol_drift() {
        let accepted = negotiate_bridge(BridgeHandshakeRequest {
            client_name: "  MediaForge Flutter  ".to_owned(),
            protocol_version: BRIDGE_PROTOCOL_VERSION,
        })
        .expect("the current protocol and non-empty name are valid");
        assert_eq!(accepted.client_name, "MediaForge Flutter");
        assert_eq!(accepted.protocol_version, BRIDGE_PROTOCOL_VERSION);
        assert_eq!(accepted.bridge_version, env!("CARGO_PKG_VERSION"));

        let blank_name = negotiate_bridge(BridgeHandshakeRequest {
            client_name: "   ".to_owned(),
            protocol_version: BRIDGE_PROTOCOL_VERSION,
        })
        .expect_err("a blank client identity must remain structured");
        assert_eq!(blank_name.code, BridgeErrorCode::InvalidClientName);

        let error = negotiate_bridge(BridgeHandshakeRequest {
            client_name: "MediaForge Flutter".to_owned(),
            protocol_version: BRIDGE_PROTOCOL_VERSION + 1,
        })
        .expect_err("protocol drift must remain structured");
        assert_eq!(error.code, BridgeErrorCode::UnsupportedProtocol);
        assert!(error.diagnostic.contains("expected 1"));
    }

    #[test]
    fn event_sequence_is_ordered_and_terminal() {
        assert_eq!(
            bridge_events(u64::MAX),
            [
                BridgeEvent {
                    kind: BridgeEventKind::Ready,
                    protocol_version: BRIDGE_PROTOCOL_VERSION,
                    sequence: 0,
                    value: 0,
                    sample_count: 0,
                },
                BridgeEvent {
                    kind: BridgeEventKind::Sample,
                    protocol_version: 0,
                    sequence: 0,
                    value: u64::MAX,
                    sample_count: 0,
                },
                BridgeEvent {
                    kind: BridgeEventKind::Sample,
                    protocol_version: 0,
                    sequence: 1,
                    value: u64::MAX,
                    sample_count: 0,
                },
                BridgeEvent {
                    kind: BridgeEventKind::Finished,
                    protocol_version: 0,
                    sequence: 0,
                    value: 0,
                    sample_count: 2,
                },
            ]
        );
    }
}
