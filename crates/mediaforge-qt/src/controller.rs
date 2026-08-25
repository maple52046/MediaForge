//! CXX-Qt presentation adapter for the `MediaForge` application use cases.

#![allow(
    unsafe_code,
    reason = "CXX-Qt expands the declared bridge into audited generated FFI shims"
)]
#![allow(
    clippy::float_cmp,
    reason = "generated Q_PROPERTY setters compare scalar values before emitting change signals"
)]

use std::path::PathBuf;
use std::pin::Pin;
use std::sync::Arc;
use std::thread;

use cxx_qt::{CxxQtThread, CxxQtType, Threading};
use cxx_qt_lib::{QString, QStringList};
use mediaforge_application::{ApplicationError, ErrorCode, JobCoordinator, JobEvent, JobEventSink};
use mediaforge_core::{
    propose_output_path, AudioQuality, BackendCapabilities, MediaBackend, MediaError, MediaInfo,
    OutputMode, TranscodeRequest, TrimRange,
};
use mediaforge_ffmpeg::FfmpegBackend;

#[cxx_qt::bridge]
pub mod qobject {
    // SAFETY: CXX-Qt owns the ABI shims for these Qt value types and validates
    // their declarations against the included Qt headers during generation.
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        include!("cxx-qt-lib/qstringlist.h");

        /// Qt string used at the presentation boundary.
        type QString = cxx_qt_lib::QString;
        /// Qt string list used for available conversion modes.
        type QStringList = cxx_qt_lib::QStringList;
    }

    extern "RustQt" {
        /// Sole QObject bridge between QML and MediaForge's Rust use cases.
        #[qobject]
        #[qml_element]
        #[qproperty(QString, application_state, cxx_name = "applicationState")]
        #[qproperty(QString, job_state, cxx_name = "jobState")]
        #[qproperty(QString, job_id, cxx_name = "jobId")]
        #[qproperty(bool, media_loaded, cxx_name = "mediaLoaded")]
        #[qproperty(QString, media_path, cxx_name = "mediaPath")]
        #[qproperty(QString, media_file_name, cxx_name = "mediaFileName")]
        #[qproperty(i64, media_file_size, cxx_name = "mediaFileSize")]
        #[qproperty(QString, media_format, cxx_name = "mediaFormat")]
        #[qproperty(i64, duration_ms, cxx_name = "durationMs")]
        #[qproperty(bool, has_video, cxx_name = "hasVideo")]
        #[qproperty(QString, video_codec, cxx_name = "videoCodec")]
        #[qproperty(i32, video_width, cxx_name = "videoWidth")]
        #[qproperty(i32, video_height, cxx_name = "videoHeight")]
        #[qproperty(f64, video_frame_rate, cxx_name = "videoFrameRate")]
        #[qproperty(bool, has_audio, cxx_name = "hasAudio")]
        #[qproperty(QString, audio_codec, cxx_name = "audioCodec")]
        #[qproperty(i32, audio_sample_rate, cxx_name = "audioSampleRate")]
        #[qproperty(i32, audio_channels, cxx_name = "audioChannels")]
        #[qproperty(QStringList, available_modes, cxx_name = "availableModes")]
        #[qproperty(QString, ffmpeg_version, cxx_name = "ffmpegVersion")]
        #[qproperty(bool, h264_available, cxx_name = "h264Available")]
        #[qproperty(bool, aac_available, cxx_name = "aacAvailable")]
        #[qproperty(bool, mp3_available, cxx_name = "mp3Available")]
        #[qproperty(f64, progress)]
        #[qproperty(i64, processed_ms, cxx_name = "processedMs")]
        #[qproperty(i64, total_ms, cxx_name = "totalMs")]
        #[qproperty(f64, frames_per_second, cxx_name = "framesPerSecond")]
        #[qproperty(f64, speed)]
        #[qproperty(QString, error_code, cxx_name = "errorCode")]
        #[qproperty(QString, error_message, cxx_name = "errorMessage")]
        type MediaForgeController = super::MediaForgeControllerRust;

        /// Probes a local media path on a Rust worker thread.
        #[qinvokable]
        #[cxx_name = "loadMedia"]
        fn load_media(self: Pin<&mut MediaForgeController>, path: &QString);

        /// Proposes a destination beside the loaded source.
        #[qinvokable]
        #[cxx_name = "defaultOutputPath"]
        fn default_output_path(self: Pin<&mut MediaForgeController>, mode: &QString) -> QString;

        /// Validates and starts one conversion on a Rust worker thread.
        #[qinvokable]
        #[cxx_name = "startConversion"]
        fn start_conversion(
            self: Pin<&mut MediaForgeController>,
            output_path: &QString,
            mode: &QString,
            quality: &QString,
            start_ms: i64,
            end_ms: i64,
            overwrite: bool,
        );

        /// Requests cancellation of the active conversion.
        #[qinvokable]
        #[cxx_name = "cancelConversion"]
        fn cancel_conversion(self: Pin<&mut MediaForgeController>);

        /// Clears the current presentation error.
        #[qinvokable]
        #[cxx_name = "clearError"]
        fn clear_error(self: Pin<&mut MediaForgeController>);

        /// Clears loaded media while preserving backend capabilities and settings.
        #[qinvokable]
        #[cxx_name = "clearMedia"]
        fn clear_media(self: Pin<&mut MediaForgeController>);

        /// Cancels active work and emits `safeToClose` after cleanup.
        #[qinvokable]
        #[cxx_name = "requestClose"]
        fn request_close(self: Pin<&mut MediaForgeController>);

        /// Reports that a source has been probed successfully.
        #[qsignal]
        #[cxx_name = "mediaLoadedSuccessfully"]
        fn media_loaded_successfully(self: Pin<&mut MediaForgeController>);

        /// Reports that source probing failed.
        #[qsignal]
        #[cxx_name = "mediaLoadFailed"]
        fn media_load_failed(self: Pin<&mut MediaForgeController>);

        /// Reports that a conversion worker has reserved the job slot.
        #[qsignal]
        #[cxx_name = "conversionStarted"]
        fn conversion_started(self: Pin<&mut MediaForgeController>);

        /// Reports a throttled progress update.
        #[qsignal]
        #[cxx_name = "conversionProgress"]
        fn conversion_progress(self: Pin<&mut MediaForgeController>);

        /// Reports successful output commit.
        #[qsignal]
        #[cxx_name = "conversionCompleted"]
        fn conversion_completed(self: Pin<&mut MediaForgeController>, output_path: &QString);

        /// Reports completed cancellation and partial-file cleanup.
        #[qsignal]
        #[cxx_name = "conversionCancelled"]
        fn conversion_cancelled(self: Pin<&mut MediaForgeController>);

        /// Reports terminal conversion failure.
        #[qsignal]
        #[cxx_name = "conversionFailed"]
        fn conversion_failed(self: Pin<&mut MediaForgeController>);

        /// Reports that no worker retains resources needed during shutdown.
        #[qsignal]
        #[cxx_name = "safeToClose"]
        fn safe_to_close(self: Pin<&mut MediaForgeController>);
    }

    impl cxx_qt::Threading for MediaForgeController {}
}

