import type { JobState, OutputMode } from "./ipc";

/** Derives the default destination next to a selected source file. */
export function outputPathForMode(path: string, mode: OutputMode): string {
  const separator = Math.max(path.lastIndexOf("/"), path.lastIndexOf("\\"));
  const dot = path.lastIndexOf(".");
  const stemEnd = dot > separator ? dot : path.length;
  return `${path.slice(0, stemEnd)}.${mode === "audioOnly" ? "mp3" : "mp4"}`;
}

/** Reports whether controls that mutate the active source must be locked. */
export function isActiveJob(state: JobState): boolean {
  return state === "preparing" || state === "running";
}
