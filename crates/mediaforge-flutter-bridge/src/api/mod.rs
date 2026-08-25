//! Stable values used to validate the Flutter-to-Rust bridge boundary.

/// Protocol handshake and deterministic stream used by the M4 bridge proof.
pub mod handshake;

pub use handshake::{
    bridge_event_stream, initialize_bridge, negotiate_bridge, BridgeError, BridgeErrorCode,
    BridgeEvent, BridgeEventKind, BridgeHandshake, BridgeHandshakeRequest,
};