/// Rust state backing the generated controller `QObject`.
#[allow(
    clippy::struct_excessive_bools,
    reason = "boolean media capabilities are independent QML-observable properties"
)]
pub struct MediaForgeControllerRust {
    application_state: QString,
    job_state: QString,
    job_id: QString,
    media_loaded: bool,
    media_path: QString,
    media_file_name: QString,
    media_file_size: i64,
    media_format: QString,
    duration_ms: i64,
    has_video: bool,
    video_codec: QString,
    video_width: i32,
    video_height: i32,
    video_frame_rate: f64,
    has_audio: bool,
    audio_codec: QString,
    audio_sample_rate: i32,
    audio_channels: i32,
    available_modes: QStringList,
    ffmpeg_version: QString,
    h264_available: bool,
    aac_available: bool,
    mp3_available: bool,
    progress: f64,
    processed_ms: i64,
    total_ms: i64,
    frames_per_second: f64,
    speed: f64,
    error_code: QString,
    error_message: QString,
    backend: Option<Arc<FfmpegBackend>>,
    coordinator: Option<JobCoordinator>,
    media: Option<MediaInfo>,
    close_pending: bool,
}

impl Default for MediaForgeControllerRust {
    fn default() -> Self {
        let backend = FfmpegBackend::new().map(Arc::new);
        let (backend, capabilities, error) = match backend {
            Ok(backend) => {
                let capabilities = backend.capabilities();
                (Some(backend), Some(capabilities), None)
            }
            Err(error) => (None, None, Some(ApplicationError::from(error))),
        };
        let capabilities = capabilities.unwrap_or_else(empty_capabilities);
        Self {
            application_state: QString::from(if error.is_some() { "failed" } else { "ready" }),
            job_state: QString::from("idle"),
            job_id: QString::default(),
            media_loaded: false,
            media_path: QString::default(),
            media_file_name: QString::default(),
            media_file_size: 0,
            media_format: QString::default(),
            duration_ms: 0,
            has_video: false,
            video_codec: QString::default(),
            video_width: 0,
            video_height: 0,
            video_frame_rate: 0.0,
            has_audio: false,
            audio_codec: QString::default(),
            audio_sample_rate: 0,
            audio_channels: 0,
            available_modes: QStringList::default(),
            ffmpeg_version: QString::from(capabilities.ffmpeg_version.as_str()),
            h264_available: capabilities.h264_available,
            aac_available: capabilities.aac,
            mp3_available: capabilities.libmp3lame,
            progress: 0.0,
            processed_ms: 0,
            total_ms: 0,
            frames_per_second: 0.0,
            speed: 0.0,
            error_code: error
                .as_ref()
                .map_or_else(QString::default, |error| QString::from(error.code.as_str())),
            error_message: error.as_ref().map_or_else(QString::default, |error| {
                QString::from(error.message.as_str())
            }),
            backend,
            coordinator: None,
            media: None,
            close_pending: false,
        }
    }
}

