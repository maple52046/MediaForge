//! Tauri composition root and versioned desktop IPC adapter.

mod contract;
mod jobs;

use std::path::PathBuf;
use std::sync::Arc;

use mediaforge_core::{MediaBackend, MediaError};
use mediaforge_ffmpeg::FfmpegBackend;
use tauri::{Manager, State};
use tracing_subscriber::EnvFilter;

use crate::contract::{ApiErrorDto, BackendCapabilitiesDto, MediaInfoDto};
use crate::jobs::{cancel_job, start_job, JobRegistry, JobSnapshotDto, StartTranscodeRequestDto};

struct AppState {
    backend: Arc<FfmpegBackend>,
    jobs: Arc<JobRegistry>,
}

#[tauri::command]
#[allow(
    clippy::needless_pass_by_value,
    reason = "Tauri commands use framework-owned extractor signatures"
)]
fn get_backend_capabilities(state: State<'_, AppState>) -> BackendCapabilitiesDto {
    state.backend.capabilities().into()
}

#[tauri::command]
#[allow(
    clippy::needless_pass_by_value,
    reason = "Tauri commands use framework-owned extractor signatures"
)]
async fn load_media(
    app: tauri::AppHandle,
    state: State<'_, AppState>,
    path: String,
) -> Result<MediaInfoDto, ApiErrorDto> {
    if state.jobs.has_active_job()? {
        return Err(ApiErrorDto::from(MediaError::JobActive));
    }

    let path = PathBuf::from(path);
    let canonical_path = path
        .canonicalize()
        .map_err(|error| ApiErrorDto::from(MediaError::CannotOpenInput(error.to_string())))?;
    app.asset_protocol_scope()
        .allow_file(&canonical_path)
        .map_err(|error| ApiErrorDto::from(MediaError::CannotOpenInput(error.to_string())))?;

    let backend = Arc::clone(&state.backend);
    tauri::async_runtime::spawn_blocking(move || backend.probe(&canonical_path))
        .await
        .map_err(|error| ApiErrorDto::unexpected(error.to_string()))?
        .map(MediaInfoDto::from)
        .map_err(ApiErrorDto::from)
}

#[tauri::command]
#[allow(
    clippy::needless_pass_by_value,
    reason = "Tauri commands use framework-owned extractor signatures"
)]
fn start_transcode(
    app: tauri::AppHandle,
    state: State<'_, AppState>,
    request: StartTranscodeRequestDto,
) -> Result<JobSnapshotDto, ApiErrorDto> {
    start_job(
        &app,
        Arc::clone(&state.backend),
        Arc::clone(&state.jobs),
        request,
    )
}

#[tauri::command]
#[allow(
    clippy::needless_pass_by_value,
    reason = "Tauri commands deserialize owned extractor arguments"
)]
fn cancel_transcode(state: State<'_, AppState>, job_id: String) -> Result<(), ApiErrorDto> {
    cancel_job(&state.jobs, &job_id)
}

/// Starts the `MediaForge` desktop application.
pub fn run() {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .json()
        .init();

    let backend = match FfmpegBackend::new() {
        Ok(backend) => backend,
        Err(error) => {
            tracing::error!(error = %error, "FFmpeg initialization failed");
            return;
        }
    };

    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .manage(AppState {
            backend: Arc::new(backend),
            jobs: Arc::new(JobRegistry::default()),
        })
        .invoke_handler(tauri::generate_handler![
            get_backend_capabilities,
            load_media,
            start_transcode,
            cancel_transcode
        ])
        .run(tauri::generate_context!())
        .unwrap_or_else(|error| tracing::error!(error = %error, "Tauri runtime failed"));
}
