//! Domain contracts and application policy for `MediaForge`.

use std::path::{Path, PathBuf};
use std::sync::Arc;

use thiserror::Error;

/// Describes the media features available in the active backend.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct BackendCapabilities {
    /// Human-readable `FFmpeg` version.
    pub ffmpeg_version: String,
    /// Whether the active platform adapter can encode H.264.
    pub h264_available: bool,
    /// Whether the native AAC encoder is available.
    pub aac: bool,
    /// Whether libmp3lame encoding is available.
    pub libmp3lame: bool,
}

/// Metadata for the selected primary video stream.
#[derive(Clone, Debug, PartialEq)]
pub struct VideoStreamInfo {
    /// Codec display name reported by `FFmpeg`.
    pub codec: String,
    /// Display width in pixels.
    pub width: u32,
    /// Display height in pixels.
    pub height: u32,
    /// Frames per second when known.
    pub frame_rate: Option<f64>,
    /// Average stream bitrate when known.
    pub bitrate: Option<u64>,
    /// Pixel format when known.
    pub pixel_format: Option<String>,
}

/// Metadata for the selected primary audio stream.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct AudioStreamInfo {
    /// Codec display name reported by `FFmpeg`.
    pub codec: String,
    /// Sample rate in hertz when known.
    pub sample_rate: Option<u32>,
    /// Channel count when known.
    pub channels: Option<u16>,
    /// Average stream bitrate when known.
    pub bitrate: Option<u64>,
}

/// Domain metadata for one local media file.
#[derive(Clone, Debug, PartialEq)]
pub struct MediaInfo {
    /// Canonical input path.
    pub path: PathBuf,
    /// Last path component for display.
    pub file_name: String,
    /// File size in bytes.
    pub file_size_bytes: u64,
    /// Container duration in milliseconds.
    pub duration_ms: u64,
    /// Container format reported by `FFmpeg`.
    pub format: String,
    /// Selected primary video stream.
    pub video: Option<VideoStreamInfo>,
    /// Selected primary audio stream.
    pub audio: Option<AudioStreamInfo>,
}

impl MediaInfo {
    /// Returns output modes supported by the available primary streams.
    #[must_use]
    pub fn available_output_modes(&self) -> Vec<OutputMode> {
        match (&self.video, &self.audio) {
            (Some(_), Some(_)) => vec![
                OutputMode::VideoWithAudio,
                OutputMode::VideoOnly,
                OutputMode::AudioOnly,
            ],
            (Some(_), None) => vec![OutputMode::VideoOnly],
            (None, Some(_)) => vec![OutputMode::AudioOnly],
            (None, None) => Vec::new(),
        }
    }

    /// Validates that this input can satisfy an output mode.
    ///
    /// # Errors
    ///
    /// Returns [`MediaError::UnsupportedInput`] when required streams are absent.
    pub fn validate_mode(&self, mode: OutputMode) -> Result<(), MediaError> {
        if self.available_output_modes().contains(&mode) {
            Ok(())
        } else {
            Err(MediaError::UnsupportedInput(format!(
                "the source does not support {mode:?}"
            )))
        }
    }
}

/// Output recipes exposed to users.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum OutputMode {
    /// H.264 video and AAC audio in MP4.
    VideoWithAudio,
    /// H.264 video without audio in MP4.
    VideoOnly,
    /// MP3 audio without video.
    AudioOnly,
}

impl OutputMode {
    /// Returns the filename extension without a leading dot.
    #[must_use]
    pub const fn extension(self) -> &'static str {
        match self {
            Self::VideoWithAudio | Self::VideoOnly => "mp4",
            Self::AudioOnly => "mp3",
        }
    }
}

/// User-facing MP3 quality choices.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AudioQuality {
    /// 256 kbps MP3.
    High,
    /// 192 kbps MP3.
    Medium,
    /// 128 kbps MP3.
    Low,
}

impl AudioQuality {
    /// Returns the target MP3 bitrate in bits per second.
    #[must_use]
    pub const fn bitrate(self) -> usize {
        match self {
            Self::High => 256_000,
            Self::Medium => 192_000,
            Self::Low => 128_000,
        }
    }
}

/// A validated half-open time range in milliseconds.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct TrimRange {
    start_ms: u64,
    end_ms: u64,
}

impl TrimRange {
    /// Creates a trim range bounded by a media duration.
    ///
    /// # Errors
    ///
    /// Returns [`MediaError::InvalidTrimRange`] unless
    /// `start_ms < end_ms <= duration_ms`.
    pub fn new(start_ms: u64, end_ms: u64, duration_ms: u64) -> Result<Self, MediaError> {
        if start_ms >= end_ms || end_ms > duration_ms {
            return Err(MediaError::InvalidTrimRange {
                start_ms,
                end_ms,
                duration_ms,
            });
        }

        Ok(Self { start_ms, end_ms })
    }

