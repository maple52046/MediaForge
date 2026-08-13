import QtQuick
import QtTest
import "../lib/time.js" as Time

TestCase {
    name: "Time"

    function test_formats_integer_milliseconds() {
        compare(Time.formatTime(3723004, false), "01:02:03");
        compare(Time.formatTime(3723004, true), "01:02:03.004");
    }

    function test_parses_supported_contract() {
        compare(Time.parseTime("01:02:03.4"), 3723400);
        compare(Time.parseTime("00:60:00"), null);
        compare(Time.parseTime("01:02"), null);
    }

    function test_bounds_timeline_range() {
        const range = Time.boundedRange(-5, 1200, 1000);
        compare(range.startMs, 0);
        compare(range.endMs, 1000);
        const reversed = Time.boundedRange(900, 100, 1000);
        compare(reversed.startMs, 900);
        compare(reversed.endMs, 901);
    }
}
