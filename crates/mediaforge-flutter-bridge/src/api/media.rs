use std::fmt;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, OnceLock};

use flutter_rust_bridge::frb;
use mediaforge_application::{
    ApplicationError, ErrorCode, JobCoordinator, JobEvent, JobEventSink, JobSnapshot, JobState,
    MediaFacade,
};
use mediaforge_core::{
    propose_output_path, AudioQuality, AudioStreamInfo, BackendCapabilities, MediaBackend,
    MediaError, MediaInfo, OutputMode, TranscodeRequest, TrimRange, VideoStreamInfo,
};
use mediaforge_ffmpeg::FfmpegBackend;

use crate::frb_generated::StreamSink;

static MEDIA_RUNTIME: OnceLock<Result<MediaRuntime, ApplicationError>> = OnceLock::new();

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

/// MP3 quality values retained in the stable conversion request contract.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum MediaAudioQuality {
    /// 256 kbps MP3.
    High,
    /// 192 kbps MP3.
    Medium,
    /// 128 kbps MP3.
    Low,
}

/// Plain conversion request accepted from Flutter presentation state.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct StartTranscodeRequestDto {
    /// Canonical source path previously returned by [`probe_media`].
    pub input_path: String,
    /// Destination path proposed by [`default_output_path`].
    pub output_path: String,
    /// Requested output recipe.
    pub mode: MediaOutputMode,
    /// MP3 quality retained for the future audio-only workflow.
    pub audio_quality: MediaAudioQuality,
    /// Inclusive trim start in integer milliseconds.
    pub start_ms: u64,
    /// Exclusive trim end in integer milliseconds.
    pub end_ms: u64,
    /// Whether an existing destination may be replaced after success.
    pub overwrite: bool,
}

/// Lifecycle state returned with a conversion snapshot.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum JobStateDto {
    /// No job has started.
    Idle,
    /// A worker owns the job and is opening media resources.
    Preparing,
    /// The backend is producing output.
    Running,
    /// The destination was committed successfully.
    Completed,
    /// Cooperative cancellation ended the operation.
    Cancelled,
    /// A non-cancellation error ended the operation.
    Failed,
}

/// Plain snapshot returned immediately after the application reserves a job.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct JobSnapshotDto {
    /// Process-local job identifier used to correlate events.
    pub job_id: u64,
    /// Current lifecycle state.
    pub state: JobStateDto,
    /// Canonical source path reserved by the job.
    pub input_path: String,
    /// Canonical destination path reserved by the job.
    pub output_path: String,
}

/// Discriminator controlling the meaningful fields in [`JobEventDto`].
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum JobEventKindDto {
    /// The application reserved the exclusive worker slot.
    Preparing,
    /// The backend emitted a throttled monotonic progress sample.
    Progress,
    /// The final destination was committed successfully.
    Completed,
    /// Cooperative cancellation and cleanup completed.
    Cancelled,
    /// A non-cancellation failure and cleanup completed.
    Failed,
}

/// Tagged application event delivered to the Flutter conversion controller.
#[derive(Clone, Debug, PartialEq)]
pub struct JobEventDto {
    /// Discriminator controlling which optional payload fields are meaningful.
    pub kind: JobEventKindDto,
    /// Job that produced the event.
    pub job_id: u64,
    /// Completion percentage for [`JobEventKindDto::Progress`].
    pub percent: Option<f64>,
    /// Processed time for [`JobEventKindDto::Progress`].
    pub processed_ms: Option<u64>,
    /// Selected duration for [`JobEventKindDto::Progress`].
    pub total_ms: Option<u64>,
    /// Current frame rate for [`JobEventKindDto::Progress`] when available.
    pub frames_per_second: Option<f64>,
    /// Current realtime multiplier for [`JobEventKindDto::Progress`] when available.
    pub speed: Option<f64>,
    /// Final destination for [`JobEventKindDto::Completed`].
    pub output_path: Option<String>,
    /// Structured failure for [`JobEventKindDto::Failed`].
    pub error: Option<MediaBridgeError>,
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
    Ok(media_runtime()?.facade.capabilities().into())
}

