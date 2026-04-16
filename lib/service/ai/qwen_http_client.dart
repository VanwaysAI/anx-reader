import 'dart:convert';
import 'dart:typed_data';

import 'package:anx_reader/utils/log/common.dart';
import 'package:http/http.dart' as http;

/// Custom HTTP client that injects enable_thinking=false into Qwen API requests
/// This is needed for Alibaba's Qwen models (like qwen3.6) to disable thinking mode
class QwenThinkingHttpClient extends http.BaseClient {
  QwenThinkingHttpClient(this._innerClient);

  final http.Client _innerClient;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Only modify chat completion POST requests
    if (request.method.toUpperCase() == 'POST' &&
        request.url.path.contains('chat/completions')) {
      try {
        // Read the request body
        final bodyBytes = await _readRequestBody(request);
        if (bodyBytes != null && bodyBytes.isNotEmpty) {
          final bodyStr = utf8.decode(bodyBytes);
          final body = json.decode(bodyStr) as Map<String, dynamic>;

          // Add enable_thinking=false for Qwen models
          body['enable_thinking'] = false;

          // Encode the modified body
          final newBodyBytes = utf8.encode(json.encode(body));

          // Create a completely new request with all original headers except Content-Length
          final newRequest = http.Request(request.method, request.url);
          newRequest.bodyBytes = Uint8List.fromList(newBodyBytes);

          // Copy headers, updating Content-Length
          for (final entry in request.headers.entries) {
            if (entry.key.toLowerCase() != 'content-length') {
              newRequest.headers[entry.key] = entry.value;
            }
          }
          newRequest.headers['Content-Length'] = newBodyBytes.length.toString();

          AnxLog.info(
            'QwenThinkingHttpClient: Injected enable_thinking=false, '
            'original size: ${bodyBytes.length}, new size: ${newBodyBytes.length}',
          );

          return _innerClient.send(newRequest);
        }
      } catch (e) {
        AnxLog.warning('QwenThinkingHttpClient: Failed to modify request: $e');
        // Fall back to original request on error
      }
    }

    return _innerClient.send(request);
  }

  Future<Uint8List?> _readRequestBody(http.BaseRequest request) async {
    if (request is http.Request) {
      // http.Request has bodyBytes property
      return request.bodyBytes;
    }
    return null;
  }

  @override
  void close() {
    _innerClient.close();
  }
}