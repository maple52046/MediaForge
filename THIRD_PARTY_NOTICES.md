# Third-party notices

MediaForge application source is licensed under the MIT License. Distribution
artifacts also include dynamically linked third-party components under their
respective licenses.

## FFmpeg 8.1.1

MediaForge's reproducible configuration disables GPL and nonfree components and
builds FFmpeg as shared libraries under the GNU Lesser General Public License,
version 2.1 or later. The build enables Apple VideoToolbox, Apple AudioToolbox,
and the external LAME encoder. It does not enable libx264.

- Project: <https://ffmpeg.org/>
- Source: <https://ffmpeg.org/releases/ffmpeg-8.1.1.tar.xz>
- Build recipe: `scripts/build-media-deps-macos.sh`
- License copies in built artifacts: `share/licenses/ffmpeg`

## LAME 3.100

LAME is dynamically linked to provide MP3 encoding under the GNU Lesser
General Public License, version 2 or later.

- Project: <https://lame.sourceforge.io/>
- Source: <https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz>
- Build recipe: `scripts/build-media-deps-macos.sh`
- License copy in built artifacts: `share/licenses/lame`

Recipients may replace the bundled shared libraries with compatible modified
versions. The checksummed source archives and complete build instructions above
provide the corresponding source and relinking information for this release.
