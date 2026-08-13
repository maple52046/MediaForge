use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Instant;

use ffmpeg::{
    codec, encoder, filter, format, frame, media, software, Dictionary, Packet, Rational,
};
use ffmpeg_next as ffmpeg;
use mediaforge_core::{
    balanced_video_bitrate, Cancellation, MediaError, OutputMode, ProgressObserver, ProgressUpdate,
    TranscodeRequest, TrimRange,
};

static TEMPORARY_OUTPUT_SEQUENCE: AtomicU64 = AtomicU64::new(0);

pub(super) fn run(
    request: &TranscodeRequest,
    observer: &dyn ProgressObserver,
    cancellation: Arc<dyn Cancellation>,
) -> Result<(), MediaError> {
    validate_paths(request)?;
    validate_encoders(request.mode)?;
    // Invariant: the destination is never the active mux target, so failure cannot corrupt it.
    let temporary = TemporaryOutput::new(&request.output_path)?;
    let result = transcode_to(request, temporary.path(), observer, cancellation);
    match result {
        Ok(()) => temporary.commit(&request.output_path, request.overwrite),
        Err(error) => Err(error),
    }
}

#[allow(
    clippy::too_many_lines,
    reason = "the packet-loop setup and teardown form one transactional media operation"
)]
fn transcode_to(
    request: &TranscodeRequest,
    temporary_path: &Path,
    observer: &dyn ProgressObserver,
    cancellation: Arc<dyn Cancellation>,
) -> Result<(), MediaError> {
    // Contract: FFmpeg I/O interruption maps cancellation to a stable domain error.
    let operation_cancellation = Arc::clone(&cancellation);
    let mut input =
        format::input_with_interrupt(&request.input_path, move || cancellation.is_cancelled())
            .map_err(|error| {
                if operation_cancellation.is_cancelled() {
                    MediaError::Cancelled
                } else {
                    MediaError::CannotOpenInput(error.to_string())
                }
            })?;
    let video_index = input
        .streams()
        .best(media::Type::Video)
        .map(|stream| stream.index());
    let audio_index = input
        .streams()
        .best(media::Type::Audio)
        .map(|stream| stream.index());
    validate_required_streams(request.mode, video_index, audio_index)?;

    let mut output = format::output(temporary_path)
        .map_err(|error| MediaError::OutputCreateFailed(error.to_string()))?;
    let mut video = if matches!(
        request.mode,
        OutputMode::VideoWithAudio | OutputMode::VideoOnly
    ) {
        let index = video_index.ok_or_else(|| {
            MediaError::UnsupportedInput("the selected mode requires a video stream".to_owned())
        })?;
        let stream = input
            .stream(index)
            .ok_or_else(|| MediaError::DecodeFailed("video stream disappeared".to_owned()))?;
        Some(VideoTranscoder::new(&stream, &mut output, request.trim)?)
    } else {
        None
    };
    let mut audio = if matches!(
        request.mode,
        OutputMode::VideoWithAudio | OutputMode::AudioOnly
    ) {
        let index = audio_index.ok_or_else(|| {
            MediaError::UnsupportedInput("the selected mode requires an audio stream".to_owned())
        })?;
        let stream = input
            .stream(index)
            .ok_or_else(|| MediaError::DecodeFailed("audio stream disappeared".to_owned()))?;
        Some(AudioTranscoder::new(
            &stream,
            &mut output,
            request.mode,
            request.audio_quality.bitrate(),
            request.trim,
        )?)
    } else {
        None
    };

    output.set_metadata(input.metadata().to_owned());
    output
        .write_header()
        .map_err(|error| MediaError::OutputCreateFailed(error.to_string()))?;

    let started = Instant::now();
    let seek_timestamp = milliseconds_to_global_timestamp(request.trim.start_ms());
    if seek_timestamp > 0 {
        input
            .seek(seek_timestamp, ..seek_timestamp)
            .map_err(|error| MediaError::DecodeFailed(error.to_string()))?;
    }

    for (stream, packet) in input.packets() {
        if operation_cancellation.is_cancelled() {
            return Err(MediaError::Cancelled);
        }

        let processed_ms = if video
            .as_ref()
            .is_some_and(|transcoder| transcoder.stream_index == stream.index())
        {
            video
                .as_mut()
                .map(|transcoder| {
                    transcoder.process_packet(&packet, &mut output, operation_cancellation.as_ref())
                })
                .transpose()?
                .flatten()
        } else if audio
            .as_ref()
            .is_some_and(|transcoder| transcoder.stream_index == stream.index())
        {
            audio
                .as_mut()
                .map(|transcoder| {
                    transcoder.process_packet(&packet, &mut output, operation_cancellation.as_ref())
                })
                .transpose()?
                .flatten()
        } else {
            None
        };

        if let Some(source_ms) = processed_ms {
            emit_progress(observer, request.trim, source_ms, started);
        }
        if all_streams_done(video.as_ref(), audio.as_ref()) {
            break;
        }
    }

    if operation_cancellation.is_cancelled() {
        return Err(MediaError::Cancelled);
    }
    if let Some(transcoder) = video.as_mut() {
        transcoder.finish(&mut output, operation_cancellation.as_ref())?;
    }
    if let Some(transcoder) = audio.as_mut() {
        transcoder.finish(&mut output, operation_cancellation.as_ref())?;
    }
    output
        .write_trailer()
        .map_err(|error| MediaError::DiskWriteFailed(error.to_string()))?;
    observer.on_progress(ProgressUpdate {
        processed_ms: request.trim.duration_ms(),
        total_ms: request.trim.duration_ms(),
        frames_per_second: None,
        speed: Some(
            milliseconds_to_seconds(request.trim.duration_ms())
                / started.elapsed().as_secs_f64().max(f64::EPSILON),
        ),
    });
    Ok(())
}

