import { Box, Grid, Heading, Text } from "@chakra-ui/react";
import { useTranslation } from "react-i18next";

import type { MediaInfo } from "../../lib/ipc";
import { formatTime } from "../../lib/time";

interface MediaDetailsProps {
  readonly media: MediaInfo;
}

function formatBytes(bytes: number): string {
  if (bytes < 1_000_000) {
    return `${(bytes / 1_000).toFixed(1)} KB`;
  }
  return `${(bytes / 1_000_000).toFixed(1)} MB`;
}

/** Presents primary-stream metadata without exposing FFmpeg implementation types. */
export function MediaDetails({ media }: MediaDetailsProps) {
  const { t } = useTranslation();
  return (
    <Box className="panel">
      <Heading size="md" marginBottom="4">
        {t("media.source")}
      </Heading>
      <Text fontWeight="semibold" truncate>
        {media.fileName}
      </Text>
      <Text color="fg.muted" fontSize="sm" truncate title={media.path}>
        {media.path}
      </Text>
      <Grid templateColumns="repeat(2, minmax(0, 1fr))" gap="3" marginTop="4">
        <Detail label={t("media.format")} value={media.format} />
        <Detail label={t("media.duration")} value={formatTime(media.durationMs)} />
        <Detail label={t("media.size")} value={formatBytes(media.fileSizeBytes)} />
        <Detail
          label={t("media.video")}
          value={
            media.video === undefined
              ? t("media.none")
              : `${media.video.codec} · ${media.video.width}×${media.video.height}`
          }
        />
        <Detail
          label={t("media.audio")}
          value={
            media.audio === undefined
              ? t("media.none")
              : `${media.audio.codec} · ${media.audio.sampleRate ?? "—"} Hz`
          }
        />
      </Grid>
    </Box>
  );
}

function Detail({ label, value }: { readonly label: string; readonly value: string }) {
  return (
    <Box>
      <Text color="fg.muted" fontSize="xs">
        {label}
      </Text>
      <Text fontSize="sm">{value}</Text>
    </Box>
  );
}
