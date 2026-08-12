import i18n from "i18next";
import { initReactI18next } from "react-i18next";

export type LanguagePreference = "system" | "en" | "zh-TW";

const LANGUAGE_KEY = "mediaforge.language";

const resources = {
  en: {
    translation: {
      app: { subtitle: "Focused media conversion for macOS" },
      actions: {
        browse: "Choose media",
        change: "Change source",
        settings: "Settings",
        convert: "Convert",
        cancel: "Cancel",
        browseOutput: "Browse…",
        reset: "Reset",
        setStart: "Set Start",
        setEnd: "Set End",
        playSelection: "Play Selection",
      },
      drop: {
        title: "Drop a media file here",
        detail: "or choose one from your Mac",
        busy: "Finish or cancel the current conversion before replacing the source.",
      },
      media: {
        source: "Source",
        format: "Format",
        duration: "Duration",
        size: "Size",
        video: "Video",
        audio: "Audio",
        none: "None",
      },
      preview: { unavailable: "Preview is unavailable, but this file can still be converted." },
      timeline: { title: "Selection", start: "Start", end: "End", current: "Current" },
      conversion: {
        title: "Output",
        mode: "Format",
        destination: "Destination",
        quality: "MP3 quality",
        videoWithAudio: "MP4 · H.264 + AAC",
        videoOnly: "MP4 · H.264 video",
        audioOnly: "MP3 audio",
        high: "High · 256 kbps",
        medium: "Medium · 192 kbps",
        low: "Low · 128 kbps",
        preparing: "Preparing…",
        running: "Converting… {{percent}}%",
        completed: "Completed",
        cancelled: "Cancelled",
        failed: "Conversion failed",
      },
      settings: {
        title: "Settings",
        language: "Language",
        system: "System default",
        english: "English",
        traditionalChinese: "繁體中文",
        backend: "Media backend",
        close: "Close",
      },
      errors: {
        unsupportedInput: "No supported audio or video stream was found.",
        cannotOpenInput: "The selected file could not be opened.",
        decodeFailed: "The media stream could not be decoded.",
        encoderUnavailable: "A required encoder is unavailable.",
        invalidTrimRange: "Choose an end time after the start time.",
        outputExists: "The destination already exists.",
        outputCreateFailed: "The destination could not be created.",
        diskWriteFailed: "The output could not be written.",
        jobActive: "Another conversion is already active.",
        jobNotFound: "The conversion is no longer active.",
        cancelled: "The conversion was cancelled.",
        unexpected: "An unexpected media error occurred.",
      },
      overwrite: "The destination already exists. Replace it after conversion succeeds?",
      closeActive: "Cancel the active conversion and close MediaForge?",
    },
  },
  "zh-TW": {
    translation: {
      app: { subtitle: "專注、輕巧的 macOS 媒體轉檔工具" },
      actions: {
        browse: "選擇媒體",
        change: "更換來源",
        settings: "設定",
        convert: "開始轉檔",
        cancel: "取消",
        browseOutput: "瀏覽…",
        reset: "重設",
        setStart: "設為起點",
        setEnd: "設為終點",
        playSelection: "播放選取範圍",
      },
      drop: {
        title: "將媒體檔拖放至此",
        detail: "或從 Mac 選擇檔案",
        busy: "請先完成或取消目前的轉檔，再更換來源。",
      },
      media: {
        source: "來源",
        format: "格式",
        duration: "長度",
        size: "大小",
        video: "影像",
        audio: "音訊",
        none: "無",
      },
      preview: { unavailable: "無法在此預覽，但仍可轉換這個檔案。" },
      timeline: { title: "選取範圍", start: "開始", end: "結束", current: "目前位置" },
      conversion: {
        title: "輸出",
        mode: "格式",
        destination: "目的地",
        quality: "MP3 品質",
        videoWithAudio: "MP4 · H.264 + AAC",
        videoOnly: "MP4 · H.264 影像",
        audioOnly: "MP3 音訊",
        high: "高 · 256 kbps",
        medium: "中 · 192 kbps",
        low: "低 · 128 kbps",
        preparing: "準備中…",
        running: "轉檔中… {{percent}}%",
        completed: "轉檔完成",
        cancelled: "已取消",
        failed: "轉檔失敗",
      },
      settings: {
        title: "設定",
        language: "語言",
        system: "跟隨系統",
        english: "English",
        traditionalChinese: "繁體中文",
        backend: "媒體後端",
        close: "關閉",
      },
      errors: {
        unsupportedInput: "找不到支援的影像或音訊串流。",
        cannotOpenInput: "無法開啟選取的檔案。",
        decodeFailed: "無法解碼媒體串流。",
        encoderUnavailable: "需要的編碼器無法使用。",
        invalidTrimRange: "結束時間必須晚於開始時間。",
        outputExists: "目的檔已存在。",
        outputCreateFailed: "無法建立目的檔。",
        diskWriteFailed: "無法寫入輸出檔案。",
        jobActive: "已有另一個轉檔工作正在執行。",
        jobNotFound: "這個轉檔工作已不在執行中。",
        cancelled: "轉檔已取消。",
        unexpected: "處理媒體時發生未預期的錯誤。",
      },
      overwrite: "目的檔已存在。要在轉檔成功後取代它嗎？",
      closeActive: "要取消目前的轉檔並關閉 MediaForge 嗎？",
    },
  },
} as const;

/** Resolves a persisted preference to a supported i18next locale. */
export function resolveLanguage(
  preference: LanguagePreference,
  systemLanguage: string,
): "en" | "zh-TW" {
  if (preference === "en" || preference === "zh-TW") {
    return preference;
  }
  return systemLanguage.toLowerCase().startsWith("zh") ? "zh-TW" : "en";
}

/** Returns the persisted language preference or the system default. */
export function loadLanguagePreference(): LanguagePreference {
  const stored = window.localStorage.getItem(LANGUAGE_KEY);
  return stored === "en" || stored === "zh-TW" || stored === "system" ? stored : "system";
}

/** Persists and activates a language preference. */
export async function setLanguagePreference(preference: LanguagePreference): Promise<void> {
  window.localStorage.setItem(LANGUAGE_KEY, preference);
  await i18n.changeLanguage(resolveLanguage(preference, window.navigator.language));
}

const preference = loadLanguagePreference();
void i18n.use(initReactI18next).init({
  resources,
  lng: resolveLanguage(preference, window.navigator.language),
  fallbackLng: "en",
  interpolation: { escapeValue: false },
});

export { i18n };