impl qobject::MediaForgeController {
    /// Starts an asynchronous probe without exposing `FFmpeg` or thread values to QML.
    pub fn load_media(mut self: Pin<&mut Self>, path: &QString) {
        if self.source_mutation_is_blocked() {
            self.as_mut()
                .report_error(&ApplicationError::from(MediaError::JobActive));
            return;
        }
        let Some(backend) = self.as_ref().rust().backend.clone() else {
            self.as_mut().report_error(&ApplicationError {
                code: ErrorCode::Unexpected,
                message: "FFmpeg backend is unavailable".to_owned(),
            });
            return;
        };
        let path = PathBuf::from(path.to_string());
        let qt_thread = self.qt_thread();
        self.as_mut().clear_error();
        self.as_mut()
            .set_application_state(QString::from("loadingMedia"));
        // Constraint: native probing can block on filesystem and codec I/O.
        thread::spawn(move || {
            let result = path
                .canonicalize()
                .map_err(|error| MediaError::CannotOpenInput(error.to_string()))
                .and_then(|path| backend.probe(&path));
            if let Err(error) = qt_thread.queue(move |mut controller| match result {
                Ok(media) => controller.as_mut().apply_media(media),
                Err(error) => {
                    controller
                        .as_mut()
                        .report_error(&ApplicationError::from(error));
                    controller.as_mut().media_load_failed();
                }
            }) {
                tracing::error!(error = %error, "media probe result could not reach Qt thread");
            }
        });
    }

    /// Returns the default destination for a mode, or an empty string if unavailable.
    pub fn default_output_path(mut self: Pin<&mut Self>, mode: &QString) -> QString {
        let controller = self.as_ref();
        let Some(media) = controller.rust().media.as_ref() else {
            return QString::default();
        };
        match parse_mode(&mode.to_string()) {
            Ok(mode) => QString::from(
                propose_output_path(&media.path, mode)
                    .to_string_lossy()
                    .as_ref(),
            ),
            Err(error) => {
                self.as_mut().report_error(&error);
                QString::default()
            }
        }
    }

