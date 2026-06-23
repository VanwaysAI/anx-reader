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
  static const String _defaultVoice = 'mimo_default';

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
        defaultValue: '小米 MiMo TTS 服务。支持预置音色和风格控制。',
        link: 'https://mimo.mi.com/docs/zh-CN/quick-start/usage-guide/audio/speech-synthesis-v2.5',
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
      ConfigItem(
        key: 'voice',
        label: 'Voice',
        description: '预置音色名称',
        type: ConfigItemType.text,
        defaultValue: _defaultVoice,
      ),
      ConfigItem(
        key: 'instructions',
        label: 'Instructions',
        description: '语音风格指令（可选，如：语速、情绪、音色等）',
        type: ConfigItemType.text,
        defaultValue: '',
      ),
      ConfigItem(
        key: 'reading_mode',
        label: '朗读模式',
        description: '逐句模式：每次朗读一句，高亮精准；段落模式：合并多句朗读，更自然',
        type: ConfigItemType.select,
        defaultValue: 'sentence',
        options: [
          {'value': 'sentence', 'label': '逐句朗读'},
          {'value': 'paragraph', 'label': '段落朗读'},
        ],
      ),
      ConfigItem(
        key: 'paragraph_sentences',
        label: '段落句子数',
        description: '段落模式下每次合并的句子数量（2-10）',
        type: ConfigItemType.number,
        defaultValue: '5',
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
        'voice': _defaultVoice,
        'instructions': '',
      };
    }
    return {
      'url': config['url'] ?? _defaultUrl,
      'key': config['key'] ?? '',
      'model': config['model'] ?? _defaultModel,
      'voice': config['voice'] ?? _defaultVoice,
      'instructions': config['instructions'] ?? '',
      'reading_mode': config['reading_mode'] ?? 'sentence',
      'paragraph_sentences': config['paragraph_sentences'] ?? '5',
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
    final String resolvedVoice = resolveVoice(voice);
    final String? instructions = config['instructions']?.toString();

    if (key == null || key.isEmpty) {
      throw Exception('MiMo TTS config missing (key)');
    }

    // 构建 user 消息（风格指令）
    final userContent = _buildUserContent(instructions, rate, pitch);

    // 构建请求体
    final body = {
      'model': model,
      'audio': {'voice': resolvedVoice},
      'messages': [
        if (userContent.isNotEmpty)
          {'role': 'user', 'content': userContent},
        {'role': 'assistant', 'content': text},
      ],
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
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
          'MiMo TTS: 无法解析响应格式。Response: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
    }

    throw Exception(
        'MiMo TTS failed: ${response.statusCode} ${response.body}');
  }

  String _buildUserContent(
      String? instructions, double rate, double pitch) {
    final buffer = StringBuffer();
    if (instructions != null && instructions.trim().isNotEmpty) {
      buffer.writeln(instructions.trim());
    }
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
    // 根据小米文档返回预置音色列表
    return const [
      TtsVoice(
          shortName: 'mimo_default',
          name: 'MiMo-默认',
          locale: 'zh-CN',
          gender: 'unknown'),
      TtsVoice(
          shortName: '冰糖',
          name: '冰糖',
          locale: 'zh-CN',
          gender: 'female'),
      TtsVoice(
          shortName: '茉莉',
          name: '茉莉',
          locale: 'zh-CN',
          gender: 'female'),
      TtsVoice(
          shortName: '苏打',
          name: '苏打',
          locale: 'zh-CN',
          gender: 'male'),
      TtsVoice(
          shortName: '白桦',
          name: '白桦',
          locale: 'zh-CN',
          gender: 'male'),
      TtsVoice(
          shortName: 'Mia',
          name: 'Mia',
          locale: 'en-US',
          gender: 'female'),
      TtsVoice(
          shortName: 'Chloe',
          name: 'Chloe',
          locale: 'en-US',
          gender: 'female'),
      TtsVoice(
          shortName: 'Milo',
          name: 'Milo',
          locale: 'en-US',
          gender: 'male'),
      TtsVoice(
          shortName: 'Dean',
          name: 'Dean',
          locale: 'en-US',
          gender: 'male'),
    ];
  }

  @override
  TtsVoice convertVoiceModel(dynamic voiceData) {
    if (voiceData is TtsVoice) return voiceData;
    if (voiceData is Map<String, dynamic>) {
      return TtsVoice.fromMap(voiceData);
    }
    return const TtsVoice(
        shortName: 'mimo_default',
        name: 'MiMo-默认',
        locale: 'zh-CN',
        gender: 'unknown');
  }

  @override
  String getSelectedVoice() {
    final config = getConfig();
    final voice = config['voice']?.toString() ?? '';
    if (voice.isNotEmpty) return voice;
    return _defaultVoice;
  }

  @override
  void setSelectedVoice(String voice) {
    final config = getConfig();
    config['voice'] = voice;
    saveConfig(config);
  }
}
