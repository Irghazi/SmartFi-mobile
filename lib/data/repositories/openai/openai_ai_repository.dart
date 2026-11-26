import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/ai_config.dart';
import '../../../core/config/ai_prompts.dart';
import '../../../core/services/ai_topic_guard.dart';
import '../../../features/ai_advisor/models/chat_message.dart';
import '../ai_repository.dart';

class _RawHttpResult {
  final int statusCode;
  final String body;

  const _RawHttpResult(this.statusCode, this.body);
}

class OpenAiAiRepository implements AiRepository {
  static const MethodChannel _httpChannel = MethodChannel('com.smartfi.mobile/http');

  final http.Client? _customClient;

  OpenAiAiRepository({http.Client? client}) : _customClient = client;

  String get _endpoint {
    String base = AiConfig.baseUrl.trim();
    if (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return '$base/chat/completions';
  }

  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${AiConfig.apiKey.trim()}',
      'Connection': 'close',
    };
  }

  /// Mengirim HTTP POST JSON menggunakan stack jaringan native Android (`HttpURLConnection`)
  /// agar stabil di Wi-Fi maupun 4G/seluler tanpa terganggu socket stall / IPv6 Dart `HttpClient`.
  /// Otomatis fallback ke `http.Client` pada test atau platform non-Android.
  Future<_RawHttpResult> _postJson({
    required Map<String, dynamic> payload,
    required Duration timeout,
  }) async {
    final encodedBody = jsonEncode(payload);

    if (_customClient == null && !kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final nativeRes = await _httpChannel
            .invokeMapMethod<String, dynamic>('postJson', {
              'url': _endpoint,
              'body': encodedBody,
              'headers': {
                'Authorization': 'Bearer ${AiConfig.apiKey.trim()}',
                'User-Agent': 'SmartFi-Mobile/1.0',
              },
              'timeoutMs': timeout.inMilliseconds,
            })
            .timeout(timeout + const Duration(seconds: 3));

        if (nativeRes != null) {
          final code = (nativeRes['statusCode'] as num?)?.toInt() ?? 500;
          final body = (nativeRes['body'] as String?) ?? '';
          return _RawHttpResult(code, body);
        }
      } on MissingPluginException {
        // Fallback ke Dart http.Client pada unit test
      } on PlatformException catch (e) {
        if (e.code == 'TIMEOUT') {
          throw TimeoutException(e.message ?? 'Timeout menghubungi server AI.');
        }
        throw SocketException(e.message ?? 'Gagal terhubung ke server AI.');
      }
    }

    final client = _customClient ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse(_endpoint),
            headers: _headers,
            body: encodedBody,
          )
          .timeout(timeout);
      return _RawHttpResult(response.statusCode, utf8.decode(response.bodyBytes));
    } finally {
      if (_customClient == null) {
        client.close();
      }
    }
  }

  @override
  Future<String> askMentor({
    required String message,
    required List<ChatMessage> history,
    required String financialContextJson,
  }) async {
    // Lapisan 1: Pre-filter input (blokir permintaan kode, prompt injection, dan topik luar keuangan)
    final refusal = AiTopicGuard.validateUserInput(message);
    if (refusal != null) {
      return refusal;
    }

    if (!AiConfig.hasApiKey) {
      throw const SocketException('API Key belum diisi pada env.json.');
    }

    // Batasi histori 8 pesan terakhir agar token & waktu respon tetap efisien
    final recentHistory = history.length > 8 ? history.sublist(history.length - 8) : history;

    // Hindari duplikasi jika pesan pengguna terakhir sudah ada di history
    final historyList = List<ChatMessage>.from(recentHistory);
    final bool alreadyEndsWithCurrent = historyList.isNotEmpty &&
        historyList.last.isUser &&
        historyList.last.content.trim() == message.trim();

    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': AiPrompts.getMentorSystemPrompt(financialContextJson),
      },
      ...historyList.map((m) => {
            'role': m.isUser ? 'user' : 'assistant',
            'content': m.content,
          }),
      if (!alreadyEndsWithCurrent)
        {
          'role': 'user',
          'content': message,
        },
    ];

    try {
      final res = await _postJson(
        payload: {
          'model': AiConfig.model,
          'messages': messages,
          'temperature': 0.3,
          'max_tokens': 800,
        },
        timeout: const Duration(seconds: 30),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final content = choices[0]['message']['content'] as String? ?? '';
          // Lapisan 3: Post-filter output (cegah kebocoran kode + hapus emoji)
          return AiTopicGuard.sanitizeAndGuardOutput(content);
        }
        return 'Maaf, AI tidak memberikan jawaban. Silakan coba kembali.';
      } else if (res.statusCode == 401) {
        throw const HttpException('Kunci API tidak valid atau belum diatur (Error 401). Silakan periksa konfigurasi env.json.');
      } else if (res.statusCode == 429) {
        throw const HttpException('Maaf, antrean server AI sedang penuh atau kuota habis (Error 429). Mohon tunggu sekitar satu menit lalu coba lagi.');
      } else {
        throw HttpException(_extractErrorDetail(res.statusCode, res.body));
      }
    } on TimeoutException {
      throw const SocketException('Permintaan ke server AI melebihi batas waktu (Timeout). Periksa koneksi internetmu lalu ketuk Coba Lagi.');
    } on SocketException catch (e) {
      if (e.message.contains('API Key')) rethrow;
      throw const SocketException('Gagal terhubung ke server AI. Pastikan internet HP aktif lalu ketuk Coba Lagi.');
    } on http.ClientException {
      throw const SocketException('Jaringan terputus saat menghubungi AI. Mohon periksa internet Anda.');
    }
  }

  @override
  Future<Map<String, dynamic>> parseSmartInput({
    required String prompt,
    required List<String> categories,
  }) async {
    if (!AiConfig.hasApiKey) {
      throw const SocketException('API Key belum diisi pada env.json.');
    }

    final messages = [
      {
        'role': 'system',
        'content': AiPrompts.getSmartInputSystemPrompt(categories),
      },
      {
        'role': 'user',
        'content': prompt,
      },
    ];

    try {
      final bodyPayload = <String, dynamic>{
        'model': AiConfig.model,
        'messages': messages,
        'temperature': 0.1,
        'response_format': {'type': 'json_object'},
      };

      var res = await _postJson(
        payload: bodyPayload,
        timeout: const Duration(seconds: 12),
      );

      // Jika server mengembalikan 400 (beberapa provider tidak mendukung response_format), coba ulang tanpa response_format
      if (res.statusCode == 400) {
        bodyPayload.remove('response_format');
        res = await _postJson(
          payload: bodyPayload,
          timeout: const Duration(seconds: 12),
        );
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final content = choices[0]['message']['content'] as String? ?? '';
          return _cleanAndParseJson(content);
        }
      } else if (res.statusCode == 401) {
        throw const HttpException('Kunci API tidak valid (401).');
      } else if (res.statusCode == 429) {
        throw const HttpException('Antrean server AI penuh (429).');
      }
      throw HttpException(_extractErrorDetail(res.statusCode, res.body));
    } on TimeoutException {
      throw const SocketException('Waktu parsing AI habis.');
    } on FormatException catch (e) {
      throw HttpException('Format data AI tidak sesuai: ${e.message}');
    } on SocketException catch (e) {
      if (e.message.contains('API Key')) rethrow;
      throw const SocketException('Gagal terhubung ke server AI.');
    } on http.ClientException {
      throw const SocketException('Jaringan terputus saat menghubungi AI.');
    }
  }

  String _extractErrorDetail(int statusCode, String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        final err = decoded['error'];
        if (err is Map<String, dynamic> && err['message'] != null) {
          return 'Server AI error ($statusCode): ${err['message']}';
        }
        if (decoded['message'] != null) {
          return 'Server AI error ($statusCode): ${decoded['message']}';
        }
      }
    } catch (_) {}
    return 'Server AI merespons dengan status error: $statusCode';
  }

  Map<String, dynamic> _cleanAndParseJson(String content) {
    try {
      String clean = content
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();
      final start = clean.indexOf('{');
      final end = clean.lastIndexOf('}');
      if (start != -1 && end != -1 && end >= start) {
        clean = clean.substring(start, end + 1);
      }
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Gagal memproses JSON: $e');
    }
  }
}
