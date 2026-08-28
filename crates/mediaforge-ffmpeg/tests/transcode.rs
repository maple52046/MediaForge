//! End-to-end tests for the `FFmpeg` adapter's public transcode contract.

use std::path::Path;
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

use mediaforge_core::{
    AudioQuality, Cancellation, MediaBackend, MediaError, OutputMode, ProgressObserver,
    ProgressUpdate, TranscodeRequest, TrimRange,
};
use mediaforge_ffmpeg::FfmpegBackend;

struct NeverCancelled;

impl Cancellation for NeverCancelled {
    fn is_cancelled(&self) -> bool {
        false
    }
}

struct AlwaysCancelled;

impl Cancellation for AlwaysCancelled {
    fn is_cancelled(&self) -> bool {
        true
    }
}

#[derive(Default)]
struct CancelAfterProgress {
    requested: AtomicBool,
}

impl Cancellation for CancelAfterProgress {
    fn is_cancelled(&self) -> bool {
        self.requested.load(Ordering::Acquire)
    }
}

impl ProgressObserver for CancelAfterProgress {
    fn on_progress(&self, _update: ProgressUpdate) {
        self.requested.store(true, Ordering::Release);
    }
}

#[derive(Default)]
struct RecordedProgress {
    samples: Mutex<Vec<ProgressUpdate>>,
}

impl ProgressObserver for RecordedProgress {
    fn on_progress(&self, update: ProgressUpdate) {
        if let Ok(mut samples) = self.samples.lock() {
            samples.push(update);
        }
    }
}

#[test]
#[ignore = "requires the developer-only FFmpeg CLI and macOS VideoToolbox"]
fn converts_all_supported_output_modes_and_cleans_cancelled_output() {
    let workspace = tempfile::tempdir().expect("test workspace must be created");
    let source = workspace.path().join("source.mp4");
    generate_fixture(&source);
    let backend = FfmpegBackend::new().expect("FFmpeg must initialize");
    let source_info = backend.probe(&source).expect("fixture must be probed");
    let trim = TrimRange::new(250, 1_250, source_info.duration_ms)
        .expect("fixture must contain the test selection");

    for (mode, quality, extension) in [
        (OutputMode::VideoWithAudio, AudioQuality::Medium, "full.mp4"),
        (OutputMode::VideoOnly, AudioQuality::Medium, "video.mp4"),
        (OutputMode::AudioOnly, AudioQuality::High, "audio-high.mp3"),
        (
            OutputMode::AudioOnly,
            AudioQuality::Medium,
            "audio-medium.mp3",
        ),
        (OutputMode::AudioOnly, AudioQuality::Low, "audio-low.mp3"),
    ] {
        let output = workspace.path().join(extension);
        let progress = RecordedProgress::default();
        backend
            .transcode(
                &TranscodeRequest {
                    input_path: source.clone(),
                    output_path: output.clone(),
                    mode,
                    trim,
                    audio_quality: quality,
                    overwrite: false,
                },
                &progress,
                Arc::new(NeverCancelled),
            )
            .unwrap_or_else(|error| panic!("{mode:?} transcode failed: {error}"));
        let output_info = backend.probe(&output).expect("output must be probed");
        assert!(output_info.duration_ms > 500);
        assert_eq!(output_info.video.is_some(), mode != OutputMode::AudioOnly);
        assert_eq!(output_info.audio.is_some(), mode != OutputMode::VideoOnly);
        assert!(progress
            .samples
            .lock()
            .expect("progress lock must remain healthy")
            .last()
            .is_some_and(|sample| (sample.percent() - 100.0).abs() < f64::EPSILON));
    }

    let cancelled_output = workspace.path().join("cancelled.mp4");
    let result = backend.transcode(
        &TranscodeRequest {
            input_path: source,
            output_path: cancelled_output.clone(),
            mode: OutputMode::VideoOnly,
            trim,
            audio_quality: AudioQuality::Medium,
            overwrite: false,
        },
        &RecordedProgress::default(),
        Arc::new(AlwaysCancelled),
    );
    assert!(matches!(result, Err(MediaError::Cancelled)));
    assert!(!cancelled_output.exists());
    let partial_count = std::fs::read_dir(workspace.path())
        .expect("test workspace must remain readable")
        .filter_map(Result::ok)
        .filter(|entry| entry.file_name().to_string_lossy().contains(".part."))
        .count();
    assert_eq!(partial_count, 0);
}

