//! Framework-independent use cases for the `MediaForge` desktop application.

use std::fmt;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use mediaforge_core::{
    BackendCapabilities, Cancellation, MediaBackend, MediaError, MediaInfo, ProgressObserver,
    ProgressUpdate, TranscodeRequest,
};

const PROGRESS_INTERVAL: Duration = Duration::from_millis(100);
static JOB_SEQUENCE: AtomicU64 = AtomicU64::new(1);

/// Stable identifier for one conversion attempt.
#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
pub struct JobId(u64);

impl JobId {
    /// Returns the process-local numeric identifier.
    #[must_use]
    pub const fn value(self) -> u64 {
        self.0
    }
}

impl fmt::Display for JobId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.0.fmt(formatter)
    }
}

/// Observable lifecycle of the most recently started conversion.
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub enum JobState {
    /// No conversion has been started.
    #[default]
    Idle,
    /// The worker owns the job slot and is opening media resources.
    Preparing,
    /// The backend is producing output.
    Running,
    /// The final output was committed successfully.
    Completed,
    /// Cancellation ended the operation without committing output.
    Cancelled,
    /// A non-cancellation error ended the operation.
    Failed,
}

impl JobState {
    /// Returns whether the job still owns the exclusive conversion slot.
    #[must_use]
    pub const fn is_active(self) -> bool {
        matches!(self, Self::Preparing | Self::Running)
    }
}

/// Immutable view of a conversion's identity, paths, and current state.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct JobSnapshot {
    /// Job identifier used by events and cancellation.
    pub id: JobId,
    /// Current lifecycle state.
    pub state: JobState,
    /// Source path reserved by the job.
    pub input_path: PathBuf,
    /// Destination path reserved by the job.
    pub output_path: PathBuf,
}

/// Stable error categories exposed to presentation adapters.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ErrorCode {
    /// The source lacks a required media stream.
    UnsupportedInput,
    /// The source could not be opened.
    CannotOpenInput,
    /// A stream could not be decoded.
    DecodeFailed,
    /// A required encoder is unavailable.
    EncoderUnavailable,
    /// The selected range violates media bounds.
    InvalidTrimRange,
    /// The destination exists without overwrite approval.
    OutputExists,
    /// The temporary destination could not be created.
    OutputCreateFailed,
    /// Output data could not be written or committed.
    DiskWriteFailed,
    /// Another conversion owns the exclusive slot.
    JobActive,
    /// No matching active job exists.
    JobNotFound,
    /// The operation was cancelled.
    Cancelled,
    /// The failure does not fit a more stable category.
    Unexpected,
}

impl ErrorCode {
    /// Returns the lower camel-case key consumed by presentation localization.
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::UnsupportedInput => "unsupportedInput",
            Self::CannotOpenInput => "cannotOpenInput",
            Self::DecodeFailed => "decodeFailed",
            Self::EncoderUnavailable => "encoderUnavailable",
            Self::InvalidTrimRange => "invalidTrimRange",
            Self::OutputExists => "outputExists",
            Self::OutputCreateFailed => "outputCreateFailed",
            Self::DiskWriteFailed => "diskWriteFailed",
            Self::JobActive => "jobActive",
            Self::JobNotFound => "jobNotFound",
            Self::Cancelled => "cancelled",
            Self::Unexpected => "unexpected",
        }
    }
}

/// Application-owned error safe to carry through UI event adapters.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ApplicationError {
    /// Stable category for localization and control flow.
    pub code: ErrorCode,
    /// Diagnostic text suitable for structured logs and development details.
    pub message: String,
}

impl ApplicationError {
    fn unexpected(message: impl Into<String>) -> Self {
        Self {
            code: ErrorCode::Unexpected,
            message: message.into(),
        }
    }
}

impl fmt::Display for ApplicationError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.message.fmt(formatter)
    }
}

impl std::error::Error for ApplicationError {}

