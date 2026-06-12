import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// Ajuste o caminho do import conforme a estrutura de pastas do seu projeto:
import 'package:liarsDeck/data/services/profile_service.dart';

class ProfileUserPage extends StatefulWidget {
  const ProfileUserPage({Key? key}) : super(key: key);

  @override
  State<ProfileUserPage> createState() => _ProfileUserPageState();
}

class _ProfileUserPageState extends State<ProfileUserPage> {
  final UserService _userService = UserService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Map<String, dynamic>? userData;
  bool isLoading = true;
  String errorMessage = '';

  // Lista dos avatares exata da sua pasta assets/images/avatar/
  final List<String> availableAvatars = [
    'default.png',
    'joker.png',
    'user1.png',
    'user2.png',
    'user3.png',
    'user4.png',
    'user5.png',
    'user6.png',
    'user7.png',
    'user8.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final String? token = await _storage.read(key: 'jwt_token');

      if (token == null) {
        setState(() {
          errorMessage =
              'Token não encontrado. Por favor, faça login novamente.';
          isLoading = false;
        });
        return;
      }

      final data = await _userService.fetchUserProfile(token);

      setState(() {
        userData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
        isLoading = false;
      });
    }
  }

  // Função para abrir o menu e trocar o avatar
  void _showAvatarSelectionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9), // Ajustado para o tema
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Colors.white12, width: 1), // Borda sutil
      ),
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ESCOLHA SEU ARQUÉTIPO',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: availableAvatars.map((avatarFile) {
                    final isSelected = userData!['avatar'] == avatarFile;

                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(context); // Fecha o menu
                        await _changeAvatar(avatarFile);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.redAccent
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [
                                  const BoxShadow(
                                      color: Colors.redAccent, blurRadius: 10)
                                ]
                              : [],
                        ),
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.grey[900],
                          backgroundImage:
                              AssetImage('assets/images/avatar/$avatarFile'),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _changeAvatar(String newAvatarName) async {
    setState(() => isLoading = true);

    try {
      final String? token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        await _userService.updateUserAvatar(token, newAvatarName);
        setState(() {
          userData!['avatar'] = newAvatarName;
        });
      }
    } catch (e) {
      print('💀 ERRO NO PATCH DO AVATAR: $e , Avatar name: $newAvatarName');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar:
          true, // Garante que a imagem de fundo cubra o topo
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'PERFIL DO JOGADOR',
          style: TextStyle(
              color: Colors.white,
              letterSpacing: 2,
              fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SizedBox.expand(
        child: Stack(
          children: [
            // 1. CAMADA DE FUNDO (A mesma da LobbyPage)
            Positioned.fill(
              child: Image.network(
                'https://www.shutterstock.com/image-photo/empty-wooden-bar-counter-defocused-600nw-2558943755.jpg',
                fit: BoxFit.cover,
              ),
            ),

            // Camada escura para dar contraste
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(
                    0.6), // Um pouco mais escuro para ler melhor os textos do perfil
              ),
            ),

            // 2. CAMADA DA INTERFACE
            SafeArea(
              child: _buildBodyState(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyState() {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.amber));
    }
    if (errorMessage.isNotEmpty) {
      return _buildErrorState();
    }
    return _buildProfileContent();
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: const TextStyle(color: Colors.redAccent, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = '';
                });
                _loadUserProfile();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Tentar Novamente',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            if (errorMessage.contains('Sessão expirada') ||
                errorMessage.contains('Token não encontrado'))
              OutlinedButton(
                onPressed: () {
                  _storage.delete(key: 'jwt_token');
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/auth', (route) => false);
                },
                style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent)),
                child: const Text('Voltar para o Login',
                    style: TextStyle(color: Colors.redAccent)),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent() {
    final String currentAvatar = userData?['avatar'] ?? 'default.png';
    // 👇 IMPLEMENTADO: Extração segura das moedas da API
    final String userCoins = userData?['coins']?.toString() ?? '0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Grupo do Avatar com botão de edição
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.black.withOpacity(0.5),
                  backgroundImage:
                      AssetImage('assets/images/avatar/$currentAvatar'),
                ),
              ),
              GestureDetector(
                onTap: _showAvatarSelectionModal,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ]),
                  child: const Icon(Icons.edit, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            userData!['nickname'].toString().toUpperCase(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Membro desde ${DateTime.parse(userData!['createdAt']).year}',
            style: TextStyle(
              color: Colors.amber[700],
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
          ),

          // 👇 IMPLEMENTADO: Exibição das moedas do usuário
          const SizedBox(height: 16),
          _buildCurrencyInfo(Icons.monetization_on, userCoins, Colors.amber),

          const SizedBox(height: 40), // Ajustado o espaçamento
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ESTATÍSTICAS DA MESA',
              style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard(
                  'Vitórias', userData!['wins'].toString(), Colors.greenAccent),
              _buildStatCard(
                  'Derrotas', userData!['losses'].toString(), Colors.redAccent),
              _buildStatCard(
                  'Win Rate', '${userData!['winRate']}%', Colors.amberAccent),
            ],
          ),
        ],
      ),
    );
  }

  // 👇 IMPLEMENTADO: Componente visual da moeda (mesmo estilo da LobbyPage)
  Widget _buildCurrencyInfo(IconData icon, String value, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
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

  // Atualizado para o estilo translúcido com bordas do Lobby
  Widget _buildStatCard(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12), // Mesma borda da LobbyPage
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                  shadows: [
                    Shadow(
                      color: valueColor.withOpacity(0.5),
                      blurRadius: 10,
                    )
                  ]),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0)),
          ],
        ),
      ),
    );
  }
}
