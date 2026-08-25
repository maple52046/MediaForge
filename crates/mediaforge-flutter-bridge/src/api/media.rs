use std::fmt;
use std::path::PathBuf;
use std::sync::{Arc, OnceLock};

use mediaforge_application::{ApplicationError, ErrorCode, MediaFacade};
use mediaforge_core::{
    propose_output_path, AudioStreamInfo, BackendCapabilities, MediaError, MediaInfo, OutputMode,
    VideoStreamInfo,
};
use mediaforge_ffmpeg::FfmpegBackend;

static MEDIA_FACADE: OnceLock<Result<MediaFacade, ApplicationError>> = OnceLock::new();

/// Codec capabilities reported by the configured native backend.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct BackendCapabilitiesDto {
    /// Human-readable `FFmpeg` library version.
    pub ffmpeg_version: String,
    /// Whether H.264 output is available on the active platform adapter.
    pub h264_available: bool,
    /// Whether native AAC output is available.
    pub aac_available: bool,
    /// Whether libmp3lame output is available.
    pub mp3_available: bool,
}

/// Primary video metadata safe to expose through FRB.
#[derive(Clone, Debug, PartialEq)]
pub struct VideoStreamInfoDto {
    /// Codec display name reported by `FFmpeg`.
    pub codec: String,
    /// Display width in pixels.
    pub width: u32,
    /// Display height in pixels.
    pub height: u32,
    /// Frames per second when the source reports a valid rate.
    pub frame_rate: Option<f64>,
    /// Average stream bitrate when known.
    pub bitrate: Option<u64>,
    /// Pixel format when known.
    pub pixel_format: Option<String>,
}

/// Primary audio metadata safe to expose through FRB.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct AudioStreamInfoDto {
    /// Codec display name reported by `FFmpeg`.
    pub codec: String,
    /// Sample rate in hertz when known.
    pub sample_rate: Option<u32>,
    /// Channel count when known.
    pub channels: Option<u16>,
    /// Average stream bitrate when known.
    pub bitrate: Option<u64>,
}

/// Output recipes whose availability is determined by Rust metadata.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum MediaOutputMode {
    /// H.264 video and AAC audio in MP4.
    VideoWithAudio,
    /// H.264 video without audio in MP4.
    VideoOnly,
    /// MP3 audio without video.
    AudioOnly,
}

/// Canonical metadata for one successfully probed local source.
#[derive(Clone, Debug, PartialEq)]
pub struct MediaInfoDto {
    /// Losslessly represented canonical local path.
    pub path: String,
    /// Last path component for display.
    pub file_name: String,
    /// File size in bytes.
    pub file_size_bytes: u64,
    /// Container duration in integer milliseconds.
    pub duration_ms: u64,
    /// Container format reported by `FFmpeg`.
    pub format: String,
    /// Selected primary video stream when present.
    pub video: Option<VideoStreamInfoDto>,
    /// Selected primary audio stream when present.
    pub audio: Option<AudioStreamInfoDto>,
    /// Output recipes supported by the selected primary streams.
    pub available_output_modes: Vec<MediaOutputMode>,
}

/// Stable application failures exposed to the Flutter boundary.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum MediaBridgeErrorCode {
    /// The source lacks a supported primary stream.
    UnsupportedInput,
    /// The source path or container could not be opened.
    CannotOpenInput,
    /// A selected stream could not be decoded for metadata.
    DecodeFailed,
    /// A required encoder is unavailable.
    EncoderUnavailable,
    /// A trim range violates source bounds.
    InvalidTrimRange,
    /// The destination exists without overwrite approval.
    OutputExists,
    /// A protected temporary output could not be created.
    OutputCreateFailed,
    /// Output data could not be written or committed.
    DiskWriteFailed,
    /// Another conversion owns the exclusive job slot.
    JobActive,
    /// No matching active job exists.
    JobNotFound,
    /// Cooperative cancellation ended the operation.
    Cancelled,
    /// The failure does not fit a stable application category.
    Unexpected,
}

/// Structured media failure crossing the generated FRB boundary.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct MediaBridgeError {
    /// Stable category used for presentation control flow and localization.
    pub code: MediaBridgeErrorCode,
    /// Diagnostic cause retained for structured development logs.
    pub diagnostic: String,
}