impl From<MediaError> for ApplicationError {
    fn from(error: MediaError) -> Self {
        let code = match error {
            MediaError::UnsupportedInput(_) => ErrorCode::UnsupportedInput,
            MediaError::CannotOpenInput(_) => ErrorCode::CannotOpenInput,
            MediaError::DecodeFailed(_) => ErrorCode::DecodeFailed,
            MediaError::EncoderUnavailable(_) => ErrorCode::EncoderUnavailable,
            MediaError::InvalidTrimRange { .. } => ErrorCode::InvalidTrimRange,
            MediaError::OutputExists(_) => ErrorCode::OutputExists,
            MediaError::OutputCreateFailed(_) => ErrorCode::OutputCreateFailed,
            MediaError::DiskWriteFailed(_) => ErrorCode::DiskWriteFailed,
            MediaError::JobActive => ErrorCode::JobActive,
            MediaError::JobNotFound => ErrorCode::JobNotFound,
            MediaError::Cancelled => ErrorCode::Cancelled,
            MediaError::Unexpected(_) => ErrorCode::Unexpected,
        };
        Self {
            code,
            message: error.to_string(),
        }
    }
}

/// Framework-independent access to backend discovery and source metadata.
pub struct MediaFacade {
    backend: Arc<dyn MediaBackend>,
}

impl MediaFacade {
    /// Creates a facade around the backend selected by an outer composition root.
    #[must_use]
    pub fn new(backend: Arc<dyn MediaBackend>) -> Self {
        Self { backend }
    }

    /// Reports codec capabilities without exposing adapter-specific values.
    #[must_use]
    pub fn capabilities(&self) -> BackendCapabilities {
        self.backend.capabilities()
    }

    /// Probes one caller-validated local path through the configured backend.
    ///
    /// # Errors
    ///
    /// Returns a stable [`ApplicationError`] while retaining the backend's
    /// diagnostic cause.
    pub fn probe(&self, path: &Path) -> Result<MediaInfo, ApplicationError> {
        self.backend.probe(path).map_err(ApplicationError::from)
    }
}

/// Events emitted during one conversion lifecycle.
#[derive(Clone, Debug, PartialEq)]
pub enum JobEvent {
    /// The job has reserved the exclusive slot and a worker will start.
    Preparing {
        /// Job that reserved the slot.
        id: JobId,
    },
    /// The backend has produced a throttled monotonic progress sample.
    Progress {
        /// Job that produced the sample.
        id: JobId,
        /// Percentage bounded to zero through one hundred.
        percent: f64,
        /// Processed time relative to the trim start.
        processed_ms: u64,
        /// Total selected duration.
        total_ms: u64,
        /// Current processing frame rate when available.
        frames_per_second: Option<f64>,
        /// Current speed relative to realtime when available.
        speed: Option<f64>,
    },
    /// The backend committed the final destination.
    Completed {
        /// Job that committed output.
        id: JobId,
        /// Final destination committed by the backend.
        output_path: PathBuf,
    },
    /// Cancellation ended the operation and cleanup finished.
    Cancelled {
        /// Job whose cleanup has finished.
        id: JobId,
    },
    /// A non-cancellation error ended the operation and cleanup finished.
    Failed {
        /// Job whose cleanup has finished.
        id: JobId,
        /// Stable error and retained diagnostic cause.
        error: ApplicationError,
    },
}

/// Receives application events without depending on a presentation framework.
pub trait JobEventSink: Send + Sync + 'static {
    /// Delivers one ordered lifecycle event.
    fn emit(&self, event: JobEvent);
}

/// Thread-safe cancellation handle shared with the media backend.
#[derive(Debug, Default)]
pub struct CancellationToken {
    requested: AtomicBool,
}

impl CancellationToken {
    /// Requests cooperative cancellation and returns whether this was new.
    pub fn cancel(&self) -> bool {
        !self.requested.swap(true, Ordering::AcqRel)
    }
}

impl Cancellation for CancellationToken {
    fn is_cancelled(&self) -> bool {
        self.requested.load(Ordering::Acquire)
    }
}

struct JobRecord {
    snapshot: JobSnapshot,
    cancellation: Arc<CancellationToken>,
}

