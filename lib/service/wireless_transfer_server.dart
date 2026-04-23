import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/dao/book.dart' as book_dao;
import 'package:anx_reader/models/book.dart';
import 'package:anx_reader/service/md5_service.dart';
import 'package:anx_reader/utils/get_path/get_base_path.dart';
import 'package:anx_reader/utils/get_path/get_temp_dir.dart';
import 'package:anx_reader/utils/log/common.dart';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;

class WirelessTransferServer {
  static final WirelessTransferServer _singleton =
      WirelessTransferServer._internal();

  factory WirelessTransferServer() {
    return _singleton;
  }

  WirelessTransferServer._internal();

  HttpServer? _server;
  Timer? _inactivityTimer;
  final List<Map<String, dynamic>> _uploadHistory = [];

  static const List<String> _supportedExtensions = ['epub', 'pdf', 'txt'];
  static const int _maxFileSize = 500 * 1024 * 1024; // 500MB

  bool get isRunning => _server != null;

  int get port => _server?.port ?? 0;

  List<Map<String, dynamic>> get uploadHistory =>
      List.unmodifiable(_uploadHistory);

  Future<bool> start({int? portOverride}) async {
    if (_server != null) {
      AnxLog.info('WirelessTransfer: Already running on port ${_server!.port}');
      return true;
    }

    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(_handleRequests);

    int port = portOverride ?? Prefs().wirelessTransferPort;

    try {
      _server = await io.serve(handler, InternetAddress.anyIPv4, port);
    } catch (e) {
      AnxLog.warning('WirelessTransfer: Port $port in use, trying random: $e');
      try {
        _server = await io.serve(handler, InternetAddress.anyIPv4, 0);
      } catch (e2) {
        AnxLog.severe('WirelessTransfer: Failed to start server: $e2');
        return false;
      }
    }

    Prefs().wirelessTransferPort = _server!.port;
    AnxLog.info(
        'WirelessTransfer: Server running at http://0.0.0.0:${_server!.port}');

    _resetInactivityTimer();
    return true;
  }

  Future<void> stop() async {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;

    if (_server == null) return;

    final stoppedPort = _server!.port;
    await _server?.close(force: true);
    _server = null;
    AnxLog.info('WirelessTransfer: Server stopped (port $stoppedPort)');
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();

    int shutdownSeconds = Prefs().wirelessTransferAutoShutdown;
    if (shutdownSeconds <= 0) {
      AnxLog.info('WirelessTransfer: Auto-shutdown disabled');
      return;
    }

    _inactivityTimer = Timer(Duration(seconds: shutdownSeconds), () {
      AnxLog.info('WirelessTransfer: Auto-shutdown triggered (idle timeout)');
      stop();
    });

    AnxLog.info(
        'WirelessTransfer: Inactivity timer set for ${shutdownSeconds}s');
  }

  Future<shelf.Response> _handleRequests(shelf.Request request) async {
    _resetInactivityTimer();

    final uriPath = request.requestedUri.path;
    final method = request.method;

    AnxLog.info('WirelessTransfer: $method $uriPath');

    if (method == 'GET' && uriPath == '/') {
      return _serveUploadPage();
    }

    if (method == 'POST' && uriPath == '/upload') {
      return _handleUpload(request);
    }

    if (method == 'GET' && uriPath == '/status') {
      return _serveStatus();
    }

    return shelf.Response.ok(
      'Wireless Transfer Server',
      headers: {'Content-Type': 'text/plain'},
    );
  }

  Future<shelf.Response> _serveUploadPage() async {
    try {
      String content = await rootBundle.loadString('assets/transfer/index.html');
      return shelf.Response.ok(
        content,
        headers: {'Content-Type': 'text/html; charset=utf-8'},
      );
    } catch (e) {
      return shelf.Response.internalServerError(
        body: 'Upload page not found: $e',
      );
    }
  }

