import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  static const MethodChannel _sfxChannel = MethodChannel('com.smartfi.mobile/sfx');

  AudioPlayer? _clickPlayer;
  AudioPlayer? _chatPlayer;
  DateTime? _lastClickPlayedAt;

  bool _isClickMuted = false;
  bool _isAiMuted = false;

  bool get isClickMuted => _isClickMuted;
  bool get isAiMuted => _isAiMuted;

  static final AudioContext _sfxAudioContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isClickMuted = prefs.getBool('smartfi_mute_click') ?? false;
      _isAiMuted = prefs.getBool('smartfi_mute_ai') ?? false;
    } catch (e) {
      debugPrint('Error init AudioService: $e');
    }
  }

  Future<AudioPlayer> _ensureFallbackPlayer({required bool isClick}) async {
    final existing = isClick ? _clickPlayer : _chatPlayer;
    if (existing != null) return existing;

    final player = AudioPlayer();
    await player.setAudioContext(_sfxAudioContext);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setPlayerMode(PlayerMode.mediaPlayer);
    if (isClick) {
      _clickPlayer = player;
    } else {
      _chatPlayer = player;
    }
    return player;
  }

  Future<void> setClickMuted(bool value) async {
    _isClickMuted = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('smartfi_mute_click', value);
  }

  Future<void> setAiMuted(bool value) async {
    _isAiMuted = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('smartfi_mute_ai', value);
  }

  void playClickSound() {
    if (_isClickMuted) return;

    // Cegah suara ganda dalam jeda sangat singkat (<35ms)
    final now = DateTime.now();
    if (_lastClickPlayedAt != null &&
        now.difference(_lastClickPlayedAt!).inMilliseconds < 35) {
      return;
    }
    _lastClickPlayedAt = now;

    unawaited(_playNativeOrFallback(isClick: true));
  }

  void playChatSound() {
    if (_isAiMuted) return;
    unawaited(_playNativeOrFallback(isClick: false));
  }

  Future<void> _playNativeOrFallback({required bool isClick}) async {
    try {
      final played = await _sfxChannel.invokeMethod<bool>(
        isClick ? 'playClick' : 'playChat',
      );
      if (played == true) return;
    } on MissingPluginException {
      // Aman pada unit test atau platform non-Android
    } catch (e) {
      debugPrint('Native SoundPool fallback: $e');
    }

    // Fallback menggunakan MediaPlayer dengan AudioFocus.none & USAGE_MEDIA
    try {
      final player = await _ensureFallbackPlayer(isClick: isClick);
      await player.stop();
      await player.play(
        AssetSource(isClick ? 'sounds/click.mp3' : 'sounds/chat.mp3'),
      );
    } catch (e) {
      debugPrint('Gagal memutar audio fallback: $e');
    }
  }
}