/// Coordinates the single background conversion allowed by `MediaForge`.
pub struct JobCoordinator {
    backend: Arc<dyn MediaBackend>,
    sink: Arc<dyn JobEventSink>,
    current: Arc<Mutex<Option<JobRecord>>>,
}

impl JobCoordinator {
    /// Creates a coordinator around an injected backend and event destination.
    #[must_use]
    pub fn new(backend: Arc<dyn MediaBackend>, sink: Arc<dyn JobEventSink>) -> Self {
        Self {
            backend,
            sink,
            current: Arc::new(Mutex::new(None)),
        }
    }

    /// Starts one backend operation on a dedicated Rust worker thread.
    ///
    /// # Errors
    ///
    /// Returns [`ErrorCode::JobActive`] when another job owns the slot, or an
    /// unexpected error if coordinator state is poisoned.
    pub fn start(&self, request: TranscodeRequest) -> Result<JobSnapshot, ApplicationError> {
        let id = JobId(JOB_SEQUENCE.fetch_add(1, Ordering::Relaxed));
        let cancellation = Arc::new(CancellationToken::default());
        let snapshot = JobSnapshot {
            id,
            state: JobState::Preparing,
            input_path: request.input_path.clone(),
            output_path: request.output_path.clone(),
        };
        {
            // Invariant: reserving under one lock makes concurrent starts mutually exclusive.
            let mut current = self.lock_current()?;
            if current
                .as_ref()
                .is_some_and(|job| job.snapshot.state.is_active())
            {
                return Err(ApplicationError::from(MediaError::JobActive));
            }
            *current = Some(JobRecord {
                snapshot: snapshot.clone(),
                cancellation: Arc::clone(&cancellation),
            });
        }

        self.sink.emit(JobEvent::Preparing { id });
        let backend = Arc::clone(&self.backend);
        let sink = Arc::clone(&self.sink);
        let current = Arc::clone(&self.current);
        // Constraint: FFmpeg performs blocking native work and owns this thread until cleanup.
        thread::spawn(move || {
            set_state(&current, id, JobState::Running);
            let observer = CoordinatedProgress::new(id, Arc::clone(&sink));
            let backend_cancellation: Arc<dyn Cancellation> = cancellation;
            let result = backend.transcode(&request, &observer, backend_cancellation);
            let (state, event) = match result {
                Ok(()) => (
                    JobState::Completed,
                    JobEvent::Completed {
                        id,
                        output_path: request.output_path,
                    },
                ),
                Err(MediaError::Cancelled) => (JobState::Cancelled, JobEvent::Cancelled { id }),
                Err(error) => (
                    JobState::Failed,
                    JobEvent::Failed {
                        id,
                        error: ApplicationError::from(error),
                    },
                ),
            };
            // Invariant: terminal state is visible before consumers receive the terminal event.
            set_state(&current, id, state);
            sink.emit(event);
        });

        Ok(snapshot)
    }

    /// Requests cancellation of the currently active job.
    ///
    /// # Errors
    ///
    /// Returns [`ErrorCode::JobNotFound`] when the identifier is stale or the
    /// current job is already terminal.
    pub fn cancel(&self, id: JobId) -> Result<(), ApplicationError> {
        let current = self.lock_current()?;
        let Some(job) = current
            .as_ref()
            .filter(|job| job.snapshot.id == id && job.snapshot.state.is_active())
        else {
            return Err(ApplicationError::from(MediaError::JobNotFound));
        };
        job.cancellation.cancel();
        Ok(())
    }

    /// Returns the most recent job snapshot, if any.
    ///
    /// # Errors
    ///
    /// Returns an unexpected error if coordinator state is poisoned.
    pub fn current(&self) -> Result<Option<JobSnapshot>, ApplicationError> {
        Ok(self
            .lock_current()?
            .as_ref()
            .map(|job| job.snapshot.clone()))
    }

    fn lock_current(
        &self,
    ) -> Result<std::sync::MutexGuard<'_, Option<JobRecord>>, ApplicationError> {
        self.current
            .lock()
            .map_err(|error| ApplicationError::unexpected(error.to_string()))
    }
}

