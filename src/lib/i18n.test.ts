import { beforeEach, describe, expect, it } from "vitest";

import { i18n, loadLanguagePreference, resolveLanguage, setLanguagePreference } from "./i18n";

describe("language preference", () => {
  beforeEach(() => window.localStorage.clear());

  it("uses Traditional Chinese for Chinese system locales and English otherwise", () => {
    expect(resolveLanguage("system", "zh-Hant-TW")).toBe("zh-TW");
    expect(resolveLanguage("system", "ja-JP")).toBe("en");
    expect(resolveLanguage("en", "zh-TW")).toBe("en");
  });

  it("falls back when persisted data is invalid", () => {
    window.localStorage.setItem("mediaforge.language", "unsupported");
    expect(loadLanguagePreference()).toBe("system");
  });

  it("persists and activates an explicit preference", async () => {
    await setLanguagePreference("zh-TW");
    expect(loadLanguagePreference()).toBe("zh-TW");
    expect(i18n.language).toBe("zh-TW");
  });
});
