use std::path::Path;
use std::process::Command;
use std::sync::Mutex;

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

    for (mode, extension) in [
        (OutputMode::VideoWithAudio, "full.mp4"),
        (OutputMode::VideoOnly, "video.mp4"),
        (OutputMode::AudioOnly, "audio.mp3"),
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
                    audio_quality: AudioQuality::Medium,
                    overwrite: false,
                },
                &progress,
                &NeverCancelled,
            )
            .unwrap_or_else(|error| panic!("{mode:?} transcode failed: {error}"));
        let output_info = backend.probe(&output).expect("output must be probed");
        assert!(output_info.duration_ms > 500);
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
        &AlwaysCancelled,
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