/// Canonicalizes and probes one regular local media file on FRB's Rust executor.
///
/// # Errors
///
/// Returns a structured application failure when the path cannot be
/// canonicalized, the input is unsupported, or `FFmpeg` cannot inspect it.
pub fn probe_media(path: String) -> Result<MediaInfoDto, MediaBridgeError> {
    let canonical_path = canonicalize_path(PathBuf::from(path))?;
    let media = media_runtime()?.facade.probe(&canonical_path)?;
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

/// Validates and starts one primary Video + Audio conversion.
///
/// # Errors
///
/// Returns a stable application failure for stale paths, unsupported mode,
/// invalid trim, unavailable encoders, or an already active job.
pub fn start_transcode(
    request: StartTranscodeRequestDto,
) -> Result<JobSnapshotDto, MediaBridgeError> {
    let input_path = canonicalize_path(PathBuf::from(&request.input_path))?;
    let output_path = canonicalize_output_path(Path::new(&request.output_path))?;
    let runtime = media_runtime()?;
    let media = runtime.facade.probe(&input_path)?;
    let request = build_transcode_request(request, input_path, output_path, &media)?;
    JobSnapshotDto::try_from(runtime.coordinator.start(request)?)
}

/// Registers the process's current Flutter subscriber for application events.
///
/// The stream remains open for the process lifetime. Re-registering replaces a
/// stale presentation subscriber and replays any retained terminal event.
pub fn job_events(sink: StreamSink<JobEventDto>) {
    if let Ok(runtime) = media_runtime() {
        runtime.events.subscribe(sink);
    }
}

struct MediaRuntime {
    facade: MediaFacade,
    coordinator: JobCoordinator,
    events: Arc<BridgeJobEventSink>,
}

fn media_runtime() -> Result<&'static MediaRuntime, MediaBridgeError> {
    MEDIA_RUNTIME
        .get_or_init(|| {
            FfmpegBackend::new()
                .map_err(ApplicationError::from)
                .map(|backend| {
                    let backend: Arc<dyn MediaBackend> = Arc::new(backend);
                    let events = Arc::new(BridgeJobEventSink::default());
                    MediaRuntime {
                        facade: MediaFacade::new(Arc::clone(&backend)),
                        coordinator: JobCoordinator::new(backend, events.clone()),
                        events,
                    }
                })
        })
        .as_ref()
        .map_err(|error| MediaBridgeError::from(error.clone()))
}

#[frb(ignore)]
#[derive(Default)]
struct BridgeJobEventSink {
    delivery: Mutex<EventDelivery>,
}

#[frb(ignore)]
#[derive(Default)]
struct EventDelivery {
    subscriber: Option<StreamSink<JobEventDto>>,
    retained_terminal: Option<JobEventDto>,
}

impl BridgeJobEventSink {
    fn subscribe(&self, sink: StreamSink<JobEventDto>) {
        let (retained, subscriber) = {
            let mut delivery = self
                .delivery
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner);
            delivery.subscriber = Some(sink);
            (
                delivery.retained_terminal.take(),
                delivery.subscriber.clone(),
            )
        };
        if let (Some(event), Some(sink)) = (retained, subscriber) {
            if sink.add(event.clone()).is_err() {
                let mut delivery = self
                    .delivery
                    .lock()
                    .unwrap_or_else(std::sync::PoisonError::into_inner);
                delivery.subscriber = None;
                delivery.retained_terminal = Some(event);
            }
        }
    }
}

impl JobEventSink for BridgeJobEventSink {
    fn emit(&self, event: JobEvent) {
        let job_id = job_event_id(&event);
        let event = JobEventDto::try_from(event).unwrap_or_else(|error| JobEventDto {
            kind: JobEventKindDto::Failed,
            job_id,
            percent: None,
            processed_ms: None,
            total_ms: None,
            frames_per_second: None,
            speed: None,
            output_path: None,
            error: Some(error),
        });
        let terminal = event.is_terminal();
        let subscriber = self
            .delivery
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
            .subscriber
            .clone();
        if subscriber
            .as_ref()
            .is_some_and(|subscriber| subscriber.add(event.clone()).is_ok())
        {
            return;
        }
        let mut delivery = self
            .delivery
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        delivery.subscriber = None;
        if terminal {
            delivery.retained_terminal = Some(event);
        }
    }
}

