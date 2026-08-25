//! Flutter bridge adapter for `MediaForge` application values.

/// Plain values and functions exposed through flutter_rust_bridge.
pub mod api;

// Constraint: generated FFI glue contains tool-owned unsafe blocks and fixed lint style.
#[allow(unsafe_code, clippy::pedantic)]
mod frb_generated;
