import { Box, Text } from "@chakra-ui/react";
import type { RefObject, SyntheticEvent } from "react";
import { useState } from "react";
import { useTranslation } from "react-i18next";

import type { MediaInfo } from "../../lib/ipc";
import { previewUrl } from "../../lib/ipc";

interface MediaPreviewProps {
  readonly media: MediaInfo;
  readonly mediaRef: RefObject<HTMLMediaElement | null>;
  readonly onTimeChange: (milliseconds: number) => void;
  readonly onEnded: () => void;
}

/** Native WebView media preview with an explicitly non-blocking failure state. */
export function MediaPreview({ media, mediaRef, onTimeChange, onEnded }: MediaPreviewProps) {
  const { t } = useTranslation();
  const [unavailable, setUnavailable] = useState(false);
  const source = previewUrl(media.path);
  const handleTimeUpdate = (event: SyntheticEvent<HTMLMediaElement>) => {
    onTimeChange(Math.round(event.currentTarget.currentTime * 1_000));
  };

  return (
    <Box className="preview-shell">
      {unavailable ? (
        <Text color="fg.muted">{t("preview.unavailable")}</Text>
      ) : media.video === undefined ? (
        <audio
          ref={mediaRef as RefObject<HTMLAudioElement | null>}
          src={source}
          controls
          onError={() => setUnavailable(true)}
          onTimeUpdate={handleTimeUpdate}
          onEnded={onEnded}
        />
      ) : (
        <video
          ref={mediaRef as RefObject<HTMLVideoElement | null>}
          src={source}
          controls
          onError={() => setUnavailable(true)}
          onTimeUpdate={handleTimeUpdate}
          onEnded={onEnded}
        />
      )}
    </Box>
  );
}
