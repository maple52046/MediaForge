import { SlidersHorizontalSquare2Outlined } from "@lineiconshq/free-icons";
import { Lineicons } from "@lineiconshq/react-lineicons";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { open, save } from "@tauri-apps/plugin-dialog";
import { Box, Button, Grid, Heading, HStack, Text } from "@chakra-ui/react";
import { useCallback, useEffect, useRef, useState } from "react";
import { useTranslation } from "react-i18next";

import { ConversionPanel } from "./features/conversion/conversion_panel";
import { MediaDetails } from "./features/media/media_details";
import { MediaDropZone } from "./features/media/media_drop_zone";
import { MediaPreview } from "./features/preview/media_preview";
import { SettingsDialog } from "./features/settings/settings_dialog";
import { Timeline } from "./features/timeline/timeline";
import {
  cancelTranscode,
  getBackendCapabilities,
  listenToJobEvents,
  loadMedia,
  startTranscode,
  toApiError,
  type ApiError,
  type AudioQuality,
  type BackendCapabilities,
  type JobState,
  type MediaInfo,
  type OutputMode,
  type TrimRange,
} from "./lib/ipc";
import { isActiveJob, outputPathForMode } from "./lib/media";

/** MediaForge desktop application shell. */
export function App() {
  const { t } = useTranslation();
  const mediaElementRef = useRef<HTMLMediaElement | null>(null);
  const selectionPlayback = useRef(false);
  const closeAfterCancellation = useRef(false);
  const [media, setMedia] = useState<MediaInfo>();
  const [capabilities, setCapabilities] = useState<BackendCapabilities>();
  const [mode, setMode] = useState<OutputMode>("videoWithAudio");
  const [quality, setQuality] = useState<AudioQuality>("medium");
  const [trim, setTrim] = useState<TrimRange>({ startMs: 0, endMs: 1 });
  const [currentMs, setCurrentMs] = useState(0);
  const [outputPath, setOutputPath] = useState("");
  const [jobId, setJobId] = useState<string>();
  const [jobState, setJobState] = useState<JobState>("idle");
  const [percent, setPercent] = useState(0);
  const [error, setError] = useState<ApiError>();
  const [settingsOpen, setSettingsOpen] = useState(false);
  const active = isActiveJob(jobState);

  const selectMedia = useCallback(
    async (path: string) => {
      if (active) {
        return;
      }
      setError(undefined);
      try {
        const loaded = await loadMedia(path);
        const defaultMode = loaded.availableOutputModes[0];
        if (defaultMode === undefined) {
          throw { code: "unsupportedInput", message: "No output mode is available." };
        }
        setMedia(loaded);
        setMode(defaultMode);
        setTrim({ startMs: 0, endMs: loaded.durationMs });
        setCurrentMs(0);
        setOutputPath(outputPathForMode(loaded.path, defaultMode));
        setJobState("idle");
        setPercent(0);
      } catch (value: unknown) {
        setError(toApiError(value));
      }
    },
    [active],
  );

  useEffect(() => {
    void getBackendCapabilities()
      .then(setCapabilities)
      .catch((value: unknown) => setError(toApiError(value)));
    let disposed = false;
    let cleanup: (() => void) | undefined;
    void listenToJobEvents((event) => {
      if (event.type === "preparing") {
        setJobState("preparing");
      } else if (event.type === "progress") {
        setJobState("running");
        setPercent(event.percent);
      } else if (event.type === "completed") {
        setJobState("completed");
        setPercent(100);
        if (closeAfterCancellation.current) {
          void getCurrentWindow().destroy();
        }
      } else if (event.type === "cancelled") {
        setJobState("cancelled");
        if (closeAfterCancellation.current) {
          void getCurrentWindow().destroy();
        }
      } else {
        setJobState("failed");
        setError(event.error);
        if (closeAfterCancellation.current) {
          void getCurrentWindow().destroy();
        }
      }
    }).then((unlisten) => {
      if (disposed) {
        unlisten();
      } else {
        cleanup = unlisten;
      }
    });
    return () => {
      disposed = true;
      cleanup?.();
    };
  }, []);

  useEffect(() => {
    const appWindow = getCurrentWindow();
    let disposed = false;
    const cleanups: Array<() => void> = [];
    void appWindow
      .onDragDropEvent((event) => {
        if (event.payload.type === "drop") {
          const firstPath = event.payload.paths[0];
          if (firstPath !== undefined) {
            void selectMedia(firstPath);
          }
        }
      })
      .then((cleanup) => {
        if (disposed) cleanup();
        else cleanups.push(cleanup);
      });
    void appWindow
      .onCloseRequested(async (event) => {
        if (active && !window.confirm(t("closeActive"))) {
          event.preventDefault();
        } else if (active && jobId !== undefined) {
          event.preventDefault();
          closeAfterCancellation.current = true;
          await cancelTranscode(jobId).catch((value: unknown) => {
            closeAfterCancellation.current = false;
            setError(toApiError(value));
          });
        }
      })
      .then((cleanup) => {
        if (disposed) cleanup();
        else cleanups.push(cleanup);
      });
    return () => {
      disposed = true;
      cleanups.forEach((cleanup) => cleanup());
    };
  }, [active, jobId, selectMedia, t]);

  useEffect(() => {
    if (selectionPlayback.current && currentMs >= trim.endMs) {
      mediaElementRef.current?.pause();
      selectionPlayback.current = false;
    }
  }, [currentMs, trim.endMs]);

  async function browseMedia() {
    const path = await open({
      multiple: false,
      directory: false,
      filters: [
        {
          name: "Media",
          extensions: ["mov", "mp4", "m4v", "mp3", "wav", "m4a", "aac", "aif", "aiff"],
        },
      ],
    });
    if (typeof path === "string") {
      await selectMedia(path);
    }
  }

  function changeMode(nextMode: OutputMode) {
    setMode(nextMode);
    if (media !== undefined) {
      setOutputPath(outputPathForMode(media.path, nextMode));
    }
  }

  async function browseOutput() {
    const selected = await save({
      defaultPath: outputPath,
      filters: [
        mode === "audioOnly"
          ? { name: "MP3 audio", extensions: ["mp3"] }
          : { name: "MP4 video", extensions: ["mp4"] },
      ],
    });
    if (selected !== null) {
      setOutputPath(selected);
    }
  }

  async function beginConversion(overwrite = false) {
    if (media === undefined || outputPath.length === 0) {
      return;
    }
    setError(undefined);
    setPercent(0);
    try {
      const snapshot = await startTranscode({
        inputPath: media.path,
        outputPath,
        mode,
        trim,
        audioQuality: quality,
        overwrite,
      });
      setJobId(snapshot.jobId);
      setJobState(snapshot.state);
    } catch (value: unknown) {
      const nextError = toApiError(value);
      if (nextError.code === "outputExists" && !overwrite && window.confirm(t("overwrite"))) {
        await beginConversion(true);
      } else {
        setError(nextError);
        setJobState("failed");
      }
    }
  }

  function playSelection() {
    const element = mediaElementRef.current;
    if (element === null) {
      return;
    }
    element.currentTime = trim.startMs / 1_000;
    selectionPlayback.current = true;
    void element.play().catch(() => {
      selectionPlayback.current = false;
    });
  }

  return (
    <Box minHeight="100vh">
      <HStack as="header" className="app-header" justifyContent="space-between">
        <Box>
          <Heading size="2xl" letterSpacing="tight">
            MediaForge
          </Heading>
          <Text color="fg.muted">{t("app.subtitle")}</Text>
        </Box>
        <HStack>
          {media !== undefined && (
            <Button variant="outline" disabled={active} onClick={() => void browseMedia()}>
              {t("actions.change")}
            </Button>
          )}
          <Button
            variant="ghost"
            onClick={() => setSettingsOpen(true)}
            aria-label={t("actions.settings")}
          >
            <Lineicons icon={SlidersHorizontalSquare2Outlined} size={22} />
          </Button>
        </HStack>
      </HStack>
      <Box as="main" className="app-main">
        {error !== undefined && (
          <Box className="error-banner" role="alert">
            <Text fontWeight="semibold">
              {t(`errors.${error.code}`, { defaultValue: t("errors.unexpected") })}
            </Text>
            <Text fontSize="sm">{error.message}</Text>
          </Box>
        )}
        {media === undefined ? (
          <MediaDropZone busy={active} onBrowse={() => void browseMedia()} />
        ) : (
          <Grid templateColumns="minmax(0, 1fr) 22rem" gap="5" alignItems="start">
            <Box>
              <MediaPreview
                media={media}
                mediaRef={mediaElementRef}
                onTimeChange={setCurrentMs}
                onEnded={() => {
                  selectionPlayback.current = false;
                }}
              />
              <Box marginTop="5">
                <Timeline
                  durationMs={media.durationMs}
                  trim={trim}
                  currentMs={currentMs}
                  disabled={active}
                  onTrimChange={setTrim}
                  onPlaySelection={playSelection}
                />
              </Box>
            </Box>
            <Box display="grid" gap="5">
              <MediaDetails media={media} />
              <ConversionPanel
                modes={media.availableOutputModes}
                mode={mode}
                quality={quality}
                outputPath={outputPath}
                state={jobState}
                percent={percent}
                onModeChange={changeMode}
                onQualityChange={setQuality}
                onOutputPathChange={setOutputPath}
                onBrowseOutput={() => void browseOutput()}
                onConvert={() => void beginConversion()}
                onCancel={() => {
                  if (jobId !== undefined) void cancelTranscode(jobId);
                }}
              />
            </Box>
          </Grid>
        )}
      </Box>
      <SettingsDialog
        open={settingsOpen}
        capabilities={capabilities}
        onClose={() => setSettingsOpen(false)}
      />
    </Box>
  );
}
