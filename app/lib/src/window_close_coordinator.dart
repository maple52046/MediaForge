import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import 'conversion_controller.dart';

/// Native window operations needed by conversion-aware close coordination.
abstract interface class WindowClosePort {
  /// Intercepts native close requests and delivers them through [onClose].
  Future<void> attach(VoidCallback onClose);

  /// Removes the interception installed by [attach].
  Future<void> detach();

  /// Destroys the native window after application cleanup is terminal.
  Future<void> destroy();
}

/// Adapts `window_manager` events to the focused close coordination boundary.
class WindowManagerClosePort with WindowListener implements WindowClosePort {
  VoidCallback? _onClose;
  bool _attached = false;

  @override
  Future<void> attach(VoidCallback onClose) async {
    _onClose = onClose;
    if (_attached) {
      return;
    }
    windowManager.addListener(this);
    _attached = true;
    try {
      await windowManager.setPreventClose(true);
    } on Object {
      windowManager.removeListener(this);
      _attached = false;
      _onClose = null;
      rethrow;
    }
  }

  @override
  Future<void> detach() async {
    if (!_attached) {
      return;
    }
    windowManager.removeListener(this);
    _attached = false;
    _onClose = null;
    await windowManager.setPreventClose(false);
  }

  @override
  Future<void> destroy() => windowManager.destroy();

  @override
  void onWindowClose() => _onClose?.call();
}

/// Defers native window destruction until active conversion cleanup finishes.
class ConversionWindowCloseCoordinator {
  /// Creates close coordination around presentation state and native operations.
  ConversionWindowCloseCoordinator(this._conversion, this._window);

  final ConversionController _conversion;
  final WindowClosePort _window;
  Future<void>? _closeFuture;

  /// Installs the native close interception.
  Future<void> attach() {
    return _window.attach(() {
      unawaited(requestClose());
    });
  }

  /// Cancels active work once and destroys the window after its terminal event.
  Future<void> requestClose() => _closeFuture ??= _close();

  /// Removes native interception when the Flutter composition root is disposed.
  Future<void> detach() => _window.detach();

  Future<void> _close() async {
    await _conversion.cancelAndWaitForTerminal();
    await _window.detach();
    await _window.destroy();
  }
}
