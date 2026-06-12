// lib/data/services/sound_service.dart
import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  bool _isInitialized = false;
  bool isSfxEnabled = true;

  DateTime? _lastHoverPlay;
  static const _hoverCooldown = Duration(milliseconds: 90);

  Future<void> _init() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  void enableAudio() {
    isSfxEnabled = true;
    print("🎵 Efeitos Sonoros (SFX) ativados!");
  }

  void toggleSfx(bool value) {
    isSfxEnabled = value;
  }

  Future<void> playHoverSound() async {
    if (!isSfxEnabled) return; // Só toca se a chave de SFX estiver ligada

    final now = DateTime.now();
    if (_lastHoverPlay != null &&
        now.difference(_lastHoverPlay!) < _hoverCooldown) {
      return;
    }
    _lastHoverPlay = now;

    await _init();
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.setSource(AssetSource("audio/card-slide-6.ogg"));
      await _sfxPlayer.resume();
    } catch (e) {
      if (e.toString().contains('AbortError')) return;
      print("❌ Erro ao tocar som: $e");
    }
  }

  void setVolume(double volume) {
    try {
      _sfxPlayer.setVolume(volume);
    } catch (e) {
      print("❌ Erro ao ajustar volume: $e");
    }
  }
}