#[test]
#[ignore = "requires MEDIAFORGE_REAL_MEDIA and macOS VideoToolbox"]
fn validates_representative_user_media_without_mutating_the_source() {
    let Some(source) = std::env::var_os("MEDIAFORGE_REAL_MEDIA").map(std::path::PathBuf::from)
    else {
        eprintln!("MEDIAFORGE_REAL_MEDIA is unset; representative media gate skipped");
        return;
    };
    let original_size = std::fs::metadata(&source)
        .expect("representative source must be readable")
        .len();
    let backend = FfmpegBackend::new().expect("FFmpeg must initialize");
    let source_info = backend.probe(&source).expect("source must be probed");
    assert!(
        source_info
            .available_output_modes()
            .contains(&OutputMode::VideoWithAudio),
        "representative source must contain primary video and audio streams"
    );
    let trim_end = source_info.duration_ms.min(3_000);
    let trim = TrimRange::new(0, trim_end, source_info.duration_ms)
        .expect("representative source must contain a non-empty selection");
    let workspace = tempfile::tempdir().expect("test workspace must be created");
    for (mode, quality, file_name) in [
        (
            OutputMode::VideoWithAudio,
            AudioQuality::Medium,
            "representative.mp4",
        ),
        (
            OutputMode::VideoOnly,
            AudioQuality::Medium,
            "representative-video.mp4",
        ),
        (
            OutputMode::AudioOnly,
            AudioQuality::High,
            "representative-audio.mp3",
        ),
    ] {
        let output = workspace.path().join(file_name);
        backend
            .transcode(
                &TranscodeRequest {
                    input_path: source.clone(),
                    output_path: output.clone(),
                    mode,
                    trim,
                    audio_quality: quality,
                    overwrite: false,
                },
                &RecordedProgress::default(),
                Arc::new(NeverCancelled),
            )
            .unwrap_or_else(|error| panic!("{mode:?} representative transcode failed: {error}"));
        let output_info = backend.probe(&output).expect("output must be probed");
        assert_eq!(output_info.video.is_some(), mode != OutputMode::AudioOnly);
        assert_eq!(output_info.audio.is_some(), mode != OutputMode::VideoOnly);
    }

    let cancelled_output = workspace.path().join("representative-cancelled.mp4");
    let cancellation = Arc::new(CancelAfterProgress::default());
    let result = backend.transcode(
        &TranscodeRequest {
            input_path: source.clone(),
            output_path: cancelled_output.clone(),
            mode: OutputMode::VideoWithAudio,
            trim,
            audio_quality: AudioQuality::Medium,
            overwrite: false,
        },
        cancellation.as_ref(),
        cancellation.clone(),
    );
    assert!(matches!(result, Err(MediaError::Cancelled)));
    assert!(!cancelled_output.exists());
    assert_eq!(
        std::fs::metadata(&source)
            .expect("representative source must remain readable")
            .len(),
        original_size
    );
    assert_eq!(
        std::fs::read_dir(workspace.path())
            .expect("test workspace must remain readable")
            .filter_map(Result::ok)
            .filter(|entry| entry.file_name().to_string_lossy().contains(".part."))
            .count(),
        0
    );
}

fn generate_fixture(path: &Path) {
    let status = Command::new("ffmpeg")
        .args([
            "-hide_banner",
            "-loglevel",
            "error",
            "-f",
            "lavfi",
            "-i",
            "testsrc=size=320x180:rate=24",
            "-f",
            "lavfi",
            "-i",
            "sine=frequency=1000:sample_rate=48000",
            "-t",
            "2",
            "-c:v",
            "mpeg4",
            "-q:v",
            "5",
            "-c:a",
            "aac",
            "-shortest",
            "-y",
        ])
        .arg(path)
        .status()
        .expect("developer FFmpeg CLI must be installed");
    assert!(status.success(), "synthetic fixture generation failed");
}
