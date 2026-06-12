// lib/data/services/music_service.dart
import 'package:audioplayers/audioplayers.dart';

class MusicService {
  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;
  MusicService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;

  // 👇 Estado que a chavinha do Modal vai controlar
  bool isMusicEnabled = true;

  Future<void> init() async {
    if (_isInitialized) return;

    print("📀 Inicializando MusicService...");

    try {
      // Ajustado o caminho (sem a barra inicial) para o padrão do audioplayers
      await _player.setSource(AssetSource("audio/theme.mp3"));
      _player.setReleaseMode(ReleaseMode.loop);
      _isInitialized = true;
      print("✅ MusicService inicializado com theme.mp3");
    } catch (e) {
      print("❌ ERRO ao carregar áudio: $e");
    }
  }

  Future<void> playMusic() async {
    if (!isMusicEnabled) return; // Se a chave estiver desligada, não toca
    print("🎵 playMusic() chamado");
    await init();
    await _player.resume();
    print("🎵 Música deveria estar tocando agora");
  }

  Future<void> stopMusic() async {
    print("⏹️ stopMusic() chamado");
    await _player.stop();
  }

  // 👇 Nova função para ser chamada pelo Modal
  void toggleMusic(bool value) {
    isMusicEnabled = value;
    if (isMusicEnabled) {
      playMusic();
    } else {
      stopMusic();
    }
  }

  void setVolume(double volume) {
    print("🔊 Volume ajustado para: ${(volume * 100).toInt()}%");
    _player.setVolume(volume);
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