fn validate_paths(request: &TranscodeRequest) -> Result<(), MediaError> {
    if request.input_path == request.output_path {
        return Err(MediaError::OutputCreateFailed(
            "input and output paths must differ".to_owned(),
        ));
    }
    if request.output_path.exists() && !request.overwrite {
        return Err(MediaError::OutputExists(request.output_path.clone()));
    }
    let parent = request.output_path.parent().ok_or_else(|| {
        MediaError::OutputCreateFailed("the output has no parent directory".to_owned())
    })?;
    if !parent.is_dir() {
        return Err(MediaError::OutputCreateFailed(format!(
            "output directory does not exist: {}",
            parent.display()
        )));
    }
    Ok(())
}

fn validate_encoders(mode: OutputMode) -> Result<(), MediaError> {
    if matches!(mode, OutputMode::VideoWithAudio | OutputMode::VideoOnly)
        && encoder::find_by_name("h264_videotoolbox").is_none()
    {
        return Err(MediaError::EncoderUnavailable(
            "h264_videotoolbox".to_owned(),
        ));
    }
    let audio_encoder = match mode {
        OutputMode::VideoWithAudio => Some("aac"),
        OutputMode::AudioOnly => Some("libmp3lame"),
        OutputMode::VideoOnly => None,
    };
    if audio_encoder.is_some_and(|name| encoder::find_by_name(name).is_none()) {
        return Err(MediaError::EncoderUnavailable(
            audio_encoder.unwrap_or_default().to_owned(),
        ));
    }
    Ok(())
}

fn validate_required_streams(
    mode: OutputMode,
    video_index: Option<usize>,
    audio_index: Option<usize>,
) -> Result<(), MediaError> {
    let valid = match mode {
        OutputMode::VideoWithAudio => video_index.is_some() && audio_index.is_some(),
        OutputMode::VideoOnly => video_index.is_some(),
        OutputMode::AudioOnly => audio_index.is_some(),
    };
    if valid {
        Ok(())
    } else {
        Err(MediaError::UnsupportedInput(
            "the source is missing a stream required by the selected output mode".to_owned(),
        ))
    }
}

fn all_streams_done(video: Option<&VideoTranscoder>, audio: Option<&AudioTranscoder>) -> bool {
    video.is_none_or(|transcoder| transcoder.done) && audio.is_none_or(|transcoder| transcoder.done)
}

