import 'package:anx_reader/main.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class AnxHeadlessWebView {
  HeadlessInAppWebView? _headlessWebView;
  OverlayEntry? _overlayEntry;

  final URLRequest initialUrlRequest;
  final void Function(InAppWebViewController controller, WebUri? url)?
      onLoadStop;
  final void Function(
          InAppWebViewController controller, ConsoleMessage consoleMessage)?
      onConsoleMessage;
  final WebViewEnvironment? webViewEnvironment;

  AnxHeadlessWebView({
    required this.initialUrlRequest,
    this.onLoadStop,
    this.onConsoleMessage,
    this.webViewEnvironment,
  });

  Future<void> run() async {
    bool useOverlay = false;
    try {
      if (TargetPlatform.ohos == defaultTargetPlatform) {
        useOverlay = true;
      }
    } catch (e) {
      // ignore
    }

    if (useOverlay) {
      _runOverlay();
    } else {
      _headlessWebView = HeadlessInAppWebView(
        webViewEnvironment: webViewEnvironment,
        initialUrlRequest: initialUrlRequest,
        onLoadStop: onLoadStop,
        onConsoleMessage: onConsoleMessage,
      );
      try {
        await _headlessWebView?.run();
      } catch (e) {
        AnxLog.info(
            "HeadlessInAppWebView failed to run, falling back to Overlay: $e");
        _headlessWebView = null;
        _runOverlay();
      }
    }
  }

  void _runOverlay() {
    final context = navigatorKey.currentContext;
    if (context == null) {
      AnxLog.severe("No context available for AnxHeadlessWebView overlay");
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Offstage(
        offstage: true,
        child: SizedBox(
          width: 1,
          height: 1,
          child: InAppWebView(
            initialUrlRequest: initialUrlRequest,
            onLoadStop: onLoadStop,
            onConsoleMessage: onConsoleMessage,
            onWebViewCreated: (controller) {
              // Controller is available here if needed
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Future<void> dispose() async {
    if (_headlessWebView != null) {
      await _headlessWebView?.dispose();
      _headlessWebView = null;
    }
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
    }
  }
}
