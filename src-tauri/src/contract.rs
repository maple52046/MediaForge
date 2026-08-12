use mediaforge_core::{
    AudioStreamInfo, BackendCapabilities, MediaError, MediaInfo, OutputMode, VideoStreamInfo,
};
use serde::Serialize;

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct BackendCapabilitiesDto {
    contract_version: u8,
    ffmpeg_version: String,
    h264_videotoolbox: bool,
    aac: bool,
    libmp3lame: bool,
}

impl From<BackendCapabilities> for BackendCapabilitiesDto {
    fn from(value: BackendCapabilities) -> Self {
        Self {
            contract_version: 1,
            ffmpeg_version: value.ffmpeg_version,
            h264_videotoolbox: value.h264_videotoolbox,
            aac: value.aac,
            libmp3lame: value.libmp3lame,
        }
    }
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct MediaInfoDto {
    contract_version: u8,
    path: String,
    file_name: String,
    file_size_bytes: u64,
    duration_ms: u64,
    format: String,
    video: Option<VideoStreamInfoDto>,
    audio: Option<AudioStreamInfoDto>,
    available_output_modes: Vec<OutputModeDto>,
}

impl From<MediaInfo> for MediaInfoDto {
    fn from(value: MediaInfo) -> Self {
        let available_output_modes = value
            .available_output_modes()
            .into_iter()
            .map(OutputModeDto::from)
            .collect();
        Self {
            contract_version: 1,
            path: value.path.to_string_lossy().into_owned(),
            file_name: value.file_name,
            file_size_bytes: value.file_size_bytes,
            duration_ms: value.duration_ms,
            format: value.format,
            video: value.video.map(VideoStreamInfoDto::from),
            audio: value.audio.map(AudioStreamInfoDto::from),
            available_output_modes,
        }
    }
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct VideoStreamInfoDto {
    codec: String,
    width: u32,
    height: u32,
    frame_rate: Option<f64>,
    bitrate: Option<u64>,
    pixel_format: Option<String>,
}

impl From<VideoStreamInfo> for VideoStreamInfoDto {
    fn from(value: VideoStreamInfo) -> Self {
        Self {
            codec: value.codec,
            width: value.width,
            height: value.height,
            frame_rate: value.frame_rate,
            bitrate: value.bitrate,
            pixel_format: value.pixel_format,
        }
    }
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct AudioStreamInfoDto {
    codec: String,
    sample_rate: Option<u32>,
    channels: Option<u16>,
    bitrate: Option<u64>,
}

impl From<AudioStreamInfo> for AudioStreamInfoDto {
    fn from(value: AudioStreamInfo) -> Self {
        Self {
            codec: value.codec,
            sample_rate: value.sample_rate,
            channels: value.channels,
            bitrate: value.bitrate,
        }
    }
}

#[derive(Clone, Copy, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) enum OutputModeDto {
    VideoWithAudio,
    VideoOnly,
    AudioOnly,
}

impl From<OutputMode> for OutputModeDto {
    fn from(value: OutputMode) -> Self {
        match value {
            OutputMode::VideoWithAudio => Self::VideoWithAudio,
            OutputMode::VideoOnly => Self::VideoOnly,
            OutputMode::AudioOnly => Self::AudioOnly,
        }
    }
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct ApiErrorDto {
    pub(crate) code: &'static str,
    pub(crate) message: String,
}

impl ApiErrorDto {
    pub(crate) fn unexpected(message: String) -> Self {
        Self {
            code: "unexpected",
            message,
        }
    }
}

impl From<MediaError> for ApiErrorDto {
    fn from(value: MediaError) -> Self {
        let code = match value {
            MediaError::UnsupportedInput(_) => "unsupportedInput",
            MediaError::CannotOpenInput(_) => "cannotOpenInput",
            MediaError::DecodeFailed(_) => "decodeFailed",
            MediaError::EncoderUnavailable(_) => "encoderUnavailable",
            MediaError::InvalidTrimRange { .. } => "invalidTrimRange",
            MediaError::OutputExists(_) => "outputExists",
            MediaError::OutputCreateFailed(_) => "outputCreateFailed",
            MediaError::DiskWriteFailed(_) => "diskWriteFailed",
            MediaError::JobActive => "jobActive",
            MediaError::JobNotFound => "jobNotFound",
            MediaError::Cancelled => "cancelled",
            MediaError::Unexpected(_) => "unexpected",
        };
        Self {
            code,
            message: value.to_string(),
        }
    }
}

impl From<std::sync::PoisonError<std::sync::MutexGuard<'_, Option<crate::jobs::JobRecord>>>>
    for ApiErrorDto
{
    fn from(
        value: std::sync::PoisonError<std::sync::MutexGuard<'_, Option<crate::jobs::JobRecord>>>,
    ) -> Self {
        Self::unexpected(value.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn capability_contract_uses_version_one_and_camel_case() {
        let dto = BackendCapabilitiesDto::from(BackendCapabilities {
            ffmpeg_version: "8.1.1".to_owned(),
            h264_videotoolbox: true,
            aac: true,
            libmp3lame: true,
        });
        let json = serde_json::to_value(dto).expect("test DTO must serialize");
        assert_eq!(json["contractVersion"], 1);
        assert_eq!(json["h264Videotoolbox"], true);
    }

    #[test]
    fn media_contract_snapshot_matches_typescript_shape() {
        let dto = MediaInfoDto::from(MediaInfo {
            path: "/media/movie.mov".into(),
            file_name: "movie.mov".to_owned(),
            file_size_bytes: 42,
            duration_ms: 1_500,
            format: "mov,mp4".to_owned(),
            video: Some(VideoStreamInfo {
                codec: "h264".to_owned(),
                width: 1_920,
                height: 1_080,
                frame_rate: Some(30.0),
                bitrate: Some(4_000_000),
                pixel_format: Some("yuv420p".to_owned()),
            }),
            audio: Some(AudioStreamInfo {
                codec: "aac".to_owned(),
                sample_rate: Some(48_000),
                channels: Some(2),
                bitrate: Some(160_000),
            }),
        });

        assert_eq!(
            serde_json::to_value(dto).expect("test DTO must serialize"),
            serde_json::json!({
                "contractVersion": 1,
                "path": "/media/movie.mov",
                "fileName": "movie.mov",
                "fileSizeBytes": 42,
                "durationMs": 1_500,
                "format": "mov,mp4",
                "video": {
                    "codec": "h264",
                    "width": 1_920,
                    "height": 1_080,
                    "frameRate": 30.0,
                    "bitrate": 4_000_000,
                    "pixelFormat": "yuv420p"
                },
                "audio": {
                    "codec": "aac",
                    "sampleRate": 48_000,
                    "channels": 2,
                    "bitrate": 160_000
                },
                "availableOutputModes": ["videoWithAudio", "videoOnly", "audioOnly"]
            })
        );
    }
}
