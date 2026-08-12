//! `FFmpeg` implementation of the `MediaForge` media backend.

use std::fs;
use std::path::Path;

use ffmpeg_next as ffmpeg;
use mediaforge_core::{
    AudioStreamInfo, BackendCapabilities, Cancellation, MediaBackend, MediaError, MediaInfo,
    ProgressObserver, TranscodeRequest, VideoStreamInfo,
};

/// Direct FFmpeg-library media backend.
#[derive(Debug, Default)]
pub struct FfmpegBackend;

impl FfmpegBackend {
    /// Initializes `FFmpeg` and creates a backend.
    ///
    /// # Errors
    ///
    /// Returns [`MediaError::Unexpected`] when `FFmpeg` initialization fails.
    pub fn new() -> Result<Self, MediaError> {
        ffmpeg::init().map_err(|error| MediaError::Unexpected(error.to_string()))?;
        Ok(Self)
    }
}

impl MediaBackend for FfmpegBackend {
    fn capabilities(&self) -> BackendCapabilities {
        let version = ffmpeg::format::version();
        BackendCapabilities {
            ffmpeg_version: format!(
                "{}.{}.{}",
                version >> 16,
                (version >> 8) & 0xff,
                version & 0xff
            ),
            h264_videotoolbox: ffmpeg::encoder::find_by_name("h264_videotoolbox").is_some(),
            aac: ffmpeg::encoder::find_by_name("aac").is_some(),
            libmp3lame: ffmpeg::encoder::find_by_name("libmp3lame").is_some(),
        }
    }

    fn probe(&self, path: &Path) -> Result<MediaInfo, MediaError> {
        let metadata =
            fs::metadata(path).map_err(|error| MediaError::CannotOpenInput(error.to_string()))?;
        if !metadata.is_file() {
            return Err(MediaError::CannotOpenInput(
                "the selected path is not a regular file".to_owned(),
            ));
        }

        let input = ffmpeg::format::input(path)
            .map_err(|error| MediaError::CannotOpenInput(error.to_string()))?;
        let duration_ms = timestamp_to_milliseconds(input.duration()).max(
            input
                .streams()
                .filter_map(|stream| stream_duration_milliseconds(&stream))
                .max()
                .unwrap_or_default(),
        );
        let video = input
            .streams()
            .best(ffmpeg::media::Type::Video)
            .map(|stream| probe_video_stream(&stream))
            .transpose()?;
        let audio = input
            .streams()
            .best(ffmpeg::media::Type::Audio)
            .map(|stream| probe_audio_stream(&stream))
            .transpose()?;

        if video.is_none() && audio.is_none() {
            return Err(MediaError::UnsupportedInput(
                "no primary audio or video stream was found".to_owned(),
            ));
        }

        let file_name = path
            .file_name()
            .and_then(|name| name.to_str())
            .unwrap_or("media")
            .to_owned();

        Ok(MediaInfo {
            path: path.to_path_buf(),
            file_name,
            file_size_bytes: metadata.len(),
            duration_ms,
            format: input.format().name().to_owned(),
            video,
            audio,
        })
    }

    fn transcode(
        &self,
        request: &TranscodeRequest,
        observer: &dyn ProgressObserver,
        cancellation: &dyn Cancellation,
    ) -> Result<(), MediaError> {
        transcode::run(request, observer, cancellation)
    }
}

fn probe_video_stream(stream: &ffmpeg::Stream<'_>) -> Result<VideoStreamInfo, MediaError> {
    let parameters = stream.parameters();
    let codec = parameters.id().name().to_owned();
    let decoder = ffmpeg::codec::context::Context::from_parameters(parameters)
        .and_then(|context| context.decoder().video())
        .map_err(|error| MediaError::DecodeFailed(error.to_string()))?;
    let frame_rate = rational_to_positive_f64(stream.avg_frame_rate());

    Ok(VideoStreamInfo {
        codec,
        width: decoder.width(),
        height: decoder.height(),
        frame_rate,
        bitrate: positive_i64_to_u64(decoder.bit_rate()),
        pixel_format: Some(decoder.format().descriptor().map_or_else(
            || "unknown".to_owned(),
            |descriptor| descriptor.name().to_owned(),
        )),
    })
}

fn probe_audio_stream(stream: &ffmpeg::Stream<'_>) -> Result<AudioStreamInfo, MediaError> {
    let parameters = stream.parameters();
    let codec = parameters.id().name().to_owned();
    let decoder = ffmpeg::codec::context::Context::from_parameters(parameters)
        .and_then(|context| context.decoder().audio())
        .map_err(|error| MediaError::DecodeFailed(error.to_string()))?;

    Ok(AudioStreamInfo {
        codec,
        sample_rate: (decoder.rate() > 0).then_some(decoder.rate()),
        channels: (decoder.channels() > 0).then_some(decoder.channels()),
        bitrate: positive_i64_to_u64(decoder.bit_rate()),
    })
}

fn timestamp_to_milliseconds(timestamp: i64) -> u64 {
    if timestamp <= 0 {
        return 0;
    }
    u64::try_from(timestamp / (i64::from(ffmpeg::ffi::AV_TIME_BASE) / 1_000)).unwrap_or_default()
}

fn stream_duration_milliseconds(stream: &ffmpeg::Stream<'_>) -> Option<u64> {
    let duration = stream.duration();
    let time_base = stream.time_base();
    if duration <= 0 || time_base.numerator() <= 0 || time_base.denominator() <= 0 {
        return None;
    }

    let milliseconds = i128::from(duration)
        .checked_mul(i128::from(time_base.numerator()))?
        .checked_mul(1_000)?
        .checked_div(i128::from(time_base.denominator()))?;
    u64::try_from(milliseconds).ok().filter(|value| *value > 0)
}

fn rational_to_positive_f64(value: ffmpeg::Rational) -> Option<f64> {
    let denominator = value.denominator();
    if value.numerator() <= 0 || denominator <= 0 {
        None
    } else {
        Some(f64::from(value.numerator()) / f64::from(denominator))
    }
}

fn positive_i64_to_u64(value: usize) -> Option<u64> {
    (value > 0).then(|| u64::try_from(value).unwrap_or(u64::MAX))
}

mod transcode;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn timestamp_conversion_handles_unknown_values() {
        assert_eq!(timestamp_to_milliseconds(-1), 0);
        assert_eq!(timestamp_to_milliseconds(1_500_000), 1_500);
    }
}
