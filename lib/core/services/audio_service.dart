import 'package:audioplayers/audioplayers.dart';

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

  /// Plays the crisp barcode scan beep
  static Future<void> playScanBeep() async {
    try {
      init();
      await _player.stop();
      await _player.play(AssetSource('audio/beep.wav'));
    } catch (_) {
      // Audio playback fails silently without crashing if hardware is unavailable
    }
  }
}
