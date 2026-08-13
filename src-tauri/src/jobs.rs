use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use mediaforge_core::{
    AudioQuality, Cancellation, JobState, MediaBackend, MediaError, OutputMode, ProgressObserver,
    ProgressUpdate, TranscodeRequest, TrimRange,
};
use serde::{Deserialize, Serialize};
use tauri::Emitter;

use crate::contract::ApiErrorDto;

const JOB_EVENT_NAME: &str = "transcode-job-event";

#[derive(Default)]
pub(crate) struct JobRegistry {
    current: Mutex<Option<JobRecord>>,
}

impl JobRegistry {
    pub(crate) fn has_active_job(&self) -> Result<bool, ApiErrorDto> {
        Ok(self
            .current
            .lock()?
            .as_ref()
            .is_some_and(|job| job.state.is_active()))
    }
}

pub(crate) struct JobRecord {
    id: String,
    state: JobState,
    input_path: PathBuf,
    output_path: PathBuf,
    cancellation: Arc<JobCancellation>,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct StartTranscodeRequestDto {
    input_path: String,
    output_path: String,
    mode: OutputModeDto,
    trim: TrimRangeDto,
    audio_quality: Option<AudioQualityDto>,
    overwrite: bool,
}

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
enum OutputModeDto {
    VideoWithAudio,
    VideoOnly,
    AudioOnly,
}

impl From<OutputModeDto> for OutputMode {
    fn from(value: OutputModeDto) -> Self {
        match value {
            OutputModeDto::VideoWithAudio => Self::VideoWithAudio,
            OutputModeDto::VideoOnly => Self::VideoOnly,
            OutputModeDto::AudioOnly => Self::AudioOnly,
        }
    }
}

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct TrimRangeDto {
    start_ms: u64,
    end_ms: u64,
}

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
enum AudioQualityDto {
    High,
    Medium,
    Low,
}

impl From<AudioQualityDto> for AudioQuality {
    fn from(value: AudioQualityDto) -> Self {
        match value {
            AudioQualityDto::High => Self::High,
            AudioQualityDto::Medium => Self::Medium,
            AudioQualityDto::Low => Self::Low,
        }
    }
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct JobSnapshotDto {
    job_id: String,
    state: JobStateDto,
    input_path: String,
    output_path: String,
}

#[derive(Clone, Copy, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
enum JobStateDto {
    Idle,
    Preparing,
    Running,
    Completed,
    Cancelled,
    Failed,
}

impl From<JobState> for JobStateDto {
    fn from(value: JobState) -> Self {
        match value {
            JobState::Idle => Self::Idle,
            JobState::Preparing => Self::Preparing,
            JobState::Running => Self::Running,
            JobState::Completed => Self::Completed,
            JobState::Cancelled => Self::Cancelled,
            JobState::Failed => Self::Failed,
        }
    }
}

#[derive(Clone, Debug, Serialize)]
#[serde(tag = "type", rename_all = "camelCase")]
enum JobEventDto {
    Preparing {
        #[serde(rename = "jobId")]
        job_id: String,
    },
    Progress {
        #[serde(rename = "jobId")]
        job_id: String,
        percent: f64,
        #[serde(rename = "processedMs")]
        processed_ms: u64,
        #[serde(rename = "totalMs")]
        total_ms: u64,
        #[serde(rename = "framesPerSecond")]
        frames_per_second: Option<f64>,
        speed: Option<f64>,
    },
    Completed {
        #[serde(rename = "jobId")]
        job_id: String,
        #[serde(rename = "outputPath")]
        output_path: String,
    },
    Cancelled {
        #[serde(rename = "jobId")]
        job_id: String,
    },
    Failed {
        #[serde(rename = "jobId")]
        job_id: String,
        error: ApiErrorDto,
    },
}

#[derive(Default)]
struct JobCancellation {
    requested: AtomicBool,
}

impl Cancellation for JobCancellation {
    fn is_cancelled(&self) -> bool {
        self.requested.load(Ordering::Acquire)
    }
}

struct TauriProgressObserver {
    app: tauri::AppHandle,
    job_id: String,
    last_emit: Mutex<Instant>,
    last_processed_ms: AtomicU64,
}

impl TauriProgressObserver {
    fn new(app: tauri::AppHandle, job_id: String) -> Self {
        let now = Instant::now();
        Self {
            app,
            job_id,
            last_emit: Mutex::new(now.checked_sub(Duration::from_millis(100)).unwrap_or(now)),
            last_processed_ms: AtomicU64::new(0),
        }
    }
}

impl ProgressObserver for TauriProgressObserver {
    fn on_progress(&self, update: ProgressUpdate) {
        // Invariant: concurrent backend callbacks cannot regress the time shown by the UI.
        let processed_ms = self
            .last_processed_ms
            .fetch_max(update.processed_ms, Ordering::AcqRel)
            .max(update.processed_ms);
        let Ok(mut last_emit) = self.last_emit.lock() else {
            return;
        };
        // Contract: the terminal sample bypasses throttling so completion reaches the UI promptly.
        if last_emit.elapsed() < Duration::from_millis(100) && processed_ms < update.total_ms {
            return;
        }
        *last_emit = Instant::now();
        let event = JobEventDto::Progress {
            job_id: self.job_id.clone(),
            percent: ProgressUpdate {
                processed_ms,
                ..update
            }
            .percent(),
            processed_ms,
            total_ms: update.total_ms,
            frames_per_second: update.frames_per_second,
            speed: update.speed,
        };
        if let Err(error) = self.app.emit(JOB_EVENT_NAME, event) {
            tracing::warn!(error = %error, "progress event delivery failed");
        }
    }
}

pub(crate) fn start_job<B: MediaBackend>(
    app: &tauri::AppHandle,
    backend: Arc<B>,
    registry: Arc<JobRegistry>,
    dto: StartTranscodeRequestDto,
) -> Result<JobSnapshotDto, ApiErrorDto> {
    let media = backend.probe(PathBuf::from(&dto.input_path).as_path())?;
    let mode = OutputMode::from(dto.mode);
    media.validate_mode(mode)?;
    let trim = TrimRange::new(dto.trim.start_ms, dto.trim.end_ms, media.duration_ms)?;
    let request = TranscodeRequest {
        input_path: PathBuf::from(&dto.input_path),
        output_path: PathBuf::from(&dto.output_path),
        mode,
        trim,
        audio_quality: dto
            .audio_quality
            .map_or(AudioQuality::Medium, AudioQuality::from),
        overwrite: dto.overwrite,
    };
    if request.output_path.exists() && !request.overwrite {
        return Err(ApiErrorDto::from(MediaError::OutputExists(
            request.output_path.clone(),
        )));
    }
    let id = uuid::Uuid::new_v4().to_string();
    let cancellation = Arc::new(JobCancellation::default());
    let record = JobRecord {
        id: id.clone(),
        state: JobState::Preparing,
        input_path: request.input_path.clone(),
        output_path: request.output_path.clone(),
        cancellation: Arc::clone(&cancellation),
    };
    {
        // Invariant: reserving the slot under the registry lock makes concurrent starts exclusive.
        let mut current = registry.current.lock()?;
        if current.as_ref().is_some_and(|job| job.state.is_active()) {
            return Err(ApiErrorDto::from(MediaError::JobActive));
        }
        *current = Some(record);
    }

    app.emit(
        JOB_EVENT_NAME,
        JobEventDto::Preparing { job_id: id.clone() },
    )
    .map_err(|error| ApiErrorDto::unexpected(error.to_string()))?;
    let snapshot = JobSnapshotDto {
        job_id: id.clone(),
        state: JobStateDto::Preparing,
        input_path: dto.input_path,
        output_path: dto.output_path,
    };
    let task_app = app.clone();
    // Constraint: FFmpeg performs blocking native work and must stay off async runtime workers.
    tauri::async_runtime::spawn_blocking(move || {
        set_job_state(&registry, &id, JobState::Running);
        let observer = TauriProgressObserver::new(task_app.clone(), id.clone());
        let result = backend.transcode(&request, &observer, cancellation);
        let (state, event) = match result {
            Ok(()) => (
                JobState::Completed,
                JobEventDto::Completed {
                    job_id: id.clone(),
                    output_path: request.output_path.to_string_lossy().into_owned(),
                },
            ),
            Err(MediaError::Cancelled) => (
                JobState::Cancelled,
                JobEventDto::Cancelled { job_id: id.clone() },
            ),
            Err(error) => {
                tracing::error!(job_id = %id, error = %error, "transcode failed");
                (
                    JobState::Failed,
                    JobEventDto::Failed {
                        job_id: id.clone(),
                        error: ApiErrorDto::from(error),
                    },
                )
            }
        };
        // Invariant: observers see terminal state before reacting to the terminal event.
        set_job_state(&registry, &id, state);
        if let Err(error) = task_app.emit(JOB_EVENT_NAME, event) {
            tracing::warn!(job_id = %id, error = %error, "terminal event delivery failed");
        }
    });

    Ok(snapshot)
}

pub(crate) fn cancel_job(registry: &JobRegistry, job_id: &str) -> Result<(), ApiErrorDto> {
    let current = registry.current.lock()?;
    let Some(job) = current.as_ref() else {
        return Err(ApiErrorDto::from(MediaError::JobNotFound));
    };
    if job.id != job_id || !job.state.is_active() {
        return Err(ApiErrorDto::from(MediaError::JobNotFound));
    }
    job.cancellation.requested.store(true, Ordering::Release);
    Ok(())
}

fn set_job_state(registry: &JobRegistry, job_id: &str, state: JobState) {
    let Ok(mut current) = registry.current.lock() else {
        tracing::error!(job_id, "job registry lock was poisoned");
        return;
    };
    if let Some(job) = current.as_mut().filter(|job| job.id == job_id) {
        job.state = state;
        tracing::debug!(
            job_id,
            input_path = %job.input_path.display(),
            output_path = %job.output_path.display(),
            ?state,
            "job state changed"
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn progress_event_snapshot_matches_typescript_union() {
        let event = JobEventDto::Progress {
            job_id: "job-1".to_owned(),
            percent: 25.0,
            processed_ms: 250,
            total_ms: 1_000,
            frames_per_second: Some(30.0),
            speed: Some(2.0),
        };

        assert_eq!(
            serde_json::to_value(event).expect("test event must serialize"),
            serde_json::json!({
                "type": "progress",
                "jobId": "job-1",
                "percent": 25.0,
                "processedMs": 250,
                "totalMs": 1_000,
                "framesPerSecond": 30.0,
                "speed": 2.0
            })
        );
    }
}
