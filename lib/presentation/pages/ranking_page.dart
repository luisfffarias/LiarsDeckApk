import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:liarsDeck/core/constants/api_constants.dart'; // Ajuste o import se necessário

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));

  List<dynamic> rankingData = [];
  bool isLoading = true;
  bool isCoinRanking = false; // false = Vitórias, true = Moedas

  @override
  void initState() {
    super.initState();
    _fetchRanking();
  }

  Future<void> _fetchRanking() async {
    setState(() => isLoading = true);
    try {
      final String? token = await _storage.read(key: 'jwt_token');
      if (token == null) throw Exception('Token não encontrado');

      // Alterna o endpoint com base no botão selecionado
      final endpoint = isCoinRanking ? 'user/ranking/coins' : 'user/ranking';

      final response = await _dio.get(
        endpoint,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      setState(() {
        rankingData = response.data;
        isLoading = false;
      });
    } catch (e) {
      print('Erro ao buscar ranking: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao carregar o ranking da taverna.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. FUNDO DA TAVERNA
          Positioned.fill(
            child: Image.network(
              'https://www.shutterstock.com/image-photo/empty-wooden-bar-counter-defocused-600nw-2558943755.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.6)),
          ),

          // 2. CONTEÚDO PRINCIPAL
          SafeArea(
            child: Column(
              children: [
                // APP BAR CUSTOMIZADA
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          "LIAR'S KINGS",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            fontFamily: 'Georgia',
                            shadows: [
                              Shadow(color: Colors.amberAccent, blurRadius: 10)
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(
                          width: 48), // Espaçamento para centralizar o título
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. TOGGLE DE SELEÇÃO (VITÓRIAS vs MOEDAS)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildToggleButton(
                          title: 'MAIS VITORIOSOS',
                          icon: Icons.emoji_events,
                          isSelected: !isCoinRanking,
                          onTap: () {
                            if (isCoinRanking) {
                              setState(() => isCoinRanking = false);
                              _fetchRanking();
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: _buildToggleButton(
                          title: 'MAIS RICOS',
                          icon: Icons.monetization_on,
                          isSelected: isCoinRanking,
                          onTap: () {
                            if (!isCoinRanking) {
                              setState(() => isCoinRanking = true);
                              _fetchRanking();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 4. LISTA DO RANKING
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.amber),
                        )
                      : rankingData.isEmpty
                          ? const Center(
                              child: Text(
                                'Nenhum jogador encontrado.',
                                style: TextStyle(color: Colors.white54),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              itemCount: rankingData.length,
                              itemBuilder: (context, index) {
                                final player = rankingData[index];
                                return _buildRankingCard(player, index);
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGETS AUXILIARES
  // ==========================================

  Widget _buildToggleButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red.shade900 : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: Colors.redAccent.withOpacity(0.5), blurRadius: 8)
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected ? Colors.amber : Colors.white54, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingCard(dynamic player, int index) {
    // Definindo cores para o Top 3
    Color rankColor;
    Color glowColor;
    if (index == 0) {
      rankColor = const Color(0xFFFFD700); // Ouro
      glowColor = Colors.amber.withOpacity(0.4);
    } else if (index == 1) {
      rankColor = const Color(0xFFC0C0C0); // Prata
      glowColor = Colors.white.withOpacity(0.2);
    } else if (index == 2) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      glowColor = Colors.orange.withOpacity(0.2);
    } else {
      rankColor = Colors.white54;
      glowColor = Colors.transparent;
    }

    final avatarPath = player['avatar']?.toString().contains('.png') == true
        ? player['avatar']
        : '${player['avatar'] ?? 'default'}.png'; // Prevenção contra erro de formato

    final mainStatValue = isCoinRanking ? player['coins'] : player['wins'];
    final mainStatLabel = isCoinRanking ? 'Moedas' : 'Vitórias';
    final mainStatIcon =
        isCoinRanking ? Icons.monetization_on : Icons.emoji_events;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: rankColor.withOpacity(index < 3 ? 0.8 : 0.2),
            width: index < 3 ? 2 : 1),
        boxShadow: [BoxShadow(color: glowColor, blurRadius: 10)],
      ),
      child: Row(
        children: [
          // Posição (Rank)
          SizedBox(
            width: 40,
            child: Text(
              '#${index + 1}',
              style: TextStyle(
                color: rankColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
                shadows: [Shadow(color: rankColor, blurRadius: 5)],
              ),
            ),
          ),

          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[900],
            backgroundImage: AssetImage('assets/images/avatar/$avatarPath'),
          ),
          const SizedBox(width: 16),

          // Nome e Taxa de Vitória
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player['nickname'] ?? 'Desconhecido',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Taxa de Vitória: ${player['winRate']}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),

          // Status Principal (Vitórias ou Moedas)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text(
                    mainStatValue.toString(),
                    style: TextStyle(
                      color: isCoinRanking ? Colors.amber : Colors.greenAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(mainStatIcon,
                      color: isCoinRanking ? Colors.amber : Colors.greenAccent,
                      size: 20),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                mainStatLabel,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
