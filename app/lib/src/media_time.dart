final RegExp _mediaTimePattern = RegExp(
  r'^(\d{2,}):([0-5]\d):([0-5]\d)(?:\.(\d{3}))?$',
);

/// Formats non-negative media time as `HH:MM:SS` with optional precision.
String formatMediaTime(int milliseconds, {bool includeMilliseconds = false}) {
  final bounded = milliseconds < 0 ? 0 : milliseconds;
  final hours = bounded ~/ 3600000;
  final minutes = (bounded ~/ 60000) % 60;
  final seconds = (bounded ~/ 1000) % 60;
  final base =
      '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
  if (!includeMilliseconds) {
    return base;
  }
  final millis = bounded % 1000;
  return '$base.${millis.toString().padLeft(3, '0')}';
}

/// Parses `HH:MM:SS` or `HH:MM:SS.mmm` into integer milliseconds.
///
/// Returns `null` when the shape is invalid or a minute/second component falls
/// outside its clock range.
int? parseMediaTime(String value) {
  final match = _mediaTimePattern.firstMatch(value.trim());
  if (match == null) {
    return null;
  }
  final hours = int.tryParse(match.group(1)!);
  final minutes = int.tryParse(match.group(2)!);
  final seconds = int.tryParse(match.group(3)!);
  if (hours == null || minutes == null || seconds == null) {
    return null;
  }
  const maxMilliseconds = 0x7FFFFFFFFFFFFFFF;
  if (hours > maxMilliseconds ~/ 3600000) {
    return null;
  }
  final milliseconds = int.tryParse(match.group(4) ?? '0') ?? 0;
  final total =
      hours * 3600000 + minutes * 60000 + seconds * 1000 + milliseconds;
  return total <= maxMilliseconds ? total : null;
}
