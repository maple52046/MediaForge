//! Stable values used to validate the Flutter-to-Rust bridge boundary.

/// Protocol handshake and deterministic stream used by the M4 bridge proof.
pub mod handshake;
/// Backend initialization and media metadata exposed to Flutter.
pub mod media;

pub use handshake::{
    bridge_event_stream, initialize_bridge, negotiate_bridge, BridgeError, BridgeErrorCode,
    BridgeEvent, BridgeEventKind, BridgeHandshake, BridgeHandshakeRequest,
};
pub use media::{
    default_output_path, initialize_backend, job_events, probe_media, start_transcode,
    AudioStreamInfoDto, BackendCapabilitiesDto, JobEventDto, JobEventKindDto, JobSnapshotDto,
    JobStateDto, MediaAudioQuality, MediaBridgeError, MediaBridgeErrorCode, MediaInfoDto,
    MediaOutputMode, StartTranscodeRequestDto, VideoStreamInfoDto,
};