fn emit_progress(
    observer: &dyn ProgressObserver,
    trim: TrimRange,
    source_ms: u64,
    started: Instant,
) {
    let processed_ms = source_ms
        .saturating_sub(trim.start_ms())
        .min(trim.duration_ms());
    let elapsed_seconds = started.elapsed().as_secs_f64();
    observer.on_progress(ProgressUpdate {
        processed_ms,
        total_ms: trim.duration_ms(),
        frames_per_second: None,
        speed: (elapsed_seconds > 0.0)
            .then_some(milliseconds_to_seconds(processed_ms) / elapsed_seconds),
    });
}

struct VideoTranscoder {
    stream_index: usize,
    output_stream_index: usize,
    input_time_base: Rational,
    encoder_time_base: Rational,
    decoder: codec::decoder::Video,
    encoder: codec::encoder::video::Encoder,
    scaler: software::scaling::Context,
    trim: TrimRange,
    next_pts: i64,
    done: bool,
}

impl VideoTranscoder {
    fn new(
        input: &format::stream::Stream<'_>,
        output: &mut format::context::Output,
        trim: TrimRange,
    ) -> Result<Self, MediaError> {
        let mut decoder = codec::context::Context::from_parameters(input.parameters())
            .and_then(|context| context.decoder().video())
            .map_err(|error| MediaError::DecodeFailed(error.to_string()))?;
        decoder.set_time_base(input.time_base());
        let codec = encoder::find_by_name("h264_videotoolbox")
            .ok_or_else(|| MediaError::EncoderUnavailable("h264_videotoolbox".to_owned()))?;
        let frame_rate = valid_frame_rate(input.avg_frame_rate());
        let encoder_time_base = frame_rate.invert();
        let global_header = output
            .format()
            .flags()
            .contains(format::Flags::GLOBAL_HEADER);
        let output_stream_index = output.nb_streams() as usize;
        let mut output_stream = output
            .add_stream(codec)
            .map_err(|error| MediaError::OutputCreateFailed(error.to_string()))?;
        let mut video_encoder = codec::context::Context::new_with_codec(codec)
            .encoder()
            .video()
            .map_err(|error| MediaError::EncoderUnavailable(error.to_string()))?;
        video_encoder.set_width(decoder.width());
        video_encoder.set_height(decoder.height());
        video_encoder.set_aspect_ratio(decoder.aspect_ratio());
        video_encoder.set_format(format::Pixel::YUV420P);
        video_encoder.set_frame_rate(Some(frame_rate));
        video_encoder.set_time_base(encoder_time_base);
        let source_bitrate = u64::try_from(decoder.bit_rate())
            .ok()
            .filter(|bitrate| *bitrate > 0);
        let target_bitrate = usize::try_from(balanced_video_bitrate(
            decoder.width(),
            decoder.height(),
            Some(f64::from(frame_rate)),
            source_bitrate,
        ))
        .map_err(|error| MediaError::EncoderUnavailable(error.to_string()))?;
        video_encoder.set_bit_rate(target_bitrate);
        video_encoder.set_gop(frame_rate.numerator().unsigned_abs().saturating_mul(2));
        if global_header {
            video_encoder.set_flags(codec::Flags::GLOBAL_HEADER);
        }
        let mut options = Dictionary::new();
        // Constraint: permit Apple's VideoToolbox fallback without substituting a GPL encoder.
        options.set("allow_sw", "1");
        options.set("realtime", "1");
        let video_encoder = video_encoder
            .open_as_with(codec, options)
            .map_err(|error| MediaError::EncoderUnavailable(error.to_string()))?;
        output_stream.set_time_base(encoder_time_base);
        output_stream.set_parameters(&video_encoder);
        let scaler = software::scaling::Context::get(
            decoder.format(),
            decoder.width(),
            decoder.height(),
            format::Pixel::YUV420P,
            decoder.width(),
            decoder.height(),
            software::scaling::Flags::BILINEAR,
        )
        .map_err(|error| MediaError::DecodeFailed(error.to_string()))?;

        Ok(Self {
            stream_index: input.index(),
            output_stream_index,
            input_time_base: input.time_base(),
            encoder_time_base,
            decoder,
            encoder: video_encoder,
            scaler,
            trim,
            next_pts: 0,
            done: false,
        })
    }

