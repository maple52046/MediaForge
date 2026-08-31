import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';

/// Selects one local source file at the Flutter platform boundary.
abstract interface class SourceFilePicker {
  /// Opens the native source picker and returns `null` when it is dismissed.
  Future<String?> pickSourceFile();
}

/// Selects one local destination directory at the Flutter platform boundary.
abstract interface class DestinationDirectoryPicker {
  /// Opens the native directory picker and returns `null` when it is dismissed.
  Future<String?> pickDestinationDirectory({String? initialDirectory});
}

/// Combined platform boundary used by the desktop composition root.
abstract interface class FileSelectionPort
    implements SourceFilePicker, DestinationDirectoryPicker {}

/// Native file-picker adapter shared by the source and destination controllers.
class NativeFileSelection implements FileSelectionPort {
  /// Creates the stateless native picker adapter.
  const NativeFileSelection();

  @override
  Future<String?> pickSourceFile() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const <String>[
        'mov',
        'mp4',
        'm4a',
        'wav',
        'mp3',
        'aac',
        'mkv',
        'avi',
        'webm',
      ],
    );
    return result?.files.singleOrNull?.path;
  }

  @override
  Future<String?> pickDestinationDirectory({String? initialDirectory}) {
    return FilePicker.getDirectoryPath(initialDirectory: initialDirectory);
  }
}

/// Deterministic file selection used only by the presentation prototype.
class PrototypeFileSelection implements FileSelectionPort {
  /// Creates deterministic picker results for widget tests and screenshots.
  const PrototypeFileSelection({required this.sourcePath, this.directoryPath});

  /// Source returned by [pickSourceFile].
  final String? sourcePath;

  /// Directory returned by [pickDestinationDirectory].
  final String? directoryPath;

  @override
  Future<String?> pickSourceFile() async => sourcePath;

  @override
  Future<String?> pickDestinationDirectory({String? initialDirectory}) async =>
      directoryPath;
}

/// Owns the security-scoped lifetime of the currently committed dropped file.
class DesktopDropSourceCoordinator {
  Uint8List? _activeBookmark;
  bool _closed = false;

  /// Validates one dropped file and transfers access only after probe succeeds.
  Future<bool> commit(
    DropItem item,
    Future<bool> Function(String path) replaceSource,
  ) async {
    if (_closed || item is DropItemDirectory) {
      return false;
    }
    final bookmark = item.extraAppleBookmark;
    var accessStarted = false;
    if (bookmark != null && bookmark.isNotEmpty) {
      accessStarted = await DesktopDrop.instance
          .startAccessingSecurityScopedResource(bookmark: bookmark);
      if (!accessStarted) {
        return false;
      }
    }
    final committed = await replaceSource(item.path);
    if (!committed || _closed) {
      if (accessStarted) {
        await DesktopDrop.instance.stopAccessingSecurityScopedResource(
          bookmark: bookmark!,
        );
      }
      return false;
    }
    final previousBookmark = _activeBookmark;
    _activeBookmark = accessStarted ? bookmark : null;
    if (previousBookmark != null) {
      await DesktopDrop.instance.stopAccessingSecurityScopedResource(
        bookmark: previousBookmark,
      );
    }
    return true;
  }

  /// Releases access retained for the active dropped source exactly once.
  Future<void> release() async {
    final bookmark = _activeBookmark;
    _activeBookmark = null;
    if (bookmark != null) {
      await DesktopDrop.instance.stopAccessingSecurityScopedResource(
        bookmark: bookmark,
      );
    }
  }

  /// Permanently closes the coordinator and releases retained source access.
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await release();
  }
}
