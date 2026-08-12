import { convertFileSrc, invoke } from "@tauri-apps/api/core";
import { listen, type UnlistenFn } from "@tauri-apps/api/event";

/** Output recipes shared by the version-one desktop contract. */
export type OutputMode = "videoWithAudio" | "videoOnly" | "audioOnly";

/** MP3 quality selections shared by the version-one desktop contract. */
export type AudioQuality = "high" | "medium" | "low";

/** Video metadata returned for the selected primary stream. */
export interface VideoStreamInfo {
  readonly codec: string;
  readonly width: number;
  readonly height: number;
  readonly frameRate?: number;
  readonly bitrate?: number;
  readonly pixelFormat?: string;
}

/** Audio metadata returned for the selected primary stream. */
export interface AudioStreamInfo {
  readonly codec: string;
  readonly sampleRate?: number;
  readonly channels?: number;
  readonly bitrate?: number;
}

/** Probed metadata for one selected local file. */
export interface MediaInfo {
  readonly contractVersion: 1;
  readonly path: string;
  readonly fileName: string;
  readonly fileSizeBytes: number;
  readonly durationMs: number;
  readonly format: string;
  readonly video?: VideoStreamInfo;
  readonly audio?: AudioStreamInfo;
  readonly availableOutputModes: readonly OutputMode[];
}

/** Codec availability returned by the FFmpeg adapter. */
export interface BackendCapabilities {
  readonly contractVersion: 1;
  readonly ffmpegVersion: string;
  readonly h264Videotoolbox: boolean;
  readonly aac: boolean;
  readonly libmp3lame: boolean;
}

/** A validated time selection sent to Rust. */
export interface TrimRange {
  readonly startMs: number;
  readonly endMs: number;
}

/** Starts one asynchronous transcode job. */
export interface StartTranscodeRequest {
  readonly inputPath: string;
  readonly outputPath: string;
  readonly mode: OutputMode;
  readonly trim: TrimRange;
  readonly audioQuality?: AudioQuality;
  readonly overwrite: boolean;
}

/** Immediate acknowledgement returned after a job is accepted. */
export interface JobSnapshot {
  readonly jobId: string;
  readonly state: JobState;
  readonly inputPath: string;
  readonly outputPath: string;
}

/** User-visible lifecycle states mirrored from Rust. */
export type JobState = "idle" | "preparing" | "running" | "completed" | "cancelled" | "failed";

/** Stable API failure returned by a Tauri command. */
export interface ApiError {
  readonly code: string;
  readonly message: string;
}

/** Tagged events emitted throughout one transcode job. */
export type JobEvent =
  | { readonly type: "preparing"; readonly jobId: string }
  | {
      readonly type: "progress";
      readonly jobId: string;
      readonly percent: number;
      readonly processedMs: number;
      readonly totalMs: number;
      readonly framesPerSecond?: number;
      readonly speed?: number;
    }
  | { readonly type: "completed"; readonly jobId: string; readonly outputPath: string }
  | { readonly type: "cancelled"; readonly jobId: string }
  | { readonly type: "failed"; readonly jobId: string; readonly error: ApiError };

/** Returns the local asset-protocol URL for a probed source. */
export function previewUrl(path: string): string {
  return convertFileSrc(path);
}

/** Requests backend codec capabilities. */
export async function getBackendCapabilities(): Promise<BackendCapabilities> {
  return invoke<BackendCapabilities>("get_backend_capabilities");
}

/** Probes and scopes one local source file. */
export async function loadMedia(path: string): Promise<MediaInfo> {
  return invoke<MediaInfo>("load_media", { path });
}

/** Starts one background transcode job. */
export async function startTranscode(request: StartTranscodeRequest): Promise<JobSnapshot> {
  return invoke<JobSnapshot>("start_transcode", { request });
}

/** Requests cancellation of an active transcode job. */
export async function cancelTranscode(jobId: string): Promise<void> {
  await invoke("cancel_transcode", { jobId });
}

/** Subscribes to transcode events and returns an unlisten callback. */
export async function listenToJobEvents(listener: (event: JobEvent) => void): Promise<UnlistenFn> {
  return listen<JobEvent>("transcode-job-event", (event) => {
    listener(event.payload);
  });
}

/** Narrows an unknown Tauri rejection to a stable API error. */
export function toApiError(value: unknown): ApiError {
  if (
    typeof value === "object" &&
    value !== null &&
    "code" in value &&
    "message" in value &&
    typeof value.code === "string" &&
    typeof value.message === "string"
  ) {
    return { code: value.code, message: value.message };
  }
  return {
    code: "unexpected",
    message: value instanceof Error ? value.message : String(value),
  };
}