    /// Returns the inclusive range start in milliseconds.
    #[must_use]
    pub const fn start_ms(self) -> u64 {
        self.start_ms
    }

    /// Returns the exclusive range end in milliseconds.
    #[must_use]
    pub const fn end_ms(self) -> u64 {
        self.end_ms
    }

    /// Returns the selected duration in milliseconds.
    #[must_use]
    pub const fn duration_ms(self) -> u64 {
        self.end_ms - self.start_ms
    }
}

/// A validated request passed to a media backend.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TranscodeRequest {
    /// Input media path.
    pub input_path: PathBuf,
    /// Final destination path.
    pub output_path: PathBuf,
    /// Output recipe.
    pub mode: OutputMode,
    /// Selected source range.
    pub trim: TrimRange,
    /// MP3 quality used for audio-only output.
    pub audio_quality: AudioQuality,
    /// Whether an existing destination may be replaced after successful encoding.
    pub overwrite: bool,
}

/// A progress sample emitted by the media backend.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ProgressUpdate {
    /// Processed output time relative to the trim start.
    pub processed_ms: u64,
    /// Total selected duration.
    pub total_ms: u64,
    /// Current processing frame rate when known.
    pub frames_per_second: Option<f64>,
    /// Current processing speed relative to realtime when known.
    pub speed: Option<f64>,
}

impl ProgressUpdate {
    /// Returns a monotonic-friendly percentage bounded to 0 through 100.
    #[must_use]
    pub fn percent(self) -> f64 {
        if self.total_ms == 0 {
            return 0.0;
        }
        let basis_points = u32::try_from(
            u128::from(self.processed_ms.min(self.total_ms)) * 10_000 / u128::from(self.total_ms),
        )
        .unwrap_or(10_000);
        f64::from(basis_points) / 100.0
    }
}

/// Receives progress samples during a transcode operation.
pub trait ProgressObserver: Send + Sync {
    /// Records one progress update.
    fn on_progress(&self, update: ProgressUpdate);
}

/// Reports whether a transcode operation should stop.
pub trait Cancellation: Send + Sync {
    /// Returns true after cancellation has been requested.
    fn is_cancelled(&self) -> bool;
}

/// Media operations required by the desktop application.
pub trait MediaBackend: Send + Sync + 'static {
    /// Reports the backend's available codecs.
    fn capabilities(&self) -> BackendCapabilities;

    /// Probes one local media file.
    ///
    /// # Errors
    ///
    /// Returns a categorized media error when the file cannot be inspected.
    fn probe(&self, path: &Path) -> Result<MediaInfo, MediaError>;

    /// Transcodes one validated request and commits the final output.
    ///
    /// The backend owns a shared cancellation handle because native I/O may
    /// retain its interrupt callback until this method returns.
    ///
    /// # Errors
    ///
    /// Returns a categorized media error on validation, cancellation, codec,
    /// decoding, encoding, muxing, or filesystem failure.
    fn transcode(
        &self,
        request: &TranscodeRequest,
        observer: &dyn ProgressObserver,
        cancellation: Arc<dyn Cancellation>,
    ) -> Result<(), MediaError>;
}

/// User-visible lifecycle states for one transcode job.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum JobState {
    /// No job has started.
    Idle,
    /// The backend is validating and opening inputs.
    Preparing,
    /// The backend is producing output.
    Running,
    /// Output was committed successfully.
    Completed,
    /// The user cancelled the operation.
    Cancelled,
    /// The operation ended with an error.
    Failed,
}

impl JobState {
    /// Returns true while source replacement and a second job must be rejected.
    #[must_use]
    pub const fn is_active(self) -> bool {
        matches!(self, Self::Preparing | Self::Running)
    }
}