impl JobEventDto {
    fn is_terminal(&self) -> bool {
        matches!(
            self.kind,
            JobEventKindDto::Completed | JobEventKindDto::Cancelled | JobEventKindDto::Failed
        )
    }
}

fn job_event_id(event: &JobEvent) -> u64 {
    match event {
        JobEvent::Preparing { id }
        | JobEvent::Progress { id, .. }
        | JobEvent::Completed { id, .. }
        | JobEvent::Cancelled { id }
        | JobEvent::Failed { id, .. } => id.value(),
    }
}

fn build_transcode_request(
    request: StartTranscodeRequestDto,
    input_path: PathBuf,
    output_path: PathBuf,
    media: &MediaInfo,
) -> Result<TranscodeRequest, MediaBridgeError> {
    let StartTranscodeRequestDto {
        input_path: request_input_path,
        output_path: request_output_path,
        mode,
        audio_quality,
        start_ms,
        end_ms,
        overwrite,
    } = request;
    drop((request_input_path, request_output_path));
    let mode = OutputMode::from(mode);
    if mode != OutputMode::VideoWithAudio {
        return Err(MediaBridgeError::from(ApplicationError::from(
            MediaError::UnsupportedInput(
                "only Video + Audio conversion is enabled in this release milestone".to_owned(),
            ),
        )));
    }
    media.validate_mode(mode).map_err(ApplicationError::from)?;
    let trim =
        TrimRange::new(start_ms, end_ms, media.duration_ms).map_err(ApplicationError::from)?;
    Ok(TranscodeRequest {
        input_path,
        output_path,
        mode,
        trim,
        audio_quality: audio_quality.into(),
        overwrite,
    })
}