    fn process_packet(
        &mut self,
        packet: &Packet,
        output: &mut format::context::Output,
        cancellation: &dyn Cancellation,
    ) -> Result<Option<u64>, MediaError> {
        self.decoder
            .send_packet(packet)
            .map_err(|error| MediaError::DecodeFailed(error.to_string()))?;
        self.receive_frames(output, cancellation)
    }

    fn receive_frames(
        &mut self,
        output: &mut format::context::Output,
        cancellation: &dyn Cancellation,
    ) -> Result<Option<u64>, MediaError> {
        let mut decoded = frame::Video::empty();
        let mut latest = None;
        while self.decoder.receive_frame(&mut decoded).is_ok() {
            if cancellation.is_cancelled() {
                return Err(MediaError::Cancelled);
            }
            let source_ms = decoded
                .timestamp()
                .map_or(self.trim.start_ms(), |timestamp| {
                    timestamp_to_milliseconds(timestamp, self.input_time_base)
                });
            latest = Some(source_ms);
            if source_ms < self.trim.start_ms() {
                continue;
            }
            if source_ms >= self.trim.end_ms() {
                self.done = true;
                break;
            }

            let mut scaled = frame::Video::empty();
            self.scaler
                .run(&decoded, &mut scaled)
                .map_err(|error| MediaError::DecodeFailed(error.to_string()))?;
            scaled.set_pts(Some(self.next_pts));
            scaled.set_kind(ffmpeg::picture::Type::None);
            self.next_pts += 1;
            self.encoder
                .send_frame(&scaled)
                .map_err(|error| MediaError::DiskWriteFailed(error.to_string()))?;
            self.write_packets(output)?;
        }
        Ok(latest)
    }

    fn write_packets(&mut self, output: &mut format::context::Output) -> Result<(), MediaError> {
        let output_time_base = output
            .stream(self.output_stream_index)
            .ok_or_else(|| MediaError::DiskWriteFailed("video output stream missing".to_owned()))?
            .time_base();
        let mut encoded = Packet::empty();
        while self.encoder.receive_packet(&mut encoded).is_ok() {
            encoded.set_stream(self.output_stream_index);
            encoded.rescale_ts(self.encoder_time_base, output_time_base);
            encoded.set_position(-1);
            encoded
                .write_interleaved(output)
                .map_err(|error| MediaError::DiskWriteFailed(error.to_string()))?;
        }
        Ok(())
    }

    fn finish(
        &mut self,
        output: &mut format::context::Output,
        cancellation: &dyn Cancellation,
    ) -> Result<(), MediaError> {
        self.decoder
            .send_eof()
            .map_err(|error| MediaError::DecodeFailed(error.to_string()))?;
        self.receive_frames(output, cancellation)?;
        self.encoder
            .send_eof()
            .map_err(|error| MediaError::DiskWriteFailed(error.to_string()))?;
        self.write_packets(output)
    }
}

struct AudioTranscoder {
    stream_index: usize,
    output_stream_index: usize,
    input_time_base: Rational,
    encoder_time_base: Rational,
    decoder: codec::decoder::Audio,
    encoder: codec::encoder::audio::Encoder,
    filter: filter::Graph,
    trim: TrimRange,
    done: bool,
}

