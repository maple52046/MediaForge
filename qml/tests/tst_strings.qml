import QtQuick
import QtTest
import "../lib/strings.js" as Strings

TestCase {
    name: "Strings"

    function test_resolves_explicit_and_system_language() {
        compare(Strings.resolveLanguage("en", "zh-TW"), "en");
        compare(Strings.resolveLanguage("system", "zh-Hant"), "zh-TW");
        compare(Strings.resolveLanguage("system", "fr-FR"), "en");
    }

    function test_unknown_keys_have_stable_fallback() {
        compare(Strings.text("convert", "zh-TW"), "開始轉檔");
        compare(Strings.text("missingKey", "zh-TW"), "missingKey");
    }
}
