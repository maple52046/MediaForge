import { Box, Button, Grid, Heading, HStack, Input, Slider, Text } from "@chakra-ui/react";
import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";

import type { TrimRange } from "../../lib/ipc";
import { formatTime, parseTime } from "../../lib/time";

interface TimelineProps {
  readonly durationMs: number;
  readonly trim: TrimRange;
  readonly currentMs: number;
  readonly disabled: boolean;
  readonly onTrimChange: (trim: TrimRange) => void;
  readonly onPlaySelection: () => void;
}

/** Accessible millisecond trim editor synchronized with preview playback. */
export function Timeline({
  durationMs,
  trim,
  currentMs,
  disabled,
  onTrimChange,
  onPlaySelection,
}: TimelineProps) {
  const { t } = useTranslation();
  const [startText, setStartText] = useState(formatTime(trim.startMs, true));
  const [endText, setEndText] = useState(formatTime(trim.endMs, true));

  useEffect(() => setStartText(formatTime(trim.startMs, true)), [trim.startMs]);
  useEffect(() => setEndText(formatTime(trim.endMs, true)), [trim.endMs]);

  function commitStart() {
    const parsed = parseTime(startText);
    if (parsed !== undefined && parsed < trim.endMs) {
      onTrimChange({ startMs: Math.min(parsed, durationMs), endMs: trim.endMs });
    } else {
      setStartText(formatTime(trim.startMs, true));
    }
  }

  function commitEnd() {
    const parsed = parseTime(endText);
    if (parsed !== undefined && parsed > trim.startMs && parsed <= durationMs) {
      onTrimChange({ startMs: trim.startMs, endMs: parsed });
    } else {
      setEndText(formatTime(trim.endMs, true));
    }
  }

  return (
    <Box className="panel">
      <Heading size="md" marginBottom="4">
        {t("timeline.title")}
      </Heading>
      <Box position="relative" paddingX="2" paddingTop="4">
        <Slider.Root
          min={0}
          max={Math.max(1, durationMs)}
          step={1}
          value={[trim.startMs, trim.endMs]}
          disabled={disabled}
          onValueChange={({ value }) => {
            const [startMs, endMs] = value;
            if (startMs !== undefined && endMs !== undefined && startMs < endMs) {
              onTrimChange({ startMs, endMs });
            }
          }}
          aria-label={[t("timeline.start"), t("timeline.end")]}
        >
          <Slider.Control>
            <Slider.Track>
              <Slider.Range />
            </Slider.Track>
            <Slider.Thumbs />
          </Slider.Control>
        </Slider.Root>
        <Box
          className="playhead"
          left={`${Math.min(100, Math.max(0, (currentMs / Math.max(1, durationMs)) * 100))}%`}
          aria-hidden="true"
        />
      </Box>
      <Grid templateColumns="1fr 1fr auto" gap="3" marginTop="5" alignItems="end">
        <TimeField
          label={t("timeline.start")}
          value={startText}
          disabled={disabled}
          onChange={setStartText}
          onCommit={commitStart}
        />
        <TimeField
          label={t("timeline.end")}
          value={endText}
          disabled={disabled}
          onChange={setEndText}
          onCommit={commitEnd}
        />
        <Text color="fg.muted" paddingBottom="2" minWidth="8rem">
          {t("timeline.current")}: {formatTime(currentMs)}
        </Text>
      </Grid>
      <HStack marginTop="4" wrap="wrap">
        <Button
          size="sm"
          variant="outline"
          disabled={disabled}
          onClick={() =>
            onTrimChange({ startMs: Math.min(currentMs, trim.endMs - 1), endMs: trim.endMs })
          }
        >
          {t("actions.setStart")}
        </Button>
        <Button
          size="sm"
          variant="outline"
          disabled={disabled || currentMs <= trim.startMs}
          onClick={() =>
            onTrimChange({ startMs: trim.startMs, endMs: Math.min(currentMs, durationMs) })
          }
        >
          {t("actions.setEnd")}
        </Button>
        <Button
          size="sm"
          variant="outline"
          disabled={disabled}
          onClick={() => onTrimChange({ startMs: 0, endMs: durationMs })}
        >
          {t("actions.reset")}
        </Button>
        <Button size="sm" colorPalette="purple" disabled={disabled} onClick={onPlaySelection}>
          {t("actions.playSelection")}
        </Button>
      </HStack>
    </Box>
  );
}

function TimeField({
  label,
  value,
  disabled,
  onChange,
  onCommit,
}: {
  readonly label: string;
  readonly value: string;
  readonly disabled: boolean;
  readonly onChange: (value: string) => void;
  readonly onCommit: () => void;
}) {
  return (
    <Box>
      <Text as="label" display="block" fontSize="xs" color="fg.muted" marginBottom="1">
        {label}
      </Text>
      <Input
        value={value}
        disabled={disabled}
        onChange={(event) => onChange(event.currentTarget.value)}
        onBlur={onCommit}
        onKeyDown={(event) => {
          if (event.key === "Enter") {
            onCommit();
          }
        }}
      />
    </Box>
  );
}