impl AudioTranscoder {
    fn new(
        input: &format::stream::Stream<'_>,
        output: &mut format::context::Output,
        mode: OutputMode,
        mp3_bitrate: usize,
        trim: TrimRange,
    ) -> Result<Self, MediaError> {
        let mut decoder = codec::context::Context::from_parameters(input.parameters())
            .and_then(|context| context.decoder().audio())
            .map_err(|error| MediaError::DecodeFailed(error.to_string()))?;
        decoder.set_time_base(input.time_base());
        let encoder_name = match mode {
            OutputMode::AudioOnly => "libmp3lame",
            OutputMode::VideoWithAudio => "aac",
            OutputMode::VideoOnly => {
                return Err(MediaError::Unexpected(
                    "audio transcoder requested for video-only output".to_owned(),
                ));
            }
        };
        let codec = encoder::find_by_name(encoder_name)
            .ok_or_else(|| MediaError::EncoderUnavailable(encoder_name.to_owned()))?;
        let audio_codec = codec
            .audio()
            .map_err(|error| MediaError::EncoderUnavailable(error.to_string()))?;
        let global_header = output
            .format()
            .flags()
            .contains(format::Flags::GLOBAL_HEADER);
        let output_stream_index = output.nb_streams() as usize;
        let mut output_stream = output
            .add_stream(codec)
            .map_err(|error| MediaError::OutputCreateFailed(error.to_string()))?;
        let mut audio_encoder = codec::context::Context::new_with_codec(codec)
            .encoder()
            .audio()
            .map_err(|error| MediaError::EncoderUnavailable(error.to_string()))?;
        let rate = decoder.rate().clamp(8_000, 48_000);
        let channel_layout = if decoder.channels() == 1 {
            ffmpeg::ChannelLayout::MONO
        } else {
            ffmpeg::ChannelLayout::STEREO
        };
        let sample_format = audio_codec
            .formats()
            .and_then(|mut formats| formats.next())
            .ok_or_else(|| {
                MediaError::EncoderUnavailable(format!(
                    "{encoder_name} did not report a supported sample format"
                ))
            })?;
        let encoder_rate = i32::try_from(rate)
            .map_err(|error| MediaError::EncoderUnavailable(error.to_string()))?;
        audio_encoder.set_rate(encoder_rate);
        audio_encoder.set_channel_layout(channel_layout);
        audio_encoder.set_format(sample_format);
        audio_encoder.set_bit_rate(if mode == OutputMode::AudioOnly {
            mp3_bitrate
        } else {
            160_000
        });
        let encoder_time_base = Rational(1, encoder_rate);
        audio_encoder.set_time_base(encoder_time_base);
        if global_header {
            audio_encoder.set_flags(codec::Flags::GLOBAL_HEADER);
        }
        let audio_encoder = audio_encoder
            .open_as(codec)
            .map_err(|error| MediaError::EncoderUnavailable(error.to_string()))?;
        output_stream.set_time_base(encoder_time_base);
        output_stream.set_parameters(&audio_encoder);
        let filter = create_audio_filter(&decoder, &audio_encoder, trim)?;

        Ok(Self {
            stream_index: input.index(),
            output_stream_index,
            input_time_base: input.time_base(),
            encoder_time_base,
            decoder,
            encoder: audio_encoder,
            filter,
            trim,
            done: false,
        })
    }

    fn process_packet(
        &mut self,
        packet: &Packet,
        output: &mut format::context::Output,
        cancellation: &dyn Cancellation,
    ) -> Result<Option<u64>, MediaError> {
        self.decoder
            .send_packet(packet)
            .map_err(|error| MediaError::DecodeFailed(error.to_string()))?;
        self.receive_frames(output, cancellation)
    }

    fn receive_frames(
        &mut self,
        output: &mut format::context::Output,
        cancellation: &dyn Cancellation,
    ) -> Result<Option<u64>, MediaError> {
        let mut decoded = frame::Audio::empty();
        let mut latest = None;
        while self.decoder.receive_frame(&mut decoded).is_ok() {
            if cancellation.is_cancelled() {
                return Err(MediaError::Cancelled);
            }
            let source_ms = decoded
                .timestamp()
                .map_or(self.trim.start_ms(), |timestamp| {
                    timestamp_to_milliseconds(timestamp, self.input_time_base)
                });
            latest = Some(source_ms);
            if source_ms >= self.trim.end_ms() {
                self.done = true;
                break;
            }
            self.filter
                .get("in")
                .ok_or_else(|| MediaError::DecodeFailed("audio filter input missing".to_owned()))?
                .source()
                .add(&decoded)
                .map_err(|error| MediaError::DecodeFailed(error.to_string()))?;
            self.receive_filtered(output, cancellation)?;
        }
        Ok(latest)
    }