    /// Validates presentation values and delegates execution to the application coordinator.
    #[allow(
        clippy::too_many_arguments,
        reason = "the invokable mirrors the fixed QML conversion form contract"
    )]
    pub fn start_conversion(
        mut self: Pin<&mut Self>,
        output_path: &QString,
        mode: &QString,
        quality: &QString,
        start_ms: i64,
        end_ms: i64,
        overwrite: bool,
    ) {
        let result =
            self.as_ref()
                .build_request(output_path, mode, quality, start_ms, end_ms, overwrite);
        let request = match result {
            Ok(request) => request,
            Err(error) => {
                self.as_mut().report_error(&error);
                return;
            }
        };
        if self.as_ref().rust().coordinator.is_none() {
            let Some(backend) = self.as_ref().rust().backend.clone() else {
                self.as_mut().report_error(&ApplicationError {
                    code: ErrorCode::Unexpected,
                    message: "FFmpeg backend is unavailable".to_owned(),
                });
                return;
            };
            let sink: Arc<dyn JobEventSink> = Arc::new(QtEventSink {
                qt_thread: self.qt_thread(),
            });
            self.as_mut().rust_mut().coordinator = Some(JobCoordinator::new(backend, sink));
        }
        self.as_mut().clear_error();
        let result = self.as_ref().rust().coordinator.as_ref().map_or_else(
            || {
                Err(ApplicationError {
                    code: ErrorCode::Unexpected,
                    message: "job coordinator is unavailable".to_owned(),
                })
            },
            |coordinator| coordinator.start(request),
        );
        if let Err(error) = result {
            self.as_mut().report_error(&error);
        }
    }

    /// Requests cooperative cancellation for the current identifier.
    pub fn cancel_conversion(mut self: Pin<&mut Self>) {
        let result = self.as_ref().rust().coordinator.as_ref().map_or_else(
            || Err(ApplicationError::from(MediaError::JobNotFound)),
            |coordinator| {
                coordinator
                    .current()?
                    .ok_or_else(|| ApplicationError::from(MediaError::JobNotFound))
                    .and_then(|job| coordinator.cancel(job.id))
            },
        );
        if let Err(error) = result {
            self.as_mut().report_error(&error);
        }
    }

    /// Clears both stable and diagnostic error properties.
    pub fn clear_error(mut self: Pin<&mut Self>) {
        self.as_mut().set_error_code(QString::default());
        self.as_mut().set_error_message(QString::default());
    }

    /// Returns the controller to its empty-source state when no operation is active.
    pub fn clear_media(mut self: Pin<&mut Self>) {
        if self.source_mutation_is_blocked() {
            self.as_mut()
                .report_error(&ApplicationError::from(MediaError::JobActive));
            return;
        }
        self.as_mut().set_media_loaded(false);
        self.as_mut().set_media_path(QString::default());
        self.as_mut().set_media_file_name(QString::default());
        self.as_mut().set_media_file_size(0);
        self.as_mut().set_media_format(QString::default());
        self.as_mut().set_duration_ms(0);
        self.as_mut().set_has_video(false);
        self.as_mut().set_video_codec(QString::default());
        self.as_mut().set_video_width(0);
        self.as_mut().set_video_height(0);
        self.as_mut().set_video_frame_rate(0.0);
        self.as_mut().set_has_audio(false);
        self.as_mut().set_audio_codec(QString::default());
        self.as_mut().set_audio_sample_rate(0);
        self.as_mut().set_audio_channels(0);
        self.as_mut().set_available_modes(QStringList::default());
        self.as_mut().set_job_state(QString::from("idle"));
        self.as_mut().set_job_id(QString::default());
        self.as_mut().set_progress(0.0);
        self.as_mut().set_processed_ms(0);
        self.as_mut().set_total_ms(0);
        self.as_mut().set_frames_per_second(0.0);
        self.as_mut().set_speed(0.0);
        self.as_mut().rust_mut().media = None;
        self.as_mut().set_application_state(QString::from("ready"));
        self.as_mut().clear_error();
    }

    /// Defers close permission until the active backend operation is terminal.
    pub fn request_close(mut self: Pin<&mut Self>) {
        if self.job_is_active() {
            self.as_mut().rust_mut().close_pending = true;
            self.as_mut().cancel_conversion();
        } else {
            self.as_mut().safe_to_close();
        }
    }

    fn build_request(
        self: Pin<&Self>,
        output_path: &QString,
        mode: &QString,
        quality: &QString,
        start_ms: i64,
        end_ms: i64,
        overwrite: bool,
    ) -> Result<TranscodeRequest, ApplicationError> {
        let media = self.rust().media.as_ref().ok_or_else(|| ApplicationError {
            code: ErrorCode::UnsupportedInput,
            message: "load media before starting conversion".to_owned(),
        })?;
        let mode = parse_mode(&mode.to_string())?;
        media.validate_mode(mode).map_err(ApplicationError::from)?;
        let start_ms = u64::try_from(start_ms).map_err(|error| ApplicationError {
            code: ErrorCode::InvalidTrimRange,
            message: error.to_string(),
        })?;
        let end_ms = u64::try_from(end_ms).map_err(|error| ApplicationError {
            code: ErrorCode::InvalidTrimRange,
            message: error.to_string(),
        })?;
        let trim =
            TrimRange::new(start_ms, end_ms, media.duration_ms).map_err(ApplicationError::from)?;
        let output_path = PathBuf::from(output_path.to_string());
        if output_path.as_os_str().is_empty() {
            return Err(ApplicationError::from(MediaError::OutputCreateFailed(
                "choose an output path".to_owned(),
            )));
        }
        Ok(TranscodeRequest {
            input_path: media.path.clone(),
            output_path,
            mode,
            trim,
            audio_quality: parse_quality(&quality.to_string())?,
            overwrite,
        })
    }

    fn apply_media(mut self: Pin<&mut Self>, media: MediaInfo) {
        let available_modes = media
            .available_output_modes()
            .into_iter()
            .map(|mode| QString::from(mode_key(mode)))
            .collect::<QStringList>();
        self.as_mut()
            .set_media_path(QString::from(media.path.to_string_lossy().as_ref()));
        self.as_mut()
            .set_media_file_name(QString::from(media.file_name.as_str()));
        self.as_mut()
            .set_media_file_size(saturating_i64(media.file_size_bytes));
        self.as_mut()
            .set_media_format(QString::from(media.format.as_str()));
        self.as_mut()
            .set_duration_ms(saturating_i64(media.duration_ms));
        if let Some(video) = media.video.as_ref() {
            self.as_mut().set_has_video(true);
            self.as_mut()
                .set_video_codec(QString::from(video.codec.as_str()));
            self.as_mut().set_video_width(saturating_i32(video.width));
            self.as_mut().set_video_height(saturating_i32(video.height));
            self.as_mut()
                .set_video_frame_rate(video.frame_rate.unwrap_or_default());
        } else {
            self.as_mut().set_has_video(false);
            self.as_mut().set_video_codec(QString::default());
            self.as_mut().set_video_width(0);
            self.as_mut().set_video_height(0);
            self.as_mut().set_video_frame_rate(0.0);
        }
        if let Some(audio) = media.audio.as_ref() {
            self.as_mut().set_has_audio(true);
            self.as_mut()
                .set_audio_codec(QString::from(audio.codec.as_str()));
            self.as_mut()
                .set_audio_sample_rate(audio.sample_rate.map_or(0, saturating_i32));
            self.as_mut()
                .set_audio_channels(audio.channels.map_or(0, i32::from));
        } else {
            self.as_mut().set_has_audio(false);
            self.as_mut().set_audio_codec(QString::default());
            self.as_mut().set_audio_sample_rate(0);
            self.as_mut().set_audio_channels(0);
        }
        self.as_mut().set_available_modes(available_modes);
        self.as_mut().set_media_loaded(true);
        self.as_mut().set_application_state(QString::from("ready"));
        self.as_mut().set_job_state(QString::from("idle"));
        self.as_mut().set_progress(0.0);
        self.as_mut().set_processed_ms(0);
        self.as_mut()
            .set_total_ms(saturating_i64(media.duration_ms));
        self.as_mut().rust_mut().media = Some(media);
        self.as_mut().media_loaded_successfully();
    }

    fn report_error(mut self: Pin<&mut Self>, error: &ApplicationError) {
        tracing::error!(code = error.code.as_str(), cause = %error, "desktop operation failed");
        self.as_mut()
            .set_error_code(QString::from(error.code.as_str()));
        self.as_mut()
            .set_error_message(QString::from(error.message.as_str()));
        if self.as_ref().application_state().to_string() == "loadingMedia" {
            self.as_mut().set_application_state(QString::from("ready"));
        }
    }

    fn job_is_active(&self) -> bool {
        self.rust()
            .coordinator
            .as_ref()
            .and_then(|coordinator| coordinator.current().ok().flatten())
            .is_some_and(|snapshot| snapshot.state.is_active())
    }

    fn source_mutation_is_blocked(&self) -> bool {
        self.job_is_active() || self.application_state().to_string() == "loadingMedia"
    }
}

