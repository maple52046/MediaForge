import { Folder1Outlined } from "@lineiconshq/free-icons";
import { Lineicons } from "@lineiconshq/react-lineicons";
import { Box, Button, Heading, Text, VStack } from "@chakra-ui/react";
import { useTranslation } from "react-i18next";

interface MediaDropZoneProps {
  readonly busy: boolean;
  readonly onBrowse: () => void;
}

/** Empty-state source picker that also communicates native drag/drop affordance. */
export function MediaDropZone({ busy, onBrowse }: MediaDropZoneProps) {
  const { t } = useTranslation();
  return (
    <Box className="drop-zone" aria-disabled={busy}>
      <VStack gap="4">
        <Lineicons icon={Folder1Outlined} size={48} aria-hidden="true" />
        <Heading size="lg">{t("drop.title")}</Heading>
        <Text color="fg.muted">{busy ? t("drop.busy") : t("drop.detail")}</Text>
        <Button colorPalette="purple" onClick={onBrowse} disabled={busy}>
          {t("actions.browse")}
        </Button>
      </VStack>
    </Box>
  );
}