fn set_state(current: &Mutex<Option<JobRecord>>, id: JobId, state: JobState) {
    if let Ok(mut current) = current.lock() {
        if let Some(job) = current.as_mut().filter(|job| job.snapshot.id == id) {
            job.snapshot.state = state;
        }
    }
}

struct CoordinatedProgress {
    id: JobId,
    sink: Arc<dyn JobEventSink>,
    last_emit: Mutex<Instant>,
    last_processed_ms: AtomicU64,
}

impl CoordinatedProgress {
    fn new(id: JobId, sink: Arc<dyn JobEventSink>) -> Self {
        let now = Instant::now();
        Self {
            id,
            sink,
            last_emit: Mutex::new(now.checked_sub(PROGRESS_INTERVAL).unwrap_or(now)),
            last_processed_ms: AtomicU64::new(0),
        }
    }
}

impl ProgressObserver for CoordinatedProgress {
    fn on_progress(&self, update: ProgressUpdate) {
        let processed_ms = self
            .last_processed_ms
            .fetch_max(update.processed_ms, Ordering::AcqRel)
            .max(update.processed_ms)
            .min(update.total_ms);
        let Ok(mut last_emit) = self.last_emit.lock() else {
            return;
        };
        // Contract: terminal progress bypasses throttling so the UI reaches one hundred percent.
        if last_emit.elapsed() < PROGRESS_INTERVAL && processed_ms < update.total_ms {
            return;
        }
        *last_emit = Instant::now();
        self.sink.emit(JobEvent::Progress {
            id: self.id,
            percent: ProgressUpdate {
                processed_ms,
                ..update
            }
            .percent(),
            processed_ms,
            total_ms: update.total_ms,
            frames_per_second: update.frames_per_second,
            speed: update.speed,
        });
    }
}

#[cfg(test)]
mod tests {
    use std::collections::VecDeque;
    use std::path::Path;
    use std::sync::Condvar;

    use mediaforge_core::{AudioQuality, BackendCapabilities, MediaInfo, OutputMode, TrimRange};

    use super::*;

    #[derive(Default)]
    struct RecordingSink {
        events: Mutex<Vec<JobEvent>>,
        changed: Condvar,
    }