impl fmt::Display for MediaBridgeError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.diagnostic.fmt(formatter)
    }
}

impl std::error::Error for MediaBridgeError {}

/// Initializes the process-wide `FFmpeg` adapter and reports its capabilities.
///
/// # Errors
///
/// Returns a structured failure when the repository-built `FFmpeg` libraries
/// cannot initialize.
pub fn initialize_backend() -> Result<BackendCapabilitiesDto, MediaBridgeError> {
    Ok(media_facade()?.capabilities().into())
}

/// Canonicalizes and probes one regular local media file on FRB's Rust executor.
///
/// # Errors
///
/// Returns a structured application failure when the path cannot be
/// canonicalized, the input is unsupported, or `FFmpeg` cannot inspect it.
pub fn probe_media(path: String) -> Result<MediaInfoDto, MediaBridgeError> {
    let canonical_path = canonicalize_path(PathBuf::from(path))?;
    let media = media_facade()?.probe(&canonical_path)?;
    MediaInfoDto::try_from(media)
}

/// Proposes a destination beside a canonical source for one supported recipe.
///
/// # Errors
///
/// Returns a structured path failure when the source cannot be canonicalized or
/// the resulting destination cannot be represented losslessly for Dart.
pub fn default_output_path(
    path: String,
    mode: MediaOutputMode,
) -> Result<String, MediaBridgeError> {
    let canonical_path = canonicalize_path(PathBuf::from(path))?;
    path_to_string(propose_output_path(&canonical_path, mode.into()))
}

fn media_facade() -> Result<&'static MediaFacade, MediaBridgeError> {
    MEDIA_FACADE
        .get_or_init(|| {
            FfmpegBackend::new()
                .map(|backend| MediaFacade::new(Arc::new(backend)))
                .map_err(ApplicationError::from)
        })
        .as_ref()
        .map_err(|error| MediaBridgeError::from(error.clone()))
}

fn canonicalize_path(path: PathBuf) -> Result<PathBuf, MediaBridgeError> {
    if path.as_os_str().is_empty() {
        return Err(MediaBridgeError::from(ApplicationError::from(
            MediaError::CannotOpenInput("media path must not be empty".to_owned()),
        )));
    }
    std::fs::canonicalize(path).map_err(|error| {
        MediaBridgeError::from(ApplicationError::from(MediaError::CannotOpenInput(
            error.to_string(),
        )))
    })
}

fn path_to_string(path: PathBuf) -> Result<String, MediaBridgeError> {
    path.into_os_string().into_string().map_err(|_| {
        MediaBridgeError::from(ApplicationError::from(MediaError::CannotOpenInput(
            "canonical media path is not valid UTF-8".to_owned(),
        )))
    })
}

impl From<BackendCapabilities> for BackendCapabilitiesDto {
    fn from(capabilities: BackendCapabilities) -> Self {
        Self {
            ffmpeg_version: capabilities.ffmpeg_version,
            h264_available: capabilities.h264_available,
            aac_available: capabilities.aac,
            mp3_available: capabilities.libmp3lame,
        }
    }
}

impl From<VideoStreamInfo> for VideoStreamInfoDto {
    fn from(video: VideoStreamInfo) -> Self {
        Self {
            codec: video.codec,
            width: video.width,
            height: video.height,
            frame_rate: video.frame_rate,
            bitrate: video.bitrate,
            pixel_format: video.pixel_format,
        }
    }
}

impl From<AudioStreamInfo> for AudioStreamInfoDto {
    fn from(audio: AudioStreamInfo) -> Self {
        Self {
            codec: audio.codec,
            sample_rate: audio.sample_rate,
            channels: audio.channels,
            bitrate: audio.bitrate,
        }
    }
}

impl TryFrom<MediaInfo> for MediaInfoDto {
    type Error = MediaBridgeError;

