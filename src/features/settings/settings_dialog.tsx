import { Box, Button, Dialog, Portal, Text } from "@chakra-ui/react";
import { useState } from "react";
import { useTranslation } from "react-i18next";

import type { BackendCapabilities } from "../../lib/ipc";
import {
  loadLanguagePreference,
  setLanguagePreference,
  type LanguagePreference,
} from "../../lib/i18n";

interface SettingsDialogProps {
  readonly open: boolean;
  readonly capabilities?: BackendCapabilities;
  readonly onClose: () => void;
}

function isLanguagePreference(value: string): value is LanguagePreference {
  return value === "system" || value === "zh-TW" || value === "en";
}

/** Language preference and diagnostic backend information. */
export function SettingsDialog({ open, capabilities, onClose }: SettingsDialogProps) {
  const { t } = useTranslation();
  const [language, setLanguage] = useState<LanguagePreference>(loadLanguagePreference());
  return (
    <Dialog.Root open={open} onOpenChange={({ open: nextOpen }) => !nextOpen && onClose()}>
      <Portal>
        <Dialog.Backdrop />
        <Dialog.Positioner>
          <Dialog.Content>
            <Dialog.Header>
              <Dialog.Title>{t("settings.title")}</Dialog.Title>
            </Dialog.Header>
            <Dialog.Body>
              <Text fontSize="sm" marginBottom="1">
                {t("settings.language")}
              </Text>
              <select
                className="native-select"
                value={language}
                onChange={(event) => {
                  const preference = event.currentTarget.value;
                  if (isLanguagePreference(preference)) {
                    setLanguage(preference);
                    void setLanguagePreference(preference).catch(() => {
                      setLanguage(loadLanguagePreference());
                    });
                  }
                }}
              >
                <option value="system">{t("settings.system")}</option>
                <option value="zh-TW">{t("settings.traditionalChinese")}</option>
                <option value="en">{t("settings.english")}</option>
              </select>
              {capabilities !== undefined && (
                <Box marginTop="5" className="backend-card">
                  <Text fontWeight="semibold">{t("settings.backend")}</Text>
                  <Text fontSize="sm" color="fg.muted">
                    FFmpeg {capabilities.ffmpegVersion}
                  </Text>
                  <Text fontSize="sm" color="fg.muted">
                    VideoToolbox {capabilities.h264Videotoolbox ? "✓" : "—"} · AAC{" "}
                    {capabilities.aac ? "✓" : "—"} · LAME {capabilities.libmp3lame ? "✓" : "—"}
                  </Text>
                </Box>
              )}
            </Dialog.Body>
            <Dialog.Footer>
              <Button onClick={onClose}>{t("settings.close")}</Button>
            </Dialog.Footer>
          </Dialog.Content>
        </Dialog.Positioner>
      </Portal>
    </Dialog.Root>
  );
}