    impl RecordingSink {
        fn wait_for_terminal(&self) -> Vec<JobEvent> {
            let events = self
                .events
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner);
            let (events, _) = self
                .changed
                .wait_timeout_while(events, Duration::from_secs(2), |events| {
                    !events.last().is_some_and(|event| {
                        matches!(
                            event,
                            JobEvent::Completed { .. }
                                | JobEvent::Cancelled { .. }
                                | JobEvent::Failed { .. }
                        )
                    })
                })
                .unwrap_or_else(std::sync::PoisonError::into_inner);
            events.clone()
        }
    }

    impl JobEventSink for RecordingSink {
        fn emit(&self, event: JobEvent) {
            self.events
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner)
                .push(event);
            self.changed.notify_all();
        }
    }

    struct FakeBackend {
        results: Mutex<VecDeque<Result<(), MediaError>>>,
        wait_for_cancel: bool,
    }

    impl FakeBackend {
        fn succeeds() -> Self {
            Self {
                results: Mutex::new(VecDeque::from([Ok(())])),
                wait_for_cancel: false,
            }
        }

        fn cancellable() -> Self {
            Self {
                results: Mutex::new(VecDeque::new()),
                wait_for_cancel: true,
            }
        }
    }

    impl MediaBackend for FakeBackend {
        fn capabilities(&self) -> BackendCapabilities {
            BackendCapabilities {
                ffmpeg_version: "fake".to_owned(),
                h264_available: true,
                aac: true,
                libmp3lame: true,
            }
        }

        fn probe(&self, path: &Path) -> Result<MediaInfo, MediaError> {
            Ok(MediaInfo {
                path: path.to_path_buf(),
                file_name: "input.mov".to_owned(),
                file_size_bytes: 1_024,
                duration_ms: 1_000,
                format: "mov".to_owned(),
                video: None,
                audio: None,
            })
        }

        fn transcode(
            &self,
            request: &TranscodeRequest,
            observer: &dyn ProgressObserver,
            cancellation: Arc<dyn Cancellation>,
        ) -> Result<(), MediaError> {
            observer.on_progress(ProgressUpdate {
                processed_ms: 100,
                total_ms: request.trim.duration_ms(),
                frames_per_second: Some(30.0),
                speed: Some(2.0),
            });
            if self.wait_for_cancel {
                while !cancellation.is_cancelled() {
                    thread::yield_now();
                }
                return Err(MediaError::Cancelled);
            }
            self.results
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner)
                .pop_front()
                .unwrap_or(Ok(()))
        }
    }

    fn request() -> TranscodeRequest {
        TranscodeRequest {
            input_path: "input.mov".into(),
            output_path: "output.mp4".into(),
            mode: OutputMode::VideoWithAudio,
            trim: TrimRange::new(0, 1_000, 1_000).unwrap_or_else(|error| panic!("{error}")),
            audio_quality: AudioQuality::Medium,
            overwrite: false,
        }
    }

    #[test]
    fn media_facade_preserves_backend_values() {
        let facade = MediaFacade::new(Arc::new(FakeBackend::succeeds()));

        assert!(facade.capabilities().h264_available);
        let media = facade
            .probe(Path::new("/canonical/input.mov"))
            .unwrap_or_else(|error| panic!("{error}"));
        assert_eq!(media.path, PathBuf::from("/canonical/input.mov"));
        assert_eq!(media.file_size_bytes, 1_024);
    }

    #[test]
    fn successful_job_transitions_and_emits_terminal_event() {
        let sink = Arc::new(RecordingSink::default());
        let coordinator = JobCoordinator::new(Arc::new(FakeBackend::succeeds()), sink.clone());
        let snapshot = coordinator
            .start(request())
            .unwrap_or_else(|error| panic!("{error}"));
        assert_eq!(snapshot.state, JobState::Preparing);

        let events = sink.wait_for_terminal();
        assert!(matches!(events.first(), Some(JobEvent::Preparing { .. })));
        assert!(matches!(events.last(), Some(JobEvent::Completed { .. })));
        assert_eq!(
            coordinator
                .current()
                .unwrap_or_else(|error| panic!("{error}"))
                .map(|snapshot| snapshot.state),
            Some(JobState::Completed)
        );
    }

    #[test]
    fn active_job_rejects_concurrent_start_and_cancels_once() {
        let sink = Arc::new(RecordingSink::default());
        let coordinator = JobCoordinator::new(Arc::new(FakeBackend::cancellable()), sink.clone());
        let snapshot = coordinator
            .start(request())
            .unwrap_or_else(|error| panic!("{error}"));
        let error = coordinator
            .start(request())
            .expect_err("second job must fail");
        assert_eq!(error.code, ErrorCode::JobActive);

        coordinator
            .cancel(snapshot.id)
            .unwrap_or_else(|error| panic!("{error}"));
        assert!(matches!(
            sink.wait_for_terminal().last(),
            Some(JobEvent::Cancelled { .. })
        ));
        assert_eq!(
            coordinator.cancel(snapshot.id).expect_err("terminal job"),
            ApplicationError::from(MediaError::JobNotFound)
        );
    }

    #[test]
    fn progress_is_monotonic_and_terminal_sample_bypasses_throttle() {
        let sink = Arc::new(RecordingSink::default());
        let observer = CoordinatedProgress::new(JobId(7), sink.clone());
        for processed_ms in [400, 300, 1_000] {
            observer.on_progress(ProgressUpdate {
                processed_ms,
                total_ms: 1_000,
                frames_per_second: None,
                speed: None,
            });
        }
        let events = sink
            .events
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner);
        let samples = events
            .iter()
            .filter_map(|event| match event {
                JobEvent::Progress { processed_ms, .. } => Some(*processed_ms),
                _ => None,
            })
            .collect::<Vec<_>>();
        assert_eq!(samples, vec![400, 1_000]);
    }
}