    fn try_from(media: MediaInfo) -> Result<Self, Self::Error> {
        let available_output_modes = media
            .available_output_modes()
            .into_iter()
            .map(MediaOutputMode::from)
            .collect();
        Ok(Self {
            path: path_to_string(media.path)?,
            file_name: media.file_name,
            file_size_bytes: media.file_size_bytes,
            duration_ms: media.duration_ms,
            format: media.format,
            video: media.video.map(VideoStreamInfoDto::from),
            audio: media.audio.map(AudioStreamInfoDto::from),
            available_output_modes,
        })
    }
}

impl From<OutputMode> for MediaOutputMode {
    fn from(mode: OutputMode) -> Self {
        match mode {
            OutputMode::VideoWithAudio => Self::VideoWithAudio,
            OutputMode::VideoOnly => Self::VideoOnly,
            OutputMode::AudioOnly => Self::AudioOnly,
        }
    }
}

impl From<MediaOutputMode> for OutputMode {
    fn from(mode: MediaOutputMode) -> Self {
        match mode {
            MediaOutputMode::VideoWithAudio => Self::VideoWithAudio,
            MediaOutputMode::VideoOnly => Self::VideoOnly,
            MediaOutputMode::AudioOnly => Self::AudioOnly,
        }
    }
}

impl From<ApplicationError> for MediaBridgeError {
    fn from(error: ApplicationError) -> Self {
        Self {
            code: error.code.into(),
            diagnostic: error.message,
        }
    }
}

impl From<ErrorCode> for MediaBridgeErrorCode {
    fn from(code: ErrorCode) -> Self {
        match code {
            ErrorCode::UnsupportedInput => Self::UnsupportedInput,
            ErrorCode::CannotOpenInput => Self::CannotOpenInput,
            ErrorCode::DecodeFailed => Self::DecodeFailed,
            ErrorCode::EncoderUnavailable => Self::EncoderUnavailable,
            ErrorCode::InvalidTrimRange => Self::InvalidTrimRange,
            ErrorCode::OutputExists => Self::OutputExists,
            ErrorCode::OutputCreateFailed => Self::OutputCreateFailed,
            ErrorCode::DiskWriteFailed => Self::DiskWriteFailed,
            ErrorCode::JobActive => Self::JobActive,
            ErrorCode::JobNotFound => Self::JobNotFound,
            ErrorCode::Cancelled => Self::Cancelled,
            ErrorCode::Unexpected => Self::Unexpected,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn media_mapping_preserves_streams_modes_and_large_values() {
        let media = MediaInfo {
            path: PathBuf::from("/tmp/input.mov"),
            file_name: "input.mov".to_owned(),
            file_size_bytes: u64::MAX,
            duration_ms: 3_856,
            format: "mov".to_owned(),
            video: Some(VideoStreamInfo {
                codec: "hevc".to_owned(),
                width: 1_920,
                height: 1_080,
                frame_rate: Some(59.94),
                bitrate: Some(8_000_000),
                pixel_format: Some("yuv420p".to_owned()),
            }),
            audio: Some(AudioStreamInfo {
                codec: "aac".to_owned(),
                sample_rate: Some(48_000),
                channels: Some(2),
                bitrate: Some(160_000),
            }),
        };

        let dto = MediaInfoDto::try_from(media).unwrap_or_else(|error| panic!("{error}"));
        assert_eq!(dto.file_size_bytes, u64::MAX);
        assert_eq!(
            dto.available_output_modes,
            vec![
                MediaOutputMode::VideoWithAudio,
                MediaOutputMode::VideoOnly,
                MediaOutputMode::AudioOnly,
            ]
        );
        assert_eq!(dto.video.map(|video| video.codec).as_deref(), Some("hevc"));
        assert_eq!(dto.audio.and_then(|audio| audio.channels), Some(2));
    }

    #[test]
    fn application_errors_keep_stable_identity_and_diagnostic() {
        let error = MediaBridgeError::from(ApplicationError::from(MediaError::UnsupportedInput(
            "missing streams".to_owned(),
        )));

        assert_eq!(error.code, MediaBridgeErrorCode::UnsupportedInput);
        assert!(error.diagnostic.contains("missing streams"));
    }

    #[test]
    fn empty_paths_are_structured_input_failures() {
        let error = canonicalize_path(PathBuf::new()).expect_err("an empty path must fail");

        assert_eq!(error.code, MediaBridgeErrorCode::CannotOpenInput);
    }
}
