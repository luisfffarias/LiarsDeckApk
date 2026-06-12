import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:liarsDeck/data/services/profile_service.dart';
import 'package:liarsDeck/data/services/music_service.dart';
import 'package:liarsDeck/presentation/pages/ranking_page.dart';
import 'queue_page.dart';
import 'profile_page.dart';
import 'auth_page.dart';

class LobbyPage extends StatefulWidget {
  final String nickname;

  const LobbyPage({super.key, required this.nickname});

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  final UserService _userService = UserService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String currentAvatar = 'default.png';
  String displayNickname = '';
  int userCoins = 0;
  bool isLoading = true;

  // --- CONTROLES DE ÁUDIO E CONFIGURAÇÕES ---
  bool showSettings = false;
  double audioVolume = 0.5; // 50% de volume inicial
  bool isMuted = false;

  @override
  void initState() {
    super.initState();
    displayNickname = widget.nickname;
    _loadUserData();
    _startBackgroundMusic();
  }

  void _startBackgroundMusic() {
    print("🎯 Chamando playMusic() do LobbyPage");
    MusicService().playMusic();
  }

  Future<void> _loadUserData() async {
    try {
      final String? token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        final data = await _userService.fetchUserProfile(token);
        setState(() {
          currentAvatar = data['avatar'] ?? 'default.png';
          displayNickname = data['nickname'] ?? widget.nickname;

          userCoins = data['coins'] != null
              ? int.tryParse(data['coins'].toString()) ?? 0
              : 0;

          isLoading = false;
        });
      }
    } catch (e) {
      print('Erro ao carregar dados do usuário no menu: $e');
      setState(() => isLoading = false);
    }
  }

  // Função para aplicar o volume (integrada com o MusicService)
  void _applyAudioSettings() {
    double finalVolume = isMuted ? 0.0 : audioVolume;
    MusicService().setVolume(finalVolume);
    print('🔊 Volume aplicado: ${(finalVolume * 100).toInt()}%');
  }

  @override
  void dispose() {
    // A música continua tocando entre as telas do menu
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // 👇 IMPLEMENTADO: Força o Stack a preencher toda a tela
      body: SizedBox.expand(
        child: Stack(
          children: [
            // 1. FUNDO
            Positioned.fill(
              child: Image.network(
                'https://www.shutterstock.com/image-photo/empty-wooden-bar-counter-defocused-600nw-2558943755.jpg',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.4),
              ),
            ),

            // 2. INTERFACE PRINCIPAL
            SafeArea(
              child: SingleChildScrollView(
                // Padding dinâmico para telas muito pequenas
                padding: EdgeInsets.all(
                    MediaQuery.of(context).size.width > 360 ? 24.0 : 16.0),
                // 👇 IMPLEMENTADO: Garante que o conteúdo estique horizontalmente
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      // BARRA SUPERIOR
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          _buildProfileHeader(),
                          _buildTopRightMenu(),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // CORPO PRINCIPAL
                      Wrap(
                        spacing: 40,
                        runSpacing: 40,
                        alignment: WrapAlignment.center,
                        children: [
                          // MENU ESQUERDO
                          Container(
                            constraints: const BoxConstraints(maxWidth: 320),
                            width: double.infinity, // Ocupa o máximo até 320px
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment
                                  .stretch, // Estica os botões
                              children: [
                                MenuButton(
                                  icon: Icons.style,
                                  title: 'JOGAR',
                                  subtitle: 'Entre em uma partida online',
                                  isActive: true,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => QueuePage(
                                            nickname: displayNickname),
                                      ),
                                    ).then((_) => _loadUserData());
                                  },
                                ),
                                const SizedBox(height: 12),
                                MenuButton(
                                  icon: Icons.badge,
                                  title: 'PERFIL',
                                  subtitle: 'Seu progresso e estatísticas',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ProfileUserPage(),
                                      ),
                                    ).then((_) {
                                      _loadUserData();
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                MenuButton(
                                  icon: Icons.leaderboard,
                                  title: 'LIARS KINGS',
                                  subtitle: 'Os melhores na mesa',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const RankingPage(),
                                      ),
                                    ).then((_) {
                                      _loadUserData();
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                MenuButton(
                                  icon: Icons.exit_to_app,
                                  title: 'SAIR',
                                  subtitle: 'Sair da taverna',
                                  onTap: () async {
                                    setState(() => isLoading = true);
                                    await _storage.delete(key: 'jwt_token');
                                    if (context.mounted) {
                                      await MusicService().stopMusic();
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const AuthPage()),
                                        (Route<dynamic> route) => false,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),

                          // PAINEL DIREITO
                          Container(
                            constraints: const BoxConstraints(maxWidth: 300),
                            width: double.infinity, // Ocupa o máximo até 300px
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment
                                  .stretch, // Estica os painéis
                              children: [
                                _buildRightPanel(
                                    'DESAFIO SEMANAL',
                                    'Vença 10 partidas',
                                    'Recompensa: 500 coins'),
                                const SizedBox(height: 12),
                                _buildRightPanel('PASSE DE BAR', 'Em breve',
                                    'Ver recompensas'),
                              ],
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. CAMADA DE CONFIGURAÇÕES (OVERLAY)
            if (showSettings) _buildSettingsOverlay(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // OVERLAY DE CONFIGURAÇÕES
  // ==========================================
  Widget _buildSettingsOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            margin: const EdgeInsets.symmetric(horizontal: 16), // Margem segura
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.amber.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.settings, color: Colors.amber),
                        SizedBox(width: 8),
                        Text(
                          'OPÇÕES',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            fontFamily: 'Georgia',
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      onPressed: () {
                        setState(() {
                          showSettings = false;
                        });
                      },
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isMuted ? 'ÁUDIO MUTADO' : 'ÁUDIO ATIVADO',
                      style: TextStyle(
                        color: isMuted ? Colors.redAccent : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Switch(
                      value: !isMuted,
                      activeColor: Colors.amber,
                      inactiveThumbColor: Colors.redAccent,
                      inactiveTrackColor: Colors.red.withOpacity(0.3),
                      onChanged: (value) {
                        setState(() {
                          isMuted = !value;
                          _applyAudioSettings();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Opacity(
                  opacity: isMuted ? 0.3 : 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'VOLUME MUSICAL',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            '${(audioVolume * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.amber,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.amberAccent,
                          overlayColor: Colors.amber.withOpacity(0.2),
                          trackHeight: 6.0,
                        ),
                        child: Slider(
                          value: audioVolume,
                          min: 0.0,
                          max: 1.0,
                          onChanged: isMuted
                              ? null
                              : (value) {
                                  setState(() {
                                    audioVolume = value;
                                    _applyAudioSettings();
                                  });
                                },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black54,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        )),
                    onPressed: () => setState(() => showSettings = false),
                    child: const Text('FECHAR',
                        style: TextStyle(color: Colors.white)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // COMPONENTES COM FONTES NATIVAS
  // ==========================================

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey[900],
            backgroundImage: AssetImage('assets/images/avatar/$currentAvatar'),
            child: isLoading
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.amber))
                : null,
          ),
          const SizedBox(width: 12),
          // Uso do Flexible para previnir overflow de textos longos
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayNickname,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 1.5,
                    fontFamily: 'Georgia',
                    shadows: [
                      Shadow(color: Colors.amber, blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTopRightMenu() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildCurrencyInfo(
            Icons.monetization_on, userCoins.toString(), Colors.amber),
        _buildCurrencyInfo(Icons.diamond, '240', Colors.redAccent),
        const Icon(Icons.mail, color: Colors.white70),
        GestureDetector(
          onTap: () {
            setState(() {
              showSettings = true;
            });
          },
          child: const MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Icon(Icons.settings, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencyInfo(IconData icon, String value, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 16,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanel(String header, String title, String subtitle) {
    return Container(
      // Removido width: double.infinity
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            header,
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// MENU BUTTON COM FONTES NATIVAS
// ==========================================
class MenuButton extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isActive;
  final VoidCallback onTap;

  const MenuButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isActive = false,
    required this.onTap,
  });

  @override
  State<MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<MenuButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color borderColor =
        widget.isActive ? Colors.redAccent : Colors.white24;
    final Color titleColor = widget.isActive ? Colors.white : Colors.white70;
    final List<BoxShadow>? glowEffect = widget.isActive
        ? [
            BoxShadow(
                color: Colors.redAccent.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 2)
          ]
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          // Removido width: double.infinity
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isHovered
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isHovered ? Colors.white54 : borderColor,
                width: widget.isActive ? 2 : 1),
            boxShadow: glowEffect,
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: Colors.amberAccent, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontFamily: 'Georgia',
                        shadows: widget.isActive
                            ? [
                                const Shadow(
                                    color: Colors.redAccent, blurRadius: 8)
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
