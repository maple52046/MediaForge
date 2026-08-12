import { Box, Button, Heading, HStack, Input, Progress, Text } from "@chakra-ui/react";
import { useTranslation } from "react-i18next";

import type { AudioQuality, JobState, OutputMode } from "../../lib/ipc";

interface ConversionPanelProps {
  readonly modes: readonly OutputMode[];
  readonly mode: OutputMode;
  readonly quality: AudioQuality;
  readonly outputPath: string;
  readonly state: JobState;
  readonly percent: number;
  readonly onModeChange: (mode: OutputMode) => void;
  readonly onQualityChange: (quality: AudioQuality) => void;
  readonly onOutputPathChange: (path: string) => void;
  readonly onBrowseOutput: () => void;
  readonly onConvert: () => void;
  readonly onCancel: () => void;
}

/** Output recipe, destination, progress, and job actions. */
export function ConversionPanel(props: ConversionPanelProps) {
  const { t } = useTranslation();
  const active = props.state === "preparing" || props.state === "running";
  return (
    <Box className="panel">
      <Heading size="md" marginBottom="4">
        {t("conversion.title")}
      </Heading>
      <Text as="label" display="block" fontSize="xs" color="fg.muted" marginBottom="1">
        {t("conversion.mode")}
      </Text>
      <select
        className="native-select"
        value={props.mode}
        disabled={active}
        onChange={(event) => props.onModeChange(event.currentTarget.value as OutputMode)}
      >
        {props.modes.map((mode) => (
          <option key={mode} value={mode}>
            {t(`conversion.${mode}`)}
          </option>
        ))}
      </select>
      {props.mode === "audioOnly" && (
        <Box marginTop="3">
          <Text as="label" display="block" fontSize="xs" color="fg.muted" marginBottom="1">
            {t("conversion.quality")}
          </Text>
          <select
            className="native-select"
            value={props.quality}
            disabled={active}
            onChange={(event) => props.onQualityChange(event.currentTarget.value as AudioQuality)}
          >
            {(["high", "medium", "low"] as const).map((quality) => (
              <option key={quality} value={quality}>
                {t(`conversion.${quality}`)}
              </option>
            ))}
          </select>
        </Box>
      )}
      <Text
        as="label"
        display="block"
        fontSize="xs"
        color="fg.muted"
        marginTop="3"
        marginBottom="1"
      >
        {t("conversion.destination")}
      </Text>
      <HStack>
        <Input
          value={props.outputPath}
          disabled={active}
          onChange={(event) => props.onOutputPathChange(event.currentTarget.value)}
        />
        <Button variant="outline" disabled={active} onClick={props.onBrowseOutput}>
          {t("actions.browseOutput")}
        </Button>
      </HStack>
      {props.state !== "idle" && (
        <Box marginTop="4" aria-live="polite">
          <Progress.Root value={props.percent} colorPalette="purple">
            <Progress.Track>
              <Progress.Range />
            </Progress.Track>
          </Progress.Root>
          <Text fontSize="sm" color="fg.muted" marginTop="2">
            {props.state === "running"
              ? t("conversion.running", { percent: Math.round(props.percent) })
              : t(`conversion.${props.state}`)}
          </Text>
        </Box>
      )}
      <Button
        width="full"
        marginTop="5"
        colorPalette={active ? "red" : "purple"}
        onClick={active ? props.onCancel : props.onConvert}
      >
        {active ? t("actions.cancel") : t("actions.convert")}
      </Button>
    </Box>
  );
}
