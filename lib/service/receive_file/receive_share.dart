import 'dart:io';

import 'package:anx_reader/main.dart';
import 'package:anx_reader/service/book.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void receiveShareIntent(WidgetRef ref) {
  // receive sharing intent
  Future<void> handleShare(List<SharedMediaFile> value) async {
    List<File> files = [];
    for (var item in value) {
      String? resolvedPath =
          item.path.trim().isNotEmpty ? item.path.trim() : null;

      // On some platforms (e.g., OHOS) path may be empty while uri carries the real location.
      if ((resolvedPath == null || resolvedPath.isEmpty) &&
          item.uri != null &&
          item.uri!.trim().isNotEmpty) {
        final uriString = item.uri!.trim();
        final parsed = Uri.tryParse(uriString);
        if (parsed != null && parsed.scheme == 'file') {
          try {
            if (parsed.authority.isNotEmpty) {
              // Some platforms send file URIs with authority; use the path part directly.
              resolvedPath = parsed.path;
            } else {
              resolvedPath = parsed.toFilePath();
            }
          } catch (e, st) {
            AnxLog.warning(
                'share: Failed to parse file uri ${item.uri}: $e', e, st);
          }
        }
      }

      if (resolvedPath != null && resolvedPath.isNotEmpty) {
        var candidate = File(resolvedPath);
        if (!candidate.existsSync() && resolvedPath.startsWith('/docs/')) {
          // OHOS paths may include a /docs prefix; try without it.
          final fallbackPath = resolvedPath.replaceFirst('/docs', '');
          final fallback = File(fallbackPath);
          if (fallback.existsSync()) {
            candidate = fallback;
          }
        }

        if (candidate.existsSync()) {
          files.add(candidate);
        } else {
          AnxLog.warning(
              'share: Resolved path does not exist, skip: $resolvedPath from ${item.toMap()}');
        }
      } else {
        AnxLog.warning(
            'share: Skip shared item with empty path and uri: ${item.toMap()}');
      }
    }

    if (files.isEmpty) {
      AnxLog.warning(
          'share: No valid shared files resolved from intent: ${value.map((e) => e.toMap())}');
      return;
    }
    importBookList(files, navigatorKey.currentContext!, ref);
    ReceiveSharingIntent.instance.reset();
  }

  ReceiveSharingIntent.instance.getMediaStream().listen((value) {
    AnxLog.info('share: Receive share intent: ${value.map((e) => e.toMap())}');
    if (value.isNotEmpty) {
      handleShare(value);
    }
  }, onError: (err) {
    AnxLog.severe(
        'share: Receive share intent, stream error: ${err?.toString()}');
  });

  ReceiveSharingIntent.instance.getInitialMedia().then((value) {
    AnxLog.info('share: Receive share intent: ${value.map((e) => e.toMap())}');
    if (value.isNotEmpty) {
      handleShare(value);
    }
  }, onError: (err) {
    AnxLog.severe(
        'share: Receive share intent, initial error: ${err?.toString()}');
  });
}
