import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'mf_tokens.dart';

/// Repository-owned SVG icons used by the MediaForge interface.
enum MfIconData {
  /// Select or drop a media file.
  upload('cloud-upload-outlined.svg'),

  /// Start preview playback.
  play('play-outlined.svg'),

  /// Pause preview playback.
  pause('pause-outlined.svg');

  const MfIconData(this.fileName);

  /// File name under the Flutter icon asset directory.
  final String fileName;
}

/// Renders a Lineicons SVG with caller-controlled size and color.
class MfIcon extends StatelessWidget {
  /// Creates an icon from a repository-owned Lineicons asset.
  const MfIcon(
    this.icon, {
    super.key,
    this.size = 20,
    this.color = MfPalette.foreground,
  });

  /// Icon asset to render.
  final MfIconData icon;

  /// Square logical size.
  final double size;

  /// Color applied to every SVG path.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/${icon.fileName}',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