struct QtEventSink {
    qt_thread: CxxQtThread<qobject::MediaForgeController>,
}

impl JobEventSink for QtEventSink {
    fn emit(&self, event: JobEvent) {
        if let Err(error) = self.qt_thread.queue(move |mut controller| {
            apply_job_event(controller.as_mut(), event);
        }) {
            tracing::error!(error = %error, "job event could not reach Qt thread");
        }
    }
}

fn apply_job_event(mut controller: Pin<&mut qobject::MediaForgeController>, event: JobEvent) {
    match event {
        JobEvent::Preparing { id } => {
            controller
                .as_mut()
                .set_job_id(QString::from(id.to_string().as_str()));
            controller
                .as_mut()
                .set_job_state(QString::from("preparing"));
            controller.as_mut().set_progress(0.0);
            controller.as_mut().set_processed_ms(0);
            controller.as_mut().conversion_started();
        }
        JobEvent::Progress {
            percent,
            processed_ms,
            total_ms,
            frames_per_second,
            speed,
            ..
        } => {
            controller.as_mut().set_job_state(QString::from("running"));
            controller.as_mut().set_progress(percent);
            controller
                .as_mut()
                .set_processed_ms(saturating_i64(processed_ms));
            controller.as_mut().set_total_ms(saturating_i64(total_ms));
            controller
                .as_mut()
                .set_frames_per_second(frames_per_second.unwrap_or_default());
            controller.as_mut().set_speed(speed.unwrap_or_default());
            controller.as_mut().conversion_progress();
        }
        JobEvent::Completed { output_path, .. } => {
            let output_path = QString::from(output_path.to_string_lossy().as_ref());
            controller
                .as_mut()
                .set_job_state(QString::from("completed"));
            controller.as_mut().set_progress(100.0);
            controller.as_mut().conversion_completed(&output_path);
            emit_close_if_pending(controller.as_mut());
        }
        JobEvent::Cancelled { .. } => {
            controller
                .as_mut()
                .set_job_state(QString::from("cancelled"));
            controller.as_mut().conversion_cancelled();
            emit_close_if_pending(controller.as_mut());
        }
        JobEvent::Failed { error, .. } => {
            controller.as_mut().set_job_state(QString::from("failed"));
            controller.as_mut().report_error(&error);
            controller.as_mut().conversion_failed();
            emit_close_if_pending(controller.as_mut());
        }
    }
}

