/** Formats integer milliseconds as `HH:MM:SS` or an editable millisecond value. */
export function formatTime(milliseconds: number, includeMilliseconds = false): string {
  const bounded = Math.max(0, Math.round(milliseconds));
  const hours = Math.floor(bounded / 3_600_000);
  const minutes = Math.floor((bounded % 3_600_000) / 60_000);
  const seconds = Math.floor((bounded % 60_000) / 1_000);
  const base = [hours, minutes, seconds].map((value) => String(value).padStart(2, "0")).join(":");
  if (!includeMilliseconds) {
    return base;
  }
  return `${base}.${String(bounded % 1_000).padStart(3, "0")}`;
}

/** Parses `HH:MM:SS[.mmm]` into integer milliseconds. */
export function parseTime(value: string): number | undefined {
  const match = /^(\d+):([0-5]\d):([0-5]\d)(?:\.(\d{1,3}))?$/.exec(value.trim());
  if (match === null) {
    return undefined;
  }
  const [, hoursText, minutesText, secondsText, fractionText = ""] = match;
  const hours = Number(hoursText);
  const minutes = Number(minutesText);
  const seconds = Number(secondsText);
  const milliseconds = Number(fractionText.padEnd(3, "0"));
  return hours * 3_600_000 + minutes * 60_000 + seconds * 1_000 + milliseconds;
}