    fn receive_filtered(
        &mut self,
        output: &mut format::context::Output,
        cancellation: &dyn Cancellation,
    ) -> Result<(), MediaError> {
        let mut filtered = frame::Audio::empty();
        while self
            .filter
            .get("out")
            .ok_or_else(|| MediaError::DecodeFailed("audio filter output missing".to_owned()))?
            .sink()
            .frame(&mut filtered)
            .is_ok()
        {
            if cancellation.is_cancelled() {
                return Err(MediaError::Cancelled);
            }
            self.encoder
                .send_frame(&filtered)
                .map_err(|error| MediaError::DiskWriteFailed(error.to_string()))?;
            self.write_packets(output)?;
        }
        Ok(())
    }

    fn write_packets(&mut self, output: &mut format::context::Output) -> Result<(), MediaError> {
        let output_time_base = output
            .stream(self.output_stream_index)
            .ok_or_else(|| MediaError::DiskWriteFailed("audio output stream missing".to_owned()))?
            .time_base();
        let mut encoded = Packet::empty();
        while self.encoder.receive_packet(&mut encoded).is_ok() {
            encoded.set_stream(self.output_stream_index);
            encoded.rescale_ts(self.encoder_time_base, output_time_base);
            encoded.set_position(-1);
            encoded
                .write_interleaved(output)
                .map_err(|error| MediaError::DiskWriteFailed(error.to_string()))?;
        }
        Ok(())
    }

    fn finish(
        &mut self,
        output: &mut format::context::Output,
        cancellation: &dyn Cancellation,
    ) -> Result<(), MediaError> {
        self.decoder
            .send_eof()
            .map_err(|error| MediaError::DecodeFailed(error.to_string()))?;
        self.receive_frames(output, cancellation)?;
        self.filter
            .get("in")
            .ok_or_else(|| MediaError::DecodeFailed("audio filter input missing".to_owned()))?
            .source()
            .flush()
            .map_err(|error| MediaError::DecodeFailed(error.to_string()))?;
        self.receive_filtered(output, cancellation)?;
        self.encoder
            .send_eof()
            .map_err(|error| MediaError::DiskWriteFailed(error.to_string()))?;
        self.write_packets(output)
    }
}

fn create_audio_filter(
    decoder: &codec::decoder::Audio,
    encoder: &codec::encoder::audio::Encoder,
    trim: TrimRange,
) -> Result<filter::Graph, MediaError> {
    let mut graph = filter::Graph::new();
    let input_layout = if decoder.channel_layout().is_empty() {
        if decoder.channels() == 1 {
            ffmpeg::ChannelLayout::MONO
        } else {
            ffmpeg::ChannelLayout::STEREO
        }
    } else {
        decoder.channel_layout()
    };
    let args = format!(
        "time_base={}:sample_rate={}:sample_fmt={}:channel_layout=0x{:x}",
        decoder.time_base(),
        decoder.rate(),
        decoder.format().name(),
        input_layout.bits()
    );
    graph
        .add(
            &filter::find("abuffer").ok_or_else(|| {
                MediaError::Unexpected("FFmpeg abuffer filter is unavailable".to_owned())
            })?,
            "in",
            &args,
        )
        .map_err(|error| MediaError::DecodeFailed(error.to_string()))?;
    graph
        .add(
            &filter::find("abuffersink").ok_or_else(|| {
                MediaError::Unexpected("FFmpeg abuffersink filter is unavailable".to_owned())
            })?,
            "out",
            "",
        )
        .map_err(|error| MediaError::DecodeFailed(error.to_string()))?;
    let spec = format!(
        "atrim=start={:.3}:end={:.3},asetpts=PTS-STARTPTS,aresample={},aformat=sample_fmts={}:sample_rates={}:channel_layouts=0x{:x}",
        milliseconds_to_seconds(trim.start_ms()),
        milliseconds_to_seconds(trim.end_ms()),
        encoder.rate(),
        encoder.format().name(),
        encoder.rate(),
        encoder.channel_layout().bits()
    );
    graph
        .output("in", 0)
        .and_then(|output| output.input("out", 0))
        .and_then(|input| input.parse(&spec))
        .and_then(|()| graph.validate())
        .map_err(|error| MediaError::DecodeFailed(error.to_string()))?;
    if encoder.frame_size() > 0 {
        graph
            .get("out")
            .ok_or_else(|| MediaError::DecodeFailed("audio filter output missing".to_owned()))?
            .sink()
            .set_frame_size(encoder.frame_size());
    }
    Ok(graph)
}