/// Stable error categories crossing the application boundary.
#[derive(Debug, Error)]
pub enum MediaError {
    /// No supported primary stream was found.
    #[error("unsupported input: {0}")]
    UnsupportedInput(String),
    /// The input could not be opened.
    #[error("cannot open input: {0}")]
    CannotOpenInput(String),
    /// Decoding failed.
    #[error("decode failed: {0}")]
    DecodeFailed(String),
    /// A required encoder is unavailable.
    #[error("encoder unavailable: {0}")]
    EncoderUnavailable(String),
    /// The trim selection violates media bounds.
    #[error("invalid trim range {start_ms}..{end_ms} for duration {duration_ms}")]
    InvalidTrimRange {
        /// Requested start time.
        start_ms: u64,
        /// Requested end time.
        end_ms: u64,
        /// Input duration.
        duration_ms: u64,
    },
    /// The destination already exists and overwrite was not approved.
    #[error("output already exists: {0}")]
    OutputExists(PathBuf),
    /// The destination could not be created.
    #[error("cannot create output: {0}")]
    OutputCreateFailed(String),
    /// Writing or committing the destination failed.
    #[error("disk write failed: {0}")]
    DiskWriteFailed(String),
    /// Another job is already active.
    #[error("another transcode job is active")]
    JobActive,
    /// A requested job identifier does not exist.
    #[error("transcode job was not found")]
    JobNotFound,
    /// Cancellation was requested.
    #[error("transcode was cancelled")]
    Cancelled,
    /// The backend failed outside a more specific category.
    #[error("unexpected media error: {0}")]
    Unexpected(String),
}

/// Calculates the balanced H.264 bitrate policy in bits per second.
#[must_use]
pub fn balanced_video_bitrate(
    width: u32,
    height: u32,
    frames_per_second: Option<f64>,
    source_bitrate: Option<u64>,
) -> u64 {
    let frames_per_second = frames_per_second.unwrap_or(30.0).max(1.0);
    let calculated = (f64::from(width) * f64::from(height) * frames_per_second * 0.07)
        .clamp(2_000_000.0, 20_000_000.0);
    #[allow(
        clippy::cast_possible_truncation,
        clippy::cast_sign_loss,
        reason = "the finite policy result is positive and clamped to 20 million"
    )]
    let bounded = calculated as u64;
    source_bitrate.map_or(bounded, |source| bounded.min(source))
}

/// Proposes an output beside the source with the requested mode's extension.
#[must_use]
pub fn propose_output_path(input: &Path, mode: OutputMode) -> PathBuf {
    let extension = mode.extension();
    let output = input.with_extension(extension);
    let aliases_input = input
        .extension()
        .and_then(std::ffi::OsStr::to_str)
        .is_some_and(|input_extension| input_extension.eq_ignore_ascii_case(extension));
    if !aliases_input {
        return output;
    }
    let Some(stem) = input.file_stem() else {
        return output;
    };
    let mut converted_stem = stem.to_os_string();
    converted_stem.push("-converted");
    input
        .with_file_name(converted_stem)
        .with_extension(extension)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn trim_range_rejects_empty_and_out_of_bounds_ranges() {
        assert!(TrimRange::new(100, 100, 1_000).is_err());
        assert!(TrimRange::new(900, 1_001, 1_000).is_err());
        assert_eq!(
            TrimRange::new(100, 900, 1_000)
                .map(TrimRange::duration_ms)
                .ok(),
            Some(800)
        );
    }

    #[test]
    fn output_modes_follow_available_streams() {
        let media = MediaInfo {
            path: PathBuf::from("movie.mov"),
            file_name: "movie.mov".into(),
            file_size_bytes: 1,
            duration_ms: 1_000,
            format: "mov".into(),
            video: Some(VideoStreamInfo {
                codec: "h264".into(),
                width: 1920,
                height: 1080,
                frame_rate: Some(30.0),
                bitrate: None,
                pixel_format: None,
            }),
            audio: Some(AudioStreamInfo {
                codec: "aac".into(),
                sample_rate: Some(48_000),
                channels: Some(2),
                bitrate: None,
            }),
        };

        assert_eq!(
            media.available_output_modes(),
            vec![
                OutputMode::VideoWithAudio,
                OutputMode::VideoOnly,
                OutputMode::AudioOnly
            ]
        );
    }

    #[test]
    fn bitrate_policy_is_bounded_and_never_exceeds_source() {
        assert_eq!(
            balanced_video_bitrate(320, 180, Some(24.0), None),
            2_000_000
        );
        assert_eq!(
            balanced_video_bitrate(7680, 4320, Some(120.0), None),
            20_000_000
        );
        assert_eq!(
            balanced_video_bitrate(1920, 1080, Some(30.0), Some(3_000_000)),
            3_000_000
        );
    }

    #[test]
    fn output_path_uses_mode_extension() {
        assert_eq!(
            propose_output_path(Path::new("/tmp/clip.mov"), OutputMode::AudioOnly),
            PathBuf::from("/tmp/clip.mp3")
        );
        assert_eq!(
            propose_output_path(Path::new("/tmp/clip.MP4"), OutputMode::VideoWithAudio),
            PathBuf::from("/tmp/clip-converted.mp4")
        );
    }
}
