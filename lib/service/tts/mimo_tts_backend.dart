import 'dart:convert';
import 'dart:typed_data';

import 'package:anx_reader/config/shared_preference_provider.dart';
import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/service/tts/models/tts_voice.dart';
import 'package:anx_reader/service/tts/tts_service.dart';
import 'package:anx_reader/service/tts/tts_service_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

class MimoTtsProvider extends TtsServiceProvider {
  static final MimoTtsProvider _instance = MimoTtsProvider._internal();

  factory MimoTtsProvider() {
    return _instance;
  }

  MimoTtsProvider._internal();

  static const String _defaultUrl =
      'https://token-plan-cn.xiaomimimo.com/v1/chat/completions';
  static const String _defaultModel = 'mimo-v2.5-tts';

  @override
  TtsService get service => TtsService.mimo;

  @override
  String getLabel(BuildContext context) => 'MiMo TTS';

  @override
  List<ConfigItem> getConfigItems(BuildContext context) {
    return [
      ConfigItem(
        key: 'tip',
        label: '说明',
        type: ConfigItemType.tip,
        defaultValue: '小米 MiMo TTS 服务，请填入 API Key 和模型名称。',
        link: '',
      ),
      ConfigItem(
        key: 'url',
        label: 'API URL',
        description: 'MiMo API 的完整地址',
        type: ConfigItemType.text,
        defaultValue: _defaultUrl,
      ),
      ConfigItem(
        key: 'key',
        label: 'API Key',
        description: '小米 MiMo API Key',
        type: ConfigItemType.password,
        defaultValue: '',
      ),
      ConfigItem(
        key: 'model',
        label: 'Model',
        description: 'TTS 模型名称',
        type: ConfigItemType.text,
        defaultValue: _defaultModel,
      ),
    ];
  }

  @override
  Map<String, dynamic> getConfig() {
    final config = Prefs().getOnlineTtsConfig(serviceId);
    if (config.isEmpty) {
      return {
        'url': _defaultUrl,
        'key': '',
        'model': _defaultModel,
      };
    }
    return {
      'url': config['url'] ?? _defaultUrl,
      'key': config['key'] ?? '',
      'model': config['model'] ?? _defaultModel,
    };
  }

  @override
  void saveConfig(Map<String, dynamic> config) {
    Prefs().saveOnlineTtsConfig(serviceId, config);
  }

  @override
  Future<Uint8List> speak(
      String text, String? voice, double rate, double pitch) async {
    final config = getConfig();
    final String url = config['url']?.toString().trim() ?? _defaultUrl;
    final String? key = config['key']?.toString();
    final String model = config['model']?.toString().trim() ?? _defaultModel;

    if (key == null || key.isEmpty) {
      throw Exception('MiMo TTS config missing (key)');
    }

    // 构建 instructions
    final instructions = _buildInstructions(rate, pitch);

    // MiMo TTS 使用 chat completions 格式，需要 assistant role
    final messages = [
      {'role': 'user', 'content': instructions},
      {'role': 'assistant', 'content': text},
    ];

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
      }),
    );

    if (response.statusCode == 200) {
      // 尝试解析 JSON 响应，提取音频数据
      final jsonResponse = jsonDecode(response.body);

      // 检查是否有 choices
      if (jsonResponse['choices'] != null &&
          jsonResponse['choices'].isNotEmpty) {
        final choice = jsonResponse['choices'][0];
        final message = choice['message'];

        // 如果 message 中有 audio 字段（可能是 base64 编码的音频）
        if (message != null && message['audio'] != null) {
          final audioData = message['audio'];
          if (audioData is String) {
            // base64 解码
            return base64Decode(audioData);
          } else if (audioData is Map && audioData['data'] != null) {
            return base64Decode(audioData['data']);
          }
        }

        // 如果 content 是音频 URL 或 base64
        if (message != null && message['content'] != null) {
          final content = message['content'].toString();
          // 检查是否是 base64
          if (content.length > 100 && !content.startsWith('http')) {
            try {
              return base64Decode(content);
            } catch (_) {}
          }
        }
      }

      // 如果无法解析，返回整个响应体让用户看到错误
      throw Exception(
          'MiMo TTS: 无法解析响应格式。Response: ${response.body.substring(0, 200)}');
    }

    throw Exception(
        'MiMo TTS failed: ${response.statusCode} ${response.body}');
  }

  String _buildInstructions(double rate, double pitch) {
    final buffer = StringBuffer();
    buffer.writeln('请用自然流畅的语调朗读以下文本。');
    if (rate != 1.0) {
      buffer.writeln('语速: ${rate.toStringAsFixed(1)}倍速');
    }
    if (pitch != 1.0) {
      buffer.writeln('音调: ${pitch.toStringAsFixed(1)}倍');
    }
    return buffer.toString().trim();
  }

  @override
  Future<List<TtsVoice>> getVoices() async {
    // MiMo TTS 可能不需要指定 voice，返回一个默认的
    return const [
      TtsVoice(shortName: 'default', name: 'Default', locale: 'zh-CN'),
    ];
  }

  @override
  TtsVoice convertVoiceModel(dynamic voiceData) {
    if (voiceData is TtsVoice) return voiceData;
    if (voiceData is Map<String, dynamic>) {
      return TtsVoice.fromMap(voiceData);
    }
    return const TtsVoice(shortName: 'default', name: 'Default', locale: 'zh-CN');
  }

  @override
  String getSelectedVoice() {
    return 'default';
  }

  @override
  void setSelectedVoice(String voice) {
    // MiMo 不需要设置 voice
  }
}