fn valid_frame_rate(candidate: Rational) -> Rational {
    if candidate.numerator() > 0 && candidate.denominator() > 0 {
        candidate
    } else {
        Rational(30, 1)
    }
}

fn timestamp_to_milliseconds(timestamp: i64, time_base: Rational) -> u64 {
    if timestamp <= 0 || time_base.numerator() <= 0 || time_base.denominator() <= 0 {
        return 0;
    }
    let milliseconds = i128::from(timestamp)
        .saturating_mul(i128::from(time_base.numerator()))
        .saturating_mul(1_000)
        / i128::from(time_base.denominator());
    u64::try_from(milliseconds).unwrap_or_default()
}

#[allow(
    clippy::cast_precision_loss,
    reason = "media durations are bounded by local file sizes and only displayed as telemetry"
)]
fn milliseconds_to_seconds(milliseconds: u64) -> f64 {
    milliseconds as f64 / 1_000.0
}

fn milliseconds_to_global_timestamp(milliseconds: u64) -> i64 {
    i64::try_from(milliseconds)
        .unwrap_or(i64::MAX)
        .saturating_mul(i64::from(ffmpeg::ffi::AV_TIME_BASE))
        / 1_000
}

struct TemporaryOutput {
    path: PathBuf,
    // Invariant: this flips only after the final rename succeeds.
    committed: bool,
}

impl TemporaryOutput {
    fn new(output_path: &Path) -> Result<Self, MediaError> {
        let parent = output_path.parent().ok_or_else(|| {
            MediaError::OutputCreateFailed("the output has no parent directory".to_owned())
        })?;
        let extension = output_path
            .extension()
            .and_then(|extension| extension.to_str())
            .unwrap_or("media");
        let sequence = TEMPORARY_OUTPUT_SEQUENCE.fetch_add(1, Ordering::Relaxed);
        let path = parent.join(format!(
            ".mediaforge-{}-{sequence}.part.{extension}",
            std::process::id()
        ));
        if path.exists() {
            fs::remove_file(&path)
                .map_err(|error| MediaError::OutputCreateFailed(error.to_string()))?;
        }
        Ok(Self {
            path,
            committed: false,
        })
    }

    fn path(&self) -> &Path {
        &self.path
    }

    fn commit(mut self, output_path: &Path, overwrite: bool) -> Result<(), MediaError> {
        // Risk: repeat the existence check here to close the race after request validation.
        if output_path.exists() && !overwrite {
            return Err(MediaError::OutputExists(output_path.to_path_buf()));
        }
        fs::rename(&self.path, output_path)
            .map_err(|error| MediaError::DiskWriteFailed(error.to_string()))?;
        self.committed = true;
        Ok(())
    }
}

impl Drop for TemporaryOutput {
    fn drop(&mut self) {
        if !self.committed {
            // Operational context: cleanup is best-effort so the original media error stays primary.
            let _ = fs::remove_file(&self.path);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn timestamp_conversion_uses_stream_time_base() {
        assert_eq!(
            timestamp_to_milliseconds(90_000, Rational(1, 90_000)),
            1_000
        );
    }

    #[test]
    fn invalid_frame_rate_uses_thirty_frames_per_second() {
        let frame_rate = valid_frame_rate(Rational(0, 0));
        assert_eq!(frame_rate.numerator(), 30);
        assert_eq!(frame_rate.denominator(), 1);
    }
}
