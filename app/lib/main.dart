import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'src/mediaforge_app.dart';
import 'src/mf_tokens.dart';
import 'src/prototype_state.dart';

/// Starts the interactive MediaForge desktop prototype.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  const compact = bool.fromEnvironment('MEDIAFORGE_COMPACT_WINDOW');
  const large = bool.fromEnvironment('MEDIAFORGE_LARGE_WINDOW');
  const windowOptions = WindowOptions(
    size: compact
        ? Size(1040, 680)
        : large
        ? Size(1440, 900)
        : Size(1200, 780),
    minimumSize: Size(1040, 680),
    center: true,
    backgroundColor: MfPalette.background,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: true,
  );
  final windowReady = windowManager.waitUntilReadyToShow(
    windowOptions,
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  const stateName = String.fromEnvironment(
    'MEDIAFORGE_PREVIEW_STATE',
    defaultValue: 'loaded',
  );
  const showDropOverlay = bool.fromEnvironment('MEDIAFORGE_SHOW_DROP_OVERLAY');
  const showSettingsPopover = bool.fromEnvironment(
    'MEDIAFORGE_SHOW_SETTINGS_POPOVER',
  );
  runApp(
    MediaForgePrototypeApp(
      state: PrototypeState.fromName(stateName),
      autoAdvanceProgress: true,
      showDropOverlay: showDropOverlay,
      showSettingsPopover: showSettingsPopover,
    ),
  );
  await windowReady;
}