fn canonicalize_output_path(path: &Path) -> Result<PathBuf, MediaBridgeError> {
    let file_name = path.file_name().ok_or_else(|| {
        MediaBridgeError::from(ApplicationError::from(MediaError::OutputCreateFailed(
            "output path must include a filename".to_owned(),
        )))
    })?;
    let parent = path.parent().ok_or_else(|| {
        MediaBridgeError::from(ApplicationError::from(MediaError::OutputCreateFailed(
            "output path must include a parent directory".to_owned(),
        )))
    })?;
    let parent = std::fs::canonicalize(parent).map_err(|error| {
        MediaBridgeError::from(ApplicationError::from(MediaError::OutputCreateFailed(
            error.to_string(),
        )))
    })?;
    Ok(parent.join(file_name))
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

impl From<MediaAudioQuality> for AudioQuality {
    fn from(quality: MediaAudioQuality) -> Self {
        match quality {
            MediaAudioQuality::High => Self::High,
            MediaAudioQuality::Medium => Self::Medium,
            MediaAudioQuality::Low => Self::Low,
        }
    }
}

impl From<JobState> for JobStateDto {
    fn from(state: JobState) -> Self {
        match state {
            JobState::Idle => Self::Idle,
            JobState::Preparing => Self::Preparing,
            JobState::Running => Self::Running,
            JobState::Completed => Self::Completed,
            JobState::Cancelled => Self::Cancelled,
            JobState::Failed => Self::Failed,
        }
    }
}

impl TryFrom<JobSnapshot> for JobSnapshotDto {
    type Error = MediaBridgeError;

    fn try_from(snapshot: JobSnapshot) -> Result<Self, Self::Error> {
        Ok(Self {
            job_id: snapshot.id.value(),
            state: snapshot.state.into(),
            input_path: path_to_string(snapshot.input_path)?,
            output_path: path_to_string(snapshot.output_path)?,
        })
    }
}

impl TryFrom<JobEvent> for JobEventDto {
    type Error = MediaBridgeError;

    fn try_from(event: JobEvent) -> Result<Self, Self::Error> {
        Ok(match event {
            JobEvent::Preparing { id } => Self {
                kind: JobEventKindDto::Preparing,
                job_id: id.value(),
                percent: None,
                processed_ms: None,
                total_ms: None,
                frames_per_second: None,
                speed: None,
                output_path: None,
                error: None,
            },
            JobEvent::Progress {
                id,
                percent,
                processed_ms,
                total_ms,
                frames_per_second,
                speed,
            } => Self {
                kind: JobEventKindDto::Progress,
                job_id: id.value(),
                percent: Some(percent),
                processed_ms: Some(processed_ms),
                total_ms: Some(total_ms),
                frames_per_second,
                speed,
                output_path: None,
                error: None,
            },
            JobEvent::Completed { id, output_path } => Self {
                kind: JobEventKindDto::Completed,
                job_id: id.value(),
                percent: None,
                processed_ms: None,
                total_ms: None,
                frames_per_second: None,
                speed: None,
                output_path: Some(path_to_string(output_path)?),
                error: None,
            },
            JobEvent::Cancelled { id } => Self {
                kind: JobEventKindDto::Cancelled,
                job_id: id.value(),
                percent: None,
                processed_ms: None,
                total_ms: None,
                frames_per_second: None,
                speed: None,
                output_path: None,
                error: None,
            },
            JobEvent::Failed { id, error } => Self {
                kind: JobEventKindDto::Failed,
                job_id: id.value(),
                percent: None,
                processed_ms: None,
                total_ms: None,
                frames_per_second: None,
                speed: None,
                output_path: None,
                error: Some(error.into()),
            },
        })
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

    #[test]
    fn primary_request_reconstructs_domain_trim_and_rejects_other_modes() {
        let media = MediaInfo {
            path: PathBuf::from("/tmp/input.mov"),
            file_name: "input.mov".to_owned(),
            file_size_bytes: 1,
            duration_ms: 2_000,
            format: "mov".to_owned(),
            video: Some(VideoStreamInfo {
                codec: "h264".to_owned(),
                width: 320,
                height: 180,
                frame_rate: Some(24.0),
                bitrate: None,
                pixel_format: None,
            }),
            audio: Some(AudioStreamInfo {
                codec: "aac".to_owned(),
                sample_rate: Some(48_000),
                channels: Some(1),
                bitrate: None,
            }),
        };
        let request = StartTranscodeRequestDto {
            input_path: "/tmp/input.mov".to_owned(),
            output_path: "/tmp/output.mp4".to_owned(),
            mode: MediaOutputMode::VideoWithAudio,
            audio_quality: MediaAudioQuality::Medium,
            start_ms: 200,
            end_ms: 1_200,
            overwrite: false,
        };

        let domain = build_transcode_request(
            request.clone(),
            PathBuf::from("/tmp/input.mov"),
            PathBuf::from("/tmp/output.mp4"),
            &media,
        )
        .unwrap_or_else(|error| panic!("{error}"));
        assert_eq!(domain.trim.start_ms(), 200);
        assert_eq!(domain.trim.end_ms(), 1_200);
        assert!(!domain.overwrite);

        let invalid_trim = build_transcode_request(
            StartTranscodeRequestDto {
                start_ms: 1_200,
                end_ms: 1_200,
                ..request.clone()
            },
            PathBuf::from("/tmp/input.mov"),
            PathBuf::from("/tmp/output.mp4"),
            &media,
        )
        .expect_err("an empty trim must remain a structured domain failure");
        assert_eq!(invalid_trim.code, MediaBridgeErrorCode::InvalidTrimRange);

        let error = build_transcode_request(
            StartTranscodeRequestDto {
                mode: MediaOutputMode::VideoOnly,
                ..request
            },
            PathBuf::from("/tmp/input.mov"),
            PathBuf::from("/tmp/output.mp4"),
            &media,
        )
        .expect_err("secondary modes remain disabled until M9");
        assert_eq!(error.code, MediaBridgeErrorCode::UnsupportedInput);
    }
}
