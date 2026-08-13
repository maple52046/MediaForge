.pragma library

function formatTime(milliseconds, includeMilliseconds) {
    const bounded = Math.max(0, Math.round(Number(milliseconds)));
    const hours = Math.floor(bounded / 3600000);
    const minutes = Math.floor((bounded % 3600000) / 60000);
    const seconds = Math.floor((bounded % 60000) / 1000);
    const base = [hours, minutes, seconds].map(value => String(value).padStart(2, "0")).join(":");
    if (!includeMilliseconds)
        return base;
    return base + "." + String(bounded % 1000).padStart(3, "0");
}

function parseTime(value) {
    const match = /^(\d+):([0-5]\d):([0-5]\d)(?:\.(\d{1,3}))?$/.exec(String(value).trim());
    if (match === null)
        return null;
    const fraction = (match[4] || "").padEnd(3, "0");
    return Number(match[1]) * 3600000 + Number(match[2]) * 60000 + Number(match[3]) * 1000 + Number(fraction);
}

function boundedRange(startMs, endMs, durationMs) {
    const duration = Math.max(1, Math.round(Number(durationMs)));
    const start = Math.max(0, Math.min(Math.round(Number(startMs)), duration - 1));
    const end = Math.max(start + 1, Math.min(Math.round(Number(endMs)), duration));
    return {
        "startMs": start,
        "endMs": end
    };
}