fn emit_close_if_pending(mut controller: Pin<&mut qobject::MediaForgeController>) {
    if controller.as_ref().rust().close_pending {
        controller.as_mut().rust_mut().close_pending = false;
        controller.as_mut().safe_to_close();
    }
}

fn empty_capabilities() -> BackendCapabilities {
    BackendCapabilities {
        ffmpeg_version: "unavailable".to_owned(),
        h264_available: false,
        aac: false,
        libmp3lame: false,
    }
}

fn parse_mode(value: &str) -> Result<OutputMode, ApplicationError> {
    match value {
        "videoWithAudio" => Ok(OutputMode::VideoWithAudio),
        "videoOnly" => Ok(OutputMode::VideoOnly),
        "audioOnly" => Ok(OutputMode::AudioOnly),
        _ => Err(ApplicationError {
            code: ErrorCode::UnsupportedInput,
            message: format!("unknown output mode: {value}"),
        }),
    }
}

fn mode_key(mode: OutputMode) -> &'static str {
    match mode {
        OutputMode::VideoWithAudio => "videoWithAudio",
        OutputMode::VideoOnly => "videoOnly",
        OutputMode::AudioOnly => "audioOnly",
    }
}

fn parse_quality(value: &str) -> Result<AudioQuality, ApplicationError> {
    match value {
        "high" => Ok(AudioQuality::High),
        "medium" => Ok(AudioQuality::Medium),
        "low" => Ok(AudioQuality::Low),
        _ => Err(ApplicationError {
            code: ErrorCode::Unexpected,
            message: format!("unknown audio quality: {value}"),
        }),
    }
}

fn saturating_i64(value: u64) -> i64 {
    i64::try_from(value).unwrap_or(i64::MAX)
}

fn saturating_i32(value: u32) -> i32 {
    i32::try_from(value).unwrap_or(i32::MAX)
}

#[cfg(test)]
mod tests {
    use std::path::Path;

    use super::*;

    #[test]
    fn bridge_keys_map_all_domain_choices() {
        assert_eq!(parse_mode("videoWithAudio"), Ok(OutputMode::VideoWithAudio));
        assert_eq!(parse_quality("low"), Ok(AudioQuality::Low));
        assert_eq!(mode_key(OutputMode::AudioOnly), "audioOnly");
    }

    #[test]
    fn unknown_bridge_values_are_structured_errors() {
        assert_eq!(
            parse_mode("webm").expect_err("mode must fail").code,
            ErrorCode::UnsupportedInput
        );
        assert_eq!(
            parse_quality("lossless")
                .expect_err("quality must fail")
                .code,
            ErrorCode::Unexpected
        );
    }

    #[test]
    fn large_unsigned_values_saturate_at_qml_boundary() {
        assert_eq!(saturating_i64(u64::MAX), i64::MAX);
        assert_eq!(saturating_i32(u32::MAX), i32::MAX);
    }

    #[test]
    fn output_path_mapping_stays_framework_free() {
        assert_eq!(
            propose_output_path(Path::new("clip.mov"), OutputMode::AudioOnly),
            PathBuf::from("clip.mp3")
        );
    }
}
