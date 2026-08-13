import QtTest
import "../lib/source.js" as Source

TestCase {
    name: "Source"

    function test_normalizes_local_file_urls() {
        compare(Source.localPath("file:///Users/media/My%20Clip.mov"), "/Users/media/My Clip.mov");
        compare(Source.localPath("file://localhost/Users/media/clip.mp4"), "/Users/media/clip.mp4");
    }

    function test_rejects_empty_and_non_local_drops() {
        compare(Source.firstDroppedPath([]), "");
        compare(Source.firstDroppedPath(["https://example.com/clip.mp4"]), "");
        compare(Source.firstDroppedPath(["file://server/share/clip.mp4"]), "");
    }

    function test_uses_first_local_drop() {
        compare(Source.firstDroppedPath(["file:///tmp/replacement.mov", "file:///tmp/ignored.mov"]), "/tmp/replacement.mov");
    }
}
