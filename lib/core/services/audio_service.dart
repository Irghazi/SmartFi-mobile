import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _clickPlayer = AudioPlayer();
  final AudioPlayer _chatPlayer = AudioPlayer();

  bool _isClickMuted = false;
  bool _isAiMuted = false;

  bool get isClickMuted => _isClickMuted;
  bool get isAiMuted => _isAiMuted;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isClickMuted = prefs.getBool('smartfi_mute_click') ?? false;
      _isAiMuted = prefs.getBool('smartfi_mute_ai') ?? false;
      await _clickPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _chatPlayer.setPlayerMode(PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('Error init AudioService: $e');
    }
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

  Future<void> playClickSound() async {
    if (_isClickMuted) return;
    try {
      await _clickPlayer.stop();
      await _clickPlayer.play(AssetSource('sounds/click.mp3'));
    } catch (e) {
      debugPrint('Gagal memutar audio klik: $e');
    }
  }

  Future<void> playChatSound() async {
    if (_isAiMuted) return;
    try {
      await _chatPlayer.stop();
      await _chatPlayer.play(AssetSource('sounds/chat.mp3'));
    } catch (e) {
      debugPrint('Gagal memutar audio chat: $e');
    }
  }
}

