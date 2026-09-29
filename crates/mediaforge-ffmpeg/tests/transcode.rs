//! End-to-end tests for the `FFmpeg` adapter's public transcode contract.

use std::path::Path;
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

use mediaforge_core::{
    AudioQuality, Cancellation, MediaBackend, MediaError, OutputMode, PlaybackRate,
    ProgressObserver, ProgressUpdate, TranscodeRequest, TrimRange, VideoQuality,
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
                    video_quality: VideoQuality::Balanced,
                    audio_quality: quality,
                    video_playback_rate: PlaybackRate::default(),
                    audio_playback_rate: PlaybackRate::default(),
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
            video_quality: VideoQuality::Balanced,
            audio_quality: AudioQuality::Medium,
            video_playback_rate: PlaybackRate::default(),
            audio_playback_rate: PlaybackRate::default(),
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
#[ignore = "requires the developer-only FFmpeg CLI and macOS VideoToolbox"]
fn playback_rates_change_duration_and_preserve_the_longer_stream() {
    let workspace = tempfile::tempdir().expect("test workspace must be created");
    let source = workspace.path().join("source.mp4");
    generate_fixture(&source);
    let backend = FfmpegBackend::new().expect("FFmpeg must initialize");
    let source_info = backend.probe(&source).expect("fixture must be probed");
    let trim = TrimRange::new(250, 1_250, source_info.duration_ms)
        .expect("fixture must contain the test selection");

    for (name, mode, video_rate, audio_rate, expected_duration) in [
        (
            "synchronized-fast.mp4",
            OutputMode::VideoWithAudio,
            200,
            200,
            350..=750,
        ),
        (
            "synchronized-slow.mp4",
            OutputMode::VideoWithAudio,
            50,
            50,
            1_700..=2_300,
        ),
        (
            "independent.mp4",
            OutputMode::VideoWithAudio,
            200,
            50,
            1_700..=2_300,
        ),
        ("video-fast.mp4", OutputMode::VideoOnly, 400, 100, 150..=450),
        (
            "audio-slow.mp3",
            OutputMode::AudioOnly,
            100,
            25,
            3_500..=4_500,
        ),
    ] {
        let output = workspace.path().join(name);
        let progress = RecordedProgress::default();
        backend
            .transcode(
                &TranscodeRequest {
                    input_path: source.clone(),
                    output_path: output.clone(),
                    mode,
                    trim,
                    video_quality: VideoQuality::Balanced,
                    audio_quality: AudioQuality::Medium,
                    video_playback_rate: PlaybackRate::new(video_rate)
                        .expect("test video rate must be valid"),
                    audio_playback_rate: PlaybackRate::new(audio_rate)
                        .expect("test audio rate must be valid"),
                    overwrite: false,
                },
                &progress,
                Arc::new(NeverCancelled),
            )
            .unwrap_or_else(|error| panic!("{name} transcode failed: {error}"));
        let output_info = backend.probe(&output).expect("output must be probed");
        assert!(
            expected_duration.contains(&output_info.duration_ms),
            "{name} duration {} was outside {expected_duration:?}",
            output_info.duration_ms
        );
        assert_eq!(output_info.video.is_some(), mode != OutputMode::AudioOnly);
        assert_eq!(output_info.audio.is_some(), mode != OutputMode::VideoOnly);
        assert!(progress
            .samples
            .lock()
            .expect("progress lock must remain healthy")
            .last()
            .is_some_and(|sample| (sample.percent() - 100.0).abs() < f64::EPSILON));
    }
}

#[test]
#[ignore = "requires the developer-only FFmpeg CLI and macOS VideoToolbox"]
fn video_quality_outputs_have_monotonic_sizes() {
    let workspace = tempfile::tempdir().expect("test workspace must be created");
    let source = workspace.path().join("quality-source.avi");
    generate_quality_fixture(&source);
    let backend = FfmpegBackend::new().expect("FFmpeg must initialize");
    let source_info = backend
        .probe(&source)
        .expect("quality fixture must be probed");
    let trim = TrimRange::new(0, source_info.duration_ms, source_info.duration_ms)
        .expect("quality fixture must have a duration");
    let sizes = [
        VideoQuality::Smaller,
        VideoQuality::Balanced,
        VideoQuality::High,
    ]
    .map(|video_quality| {
        let output = workspace
            .path()
            .join(format!("quality-{video_quality:?}.mp4"));
        backend
            .transcode(
                &TranscodeRequest {
                    input_path: source.clone(),
                    output_path: output.clone(),
                    mode: OutputMode::VideoOnly,
                    trim,
                    video_quality,
                    audio_quality: AudioQuality::Medium,
                    video_playback_rate: PlaybackRate::default(),
                    audio_playback_rate: PlaybackRate::default(),
                    overwrite: false,
                },
                &RecordedProgress::default(),
                Arc::new(NeverCancelled),
            )
            .unwrap_or_else(|error| panic!("{video_quality:?} transcode failed: {error}"));
        std::fs::metadata(output)
            .expect("quality output must be readable")
            .len()
    });

    assert!(sizes[0] < sizes[1], "sizes were not monotonic: {sizes:?}");
    assert!(sizes[1] < sizes[2], "sizes were not monotonic: {sizes:?}");
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
                    video_quality: VideoQuality::Balanced,
                    audio_quality: quality,
                    video_playback_rate: PlaybackRate::default(),
                    audio_playback_rate: PlaybackRate::default(),
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
            video_quality: VideoQuality::Balanced,
            audio_quality: AudioQuality::Medium,
            video_playback_rate: PlaybackRate::default(),
            audio_playback_rate: PlaybackRate::default(),
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

#[test]
#[ignore = "requires MEDIAFORGE_QUALITY_REFERENCE and macOS VideoToolbox"]
fn validates_balanced_quality_reference_size_and_bitrate() {
    let Some(source) =
        std::env::var_os("MEDIAFORGE_QUALITY_REFERENCE").map(std::path::PathBuf::from)
    else {
        eprintln!("MEDIAFORGE_QUALITY_REFERENCE is unset; quality calibration gate skipped");
        return;
    };
    let original_size = std::fs::metadata(&source)
        .expect("quality reference must be readable")
        .len();
    let backend = FfmpegBackend::new().expect("FFmpeg must initialize");
    let source_info = backend
        .probe(&source)
        .expect("quality reference must be probed");
    let trim = TrimRange::new(0, source_info.duration_ms, source_info.duration_ms)
        .expect("quality reference must have a duration");
    let workspace = tempfile::tempdir().expect("test workspace must be created");
    let output = workspace.path().join("balanced-reference.mp4");

    backend
        .transcode(
            &TranscodeRequest {
                input_path: source.clone(),
                output_path: output.clone(),
                mode: OutputMode::VideoWithAudio,
                trim,
                video_quality: VideoQuality::Balanced,
                audio_quality: AudioQuality::Medium,
                video_playback_rate: PlaybackRate::default(),
                audio_playback_rate: PlaybackRate::default(),
                overwrite: false,
            },
            &RecordedProgress::default(),
            Arc::new(NeverCancelled),
        )
        .expect("balanced quality reference transcode must succeed");

    let output_size = std::fs::metadata(&output)
        .expect("quality reference output must be readable")
        .len();
    let output_info = backend
        .probe(&output)
        .expect("quality reference output must be probed");
    let video_bitrate = output_info
        .video
        .as_ref()
        .and_then(|video| video.bitrate)
        .expect("quality reference output must report video bitrate");
    assert!(
        (35_000_000..=45_000_000).contains(&output_size),
        "balanced output size {output_size} was outside 35-45 MB; metadata: {output_info:?}"
    );
    assert!(
        (1_800_000..=2_200_000).contains(&video_bitrate),
        "balanced video bitrate {video_bitrate} was outside 1.8-2.2 Mbps"
    );
    assert!(output_info.video.is_some());
    assert!(output_info.audio.is_some());
    assert!(
        output_info.duration_ms.abs_diff(source_info.duration_ms) <= 1_000,
        "balanced output duration {} differed from source duration {}",
        output_info.duration_ms,
        source_info.duration_ms
    );
    assert_eq!(
        std::fs::metadata(source)
            .expect("quality reference must remain readable")
            .len(),
        original_size
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

fn generate_quality_fixture(path: &Path) {
    let status = Command::new("ffmpeg")
        .args([
            "-hide_banner",
            "-loglevel",
            "error",
            "-f",
            "lavfi",
            "-i",
            "testsrc2=size=640x360:rate=30",
            "-t",
            "3",
            "-c:v",
            "rawvideo",
            "-pix_fmt",
            "yuv420p",
            "-y",
        ])
        .arg(path)
        .status()
        .expect("developer FFmpeg CLI must be installed");
    assert!(status.success(), "quality fixture generation failed");
}