  shelf.Response _serveStatus() {
    final status = {
      'running': isRunning,
      'port': port,
      'uploads': _uploadHistory,
    };
    return shelf.Response.ok(
      jsonEncode(status),
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }

  Future<shelf.Response> _handleUpload(shelf.Request request) async {
    try {
      final contentType = request.headers['content-type'] ?? '';

      if (!contentType.contains('multipart/form-data')) {
        return shelf.Response.badRequest(
          body: jsonEncode({'error': 'Content-Type must be multipart/form-data'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final boundary = _extractBoundary(contentType);
      if (boundary == null) {
        return shelf.Response.badRequest(
          body: jsonEncode({'error': 'Missing boundary in Content-Type'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final bodyBytes = await request.read().fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );

      final files = _parseMultipartBytes(bodyBytes, boundary);

      if (files.isEmpty) {
        return shelf.Response.badRequest(
          body: jsonEncode({'error': 'No files found in upload'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final results = <Map<String, dynamic>>[];

      for (final fileData in files) {
        final fileName = fileData['filename'] as String;
        final contentBytes = fileData['content'] as List<int>;

        final ext = fileName.split('.').last.toLowerCase();
        if (!_supportedExtensions.contains(ext)) {
          results.add({
            'filename': fileName,
            'success': false,
            'error': 'Unsupported file type. Supported: ${_supportedExtensions.join(', ')}',
          });
          continue;
        }

        if (contentBytes.length > _maxFileSize) {
          results.add({
            'filename': fileName,
            'success': false,
            'error': 'File too large (max ${_maxFileSize ~/ (1024 * 1024)}MB)',
          });
          continue;
        }

        try {
          final tempDir = await getAnxTempDir();
          final safeName =
              '${DateTime.now().millisecondsSinceEpoch}_$fileName';
          final tempFile = File('${tempDir.path}/$safeName');
          await tempFile.writeAsBytes(contentBytes, flush: true);

          final md5 = await MD5Service.calculateFileMd5(tempFile.path);
          final bookName = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
          await _saveBookToFile(tempFile, bookName, md5);

          results.add({
            'filename': fileName,
            'success': true,
          });

          _uploadHistory.add({
            'filename': fileName,
            'time': DateTime.now().toIso8601String(),
            'success': true,
          });
        } catch (e) {
          AnxLog.severe('WirelessTransfer: Import failed for $fileName: $e');
          results.add({
            'filename': fileName,
            'success': false,
            'error': e.toString(),
          });
          _uploadHistory.add({
            'filename': fileName,
            'time': DateTime.now().toIso8601String(),
            'success': false,
            'error': e.toString(),
          });
        }
      }

      return shelf.Response.ok(
        jsonEncode({'results': results}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e, stack) {
      AnxLog.severe('WirelessTransfer: Upload error: $e\n$stack');
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }
  }

  String? _extractBoundary(String contentType) {
    final boundaryMatch = RegExp(r'boundary=(.+)').firstMatch(contentType);
    return boundaryMatch?.group(1)?.replaceAll(RegExp(r'^"|"$'), '');
  }

  List<Map<String, dynamic>> _parseMultipartBytes(
      List<int> body, String boundary) {
    final files = <Map<String, dynamic>>[];
    final delimiter = utf8.encode('--$boundary');

    // Find all parts
    int startIdx = 0;
    while (startIdx < body.length) {
      // Find delimiter
      int delimIdx = _findSubsequence(body, delimiter, startIdx);
      if (delimIdx == -1) break;

      // Find end of delimiter line
      int lineEnd = _findLineEnd(body, delimIdx + delimiter.length);

      // Find header/body separator (\r\n\r\n)
      int headerEnd = _findSubsequence(body, [13, 10, 13, 10], lineEnd);
      if (headerEnd == -1) {
        startIdx = lineEnd;
        continue;
      }

      final headerBytes = body.sublist(lineEnd, headerEnd);
      final headerStr = utf8.decode(headerBytes);

      // Check for filename in Content-Disposition header
      final filenameMatch =
          RegExp(r'filename="([^"]+)"').firstMatch(headerStr);
      if (filenameMatch == null) {
        startIdx = headerEnd + 4;
        continue;
      }

      final filename = filenameMatch.group(1)!;

      // Find end of part (next delimiter or closing --)
      final closingDelimiter = utf8.encode('--$boundary--');
      int nextDelim = _findSubsequence(body, delimiter, headerEnd + 4);
      int nextClosing = _findSubsequence(body, closingDelimiter, headerEnd + 4);

      int endIdx;
      if (nextDelim != -1 && (nextClosing == -1 || nextDelim < nextClosing)) {
        endIdx = nextDelim;
      } else if (nextClosing != -1) {
        endIdx = nextClosing;
      } else {
        break;
      }

      // Extract content, trim trailing \r\n
      var contentEnd = endIdx;
      while (contentEnd > headerEnd + 4 &&
          (body[contentEnd - 1] == 13 || body[contentEnd - 1] == 10)) {
        contentEnd--;
      }

      final contentBytes = body.sublist(headerEnd + 4, contentEnd);

      files.add({
        'filename': filename,
        'content': contentBytes,
      });

      startIdx = endIdx;
    }

    return files;
  }

  int _findSubsequence(List<int> haystack, List<int> needle, int start) {
    if (needle.isEmpty) return -1;
    for (int i = start; i <= haystack.length - needle.length; i++) {
      bool found = true;
      for (int j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  int _findLineEnd(List<int> body, int start) {
    for (int i = start; i < body.length; i++) {
      if (body[i] == 13 || body[i] == 10) {
        // Skip all line endings
        while (i < body.length && (body[i] == 13 || body[i] == 10)) {
          i++;
        }
        return i;
      }
    }
    return body.length;
  }

  Future<void> _saveBookToFile(File tempFile, String title, String? md5) async {
    final extension = tempFile.path.split('.').last;
    final safeTitle = title
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .trim();
    final bookName =
        '${safeTitle.length > 20 ? safeTitle.substring(0, 20) : safeTitle}-${DateTime.now().millisecondsSinceEpoch}';
    final dbFilePath = 'file/$bookName.$extension';
    final filePath = getBasePath(dbFilePath);

    await tempFile.copy(filePath);
    await tempFile.delete();

    final existingBook = md5 != null ? await book_dao.bookDao.getBookByMd5(md5) : null;

    final book = Book(
      id: existingBook?.id ?? -1,
      title: existingBook?.title ?? title,
      coverPath: 'cover/$bookName',
      filePath: dbFilePath,
      lastReadPosition: '',
      readingPercentage: 0,
      author: existingBook?.author ?? '',
      isDeleted: false,
      rating: existingBook?.rating ?? 0.0,
      md5: md5,
      createTime: existingBook?.createTime ?? DateTime.now(),
      updateTime: DateTime.now(),
    );

    await book_dao.bookDao.insertBook(book);
  }
}
