import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _initialized = false;

  static void init() {
    if (!_initialized) {
      _player.setReleaseMode(ReleaseMode.stop);
      _player.setVolume(1.0);
      _initialized = true;
    }
  }

  /// Plays the crisp barcode scan beep and triggers haptic feedback
  static Future<void> playScanBeep() async {
    // 1. Tactile physical haptic feedback (works even if phone is muted)
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}

    // 2. Audio beep
    try {
      init();
      await _player.stop();
      await _player.play(AssetSource('audio/beep.wav'));
    } catch (_) {}
  }

  /// Error or alert tone for invalid action
  static Future<void> playAlertBeep() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}
