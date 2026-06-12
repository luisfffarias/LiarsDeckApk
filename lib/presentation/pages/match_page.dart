import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'package:liarsDeck/data/services/sound_service.dart';
import 'package:liarsDeck/data/services/music_service.dart';

class MatchPage extends StatefulWidget {
  final String nickname;
  final String userId;
  final String matchId;
  final IO.Socket socket;

  const MatchPage({
    super.key,
    required this.nickname,
    required this.userId,
    required this.matchId,
    required this.socket,
  });

  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  // ==========================================
  // ESTADO DO JOGO
  // ==========================================
  List<String> myCards = [];
  List<int> selectedCardIndexes = [];
  int? hoveredCardIndex;

  String currentTurnPlayerId = '';
  String roundCard = 'ROCK';

  int cardsOnTable = 0;

  List<Map<String, dynamic>> tablePlayers = [];
  Map<String, int> playersCardsCount = {};
  Map<String, dynamic>? lastPlay;

  String gameStatus = 'Sincronizando mesa...';
  bool isMyTurn = false;
  bool isInPenaltyMode = false;

  bool amIAlive = true;

  // ==========================================
  // TIMERS E FEEDBACK
  // ==========================================
  String? _lastPlayerId;
  int _lastPlayCount = 0;
  bool _showPlayBanner = false;
  Timer? _playBannerTimer;
  Timer? _actionTimeout; // 👈 NOVO: Timer de segurança anti-travamento

  @override
  void initState() {
    super.initState();
    _setupGameListeners();

    _requestSync();

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && myCards.isEmpty) {
        debugPrint('⚠️ Cartas ainda vazias, forçando nova sincronização...');
        _requestSync();
      }
    });
  }

  void _requestSync() {
    widget.socket.emit('reconnect_match', {
      'matchId': widget.matchId,
      'userId': widget.userId,
    });
  }

  // 👇 NOVA LÓGICA DE RECUPERAÇÃO ANTI-TRAVAMENTO 👇
  void _setPendingAction() {
    setState(() => isMyTurn = false);
    _actionTimeout?.cancel();
    _actionTimeout = Timer(const Duration(seconds: 4), () {
      // Se passar 4 segundos sem resposta do servidor, o app se "cura" sozinho
      if (mounted && amIAlive) {
        setState(() {
          _updateTurnStatus(); // Devolve os botões e a vez para o jogador tentar de novo
        });
        _showSnack('O servidor demorou para responder. Tente jogar novamente.',
            isError: true);
      }
    });
  }

  void _clearPendingAction() {
    _actionTimeout?.cancel();
  }

  // 👇 LÓGICA DE ORGANIZAR CARTAS 👇
  void _sortMyHand() {
    const order = {
      'ROCK': 1,
      'PAPER': 2,
      'SCISSORS': 3,
      'JOKER': 4,
    };

    myCards.sort((a, b) {
      final valA = order[a.toUpperCase()] ?? 5;
      final valB = order[b.toUpperCase()] ?? 5;
      return valA.compareTo(valB);
    });
  }

  // ==========================================
  // UTILITÁRIOS DE TRADUÇÃO
  // ==========================================
  String _getCardNamePtBr(String cardType) {
    switch (cardType.toUpperCase()) {
      case 'ROCK':
        return 'PEDRA';
      case 'PAPER':
        return 'PAPEL';
      case 'SCISSORS':
        return 'TESOURA';
      case 'JOKER':
        return 'MÍMICO';
      default:
        return 'PEDRA';
    }
  }

  String _getCardAssetPath(String cardType) {
    switch (cardType.toUpperCase()) {
      case 'ROCK':
        return 'assets/images/cards/pedra.png';
      case 'PAPER':
        return 'assets/images/cards/papel.png';
      case 'SCISSORS':
        return 'assets/images/cards/tesoura.png';
      case 'JOKER':
        return 'assets/images/cards/mimico.png';
      default:
        return 'assets/images/cards/pedra.png';
    }
  }

  String _getAvatarPath(String avatar) {
    return 'assets/images/avatar/$avatar';
  }

  // ==========================================
  // LÓGICA DE SOCKETS
  // ==========================================
  void _setupGameListeners() {
    final socket = widget.socket;

    socket.off('match_started');
    socket.off('new_round_cards');
    socket.off('game_state_recovered');
    socket.off('turn_start');
    socket.off('card_played');
    socket.off('challenge_result');
    socket.off('player_eliminated');
    socket.off('start_penalty_duel');
    socket.off('penalty_result');
    socket.off('game_over');
    socket.off('error');
    socket.off('player_surrendered');
    socket.off('player_eliminated_afk');

    socket.onAny((event, data) {
      debugPrint('🔥 SOCKET EVENT: $event | DATA: $data');
    });

    socket.on('match_started', (data) {
      if (!mounted) return;
      _clearPendingAction(); // 👈 Limpa a segurança caso estivesse carregando
      setState(() {
        final cards = data['myCards'];
        myCards = cards != null ? List<String>.from(cards) : [];
        _sortMyHand();

        currentTurnPlayerId = data['currentTurnPlayerId'] ?? '';
        selectedCardIndexes.clear();

        _updatePlayersList(data['playersInfo'] ?? []);
        _updateTurnStatus();
      });

      SoundService().enableAudio();
    });

    socket.on('new_round_cards', (data) {
      if (!mounted) return;
      _clearPendingAction();
      setState(() {
        myCards = List<String>.from(data['myCards'] ?? data['hand'] ?? []);
        _sortMyHand();

        selectedCardIndexes.clear();
        lastPlay = null;
        cardsOnTable = 0;
        _lastPlayerId = null;
        _showPlayBanner = false;

        _updatePlayersList(data['playersInfo'] ?? data['players'] ?? []);
      });
      _showSnack('Nova rodada! Cartas redistribuídas.', isError: false);
    });

    socket.on('game_state_recovered', (data) {
      if (!mounted) return;
      _clearPendingAction();
      setState(() {
        myCards = List<String>.from(data['myCards'] ?? data['hand'] ?? []);
        _sortMyHand();

        currentTurnPlayerId = data['currentTurnPlayerId'] ?? '';
        lastPlay = data['lastPlay'];
        selectedCardIndexes.clear();

        _updatePlayersList(data['playersInfo'] ?? data['players'] ?? []);
        _updateTurnStatus();
      });

      SoundService().enableAudio();
    });

    socket.on('turn_start', (data) {
      if (!mounted) return;
      _clearPendingAction();
      setState(() {
        currentTurnPlayerId = data['currentPlayerId'];
        roundCard = data['roundCard'] ?? 'ROCK';
        cardsOnTable = data['cardsOnTableCount'] ?? cardsOnTable;
        _updateTurnStatus();
      });
    });

    socket.on('card_played', (data) {
      if (!mounted) return;
      _clearPendingAction(); // 👈 Jogada foi aceita pelo servidor, limpa a proteção
      setState(() {
        lastPlay = {
          'userId': data['userId'],
          'count': data['count'],
          'cards': data['cards'] ?? []
        };

        cardsOnTable =
            data['totalOnTable'] ?? (cardsOnTable + (data['count'] as int));

        if (data['userId'] != widget.userId) {
          playersCardsCount[data['userId']] = data['cardsLeft'];
          final index =
              tablePlayers.indexWhere((p) => p['id'] == data['userId']);
          if (index != -1) {
            tablePlayers[index]['cardsCount'] = data['cardsLeft'];
          }
        } else {
          selectedCardIndexes.sort((a, b) => b.compareTo(a));
          for (var i in selectedCardIndexes) {
            if (i < myCards.length) myCards.removeAt(i);
          }
          selectedCardIndexes.clear();
        }

        gameStatus = data['message'];
        _updateTurnStatus();
      });

      _lastPlayerId = data['userId'];
      _lastPlayCount = (data['count'] as int?) ?? 0;
      _triggerPlayBanner();
    });

    socket.on('challenge_result', (data) {
      if (!mounted) return;
      _clearPendingAction();
      _showSnack(data['message'], isError: false);
      setState(() {
        lastPlay = null;
        cardsOnTable = 0;
        selectedCardIndexes.clear();
        _lastPlayerId = null;
        _showPlayBanner = false;
        _updateTurnStatus();
      });
    });

    socket.on('player_eliminated', (data) {
      if (!mounted) return;
      setState(() {
        final index =
            tablePlayers.indexWhere((p) => p['id'] == data['eliminatedId']);
        if (index != -1) {
          tablePlayers[index]['isAlive'] = false;
        }
      });
      _showSnack(data['message'] ?? 'Um jogador foi eliminado!',
          isError: false);
    });

    socket.on('start_penalty_duel', (data) {
      if (!mounted) return;
      _clearPendingAction();
      setState(() => isInPenaltyMode = true);
      if (data['loserId'] == widget.userId) {
        _showPenaltyDuelDialog();
      } else {
        setState(() => gameStatus = 'Aguardando punição do oponente...');
      }
    });

    socket.on('penalty_result', (data) {
      if (!mounted) return;
      bool isTie = data['isTie'] ?? false;
      bool isMe = data['userId'] == widget.userId;
      bool isEliminated = data['isEliminated'] ?? false;

      if (isTie) {
        _showSnack(data['message'], isError: false);
        if (isMe) _showPenaltyDuelDialog();
        return;
      }

      setState(() => isInPenaltyMode = false);

      if (isMe) {
        if (isEliminated) {
          setState(() {
            amIAlive = false;
            isMyTurn = false;
            myCards.clear();
          });
        }

        _showResultDialog(
          title:
              isEliminated ? '💀 VOCÊ FOI ELIMINADO!' : '🎉 VOCÊ SOBREVIVEU!',
          message: data['message'],
          color: isEliminated ? Colors.red : Colors.green,
          shouldQuitMenu: isEliminated,
        );
      } else {
        _showSnack(data['message'], isError: isEliminated);
      }
    });

    socket.on('game_over', (data) {
      if (!mounted) return;
      _showGameOverDialog(data['winnerId'], data['message']);
    });

    socket.on('error', (data) {
      if (!mounted) return;
      _clearPendingAction(); // 👈 Se o servidor recusar, devolvemos a ação do usuário na mesma hora
      _showSnack(data['message'] ?? 'Erro de comunicação', isError: true);
      setState(() {
        _updateTurnStatus(); // Força a atualização pra devolver os botões
      });
    });

    socket.on('player_surrendered', (data) {
      if (!mounted) return;
      _showSnack(data['message'], isError: true);

      setState(() {
        final index = tablePlayers.indexWhere((p) => p['id'] == data['userId']);
        if (index != -1) {
          tablePlayers[index]['isAlive'] = false;
        }
      });
    });

    socket.on('player_eliminated_afk', (data) {
      if (!mounted) return;

      if (data['userId'] == widget.userId) {
        setState(() {
          amIAlive = false;
          isMyTurn = false;
          myCards.clear();
        });

        _showResultDialog(
          title: '⏳ TEMPO ESGOTADO!',
          message:
              'Você demorou muito para jogar e foi removido da mesa por inatividade.',
          color: Colors.red,
          shouldQuitMenu: true,
        );
      } else {
        _showSnack(data['message'], isError: true);
        setState(() {
          final index =
              tablePlayers.indexWhere((p) => p['id'] == data['userId']);
          if (index != -1) {
            tablePlayers[index]['isAlive'] = false;
          }
        });
      }
    });
  }

  void _updatePlayersList(List<dynamic> players) {
    tablePlayers = players
        .map((p) => {
              'id': p['id'] ?? '',
              'nickname': p['nickname'] ?? 'Desconhecido',
              'cardsCount': p['cardsCount'] ?? p['handSize'] ?? 13,
              'isAlive': p['isAlive'] ?? true,
              'avatar': p['avatar'] ?? 'default.png',
            })
        .toList();

    for (var player in tablePlayers) {
      playersCardsCount[player['id']] = player['cardsCount'];
    }
  }

  void _updateTurnStatus() {
    if (!amIAlive) {
      setState(() {
        isMyTurn = false;
        gameStatus = '💀 Você foi eliminado. Apenas assistindo...';
      });
      return;
    }

    isMyTurn = (currentTurnPlayerId == widget.userId);

    if (isMyTurn) {
      if (playersCardsCount.values.where((c) => c == 0).isNotEmpty) {
        gameStatus = '⚠️ Alguém está sem cartas! Duvide agora! ⚠️';
      } else if (cardsOnTable > 0) {
        gameStatus =
            '🎲 Cartas na mesa! Clique em DUVIDAR se achar que é blefe! 🎲';
      } else {
        gameStatus = '🎲 SUA VEZ - Jogue ${_getCardNamePtBr(roundCard)} 🎲';
      }
    } else {
      if (cardsOnTable > 0) {
        gameStatus = '🎲 ⚠️ ALGUÉM JOGOU! Você pode DUVIDAR agora! ⚠️ 🎲';
      } else {
        gameStatus = '⏳ Aguardando oponente... ⏳';
      }
    }
  }

  void _toggleCardSelection(int index) {
    if (!isMyTurn || !amIAlive || isInPenaltyMode) return;
    setState(() {
      if (selectedCardIndexes.contains(index)) {
        selectedCardIndexes.remove(index);
      } else {
        // 👇 Trava removida! Agora você pode selecionar as 13 cartas se quiser.
        selectedCardIndexes.add(index);
      }
    });
  }

  void _playSelectedCards() {
    if (!amIAlive) return;
    if (selectedCardIndexes.isEmpty) {
      _showSnack('Selecione pelo menos uma carta para jogar!', isError: true);
      return;
    }

    List<String> cardsToSend =
        selectedCardIndexes.map((i) => myCards[i]).toList();

    widget.socket.emit('play_card', {
      'matchId': widget.matchId,
      'userId': widget.userId,
      'cardsPlayed': cardsToSend,
    });

    _setPendingAction(); // 👈 Esconde os botões e ativa a segurança de timeout
  }

  void _callBluff() {
    if (!amIAlive) return;
    if (cardsOnTable == 0) {
      _showSnack('Não há cartas na mesa para duvidar!', isError: true);
      return;
    }

    widget.socket.emit('challenge', {
      'matchId': widget.matchId,
      'userId': widget.userId,
    });

    _setPendingAction(); // 👈 Ativa segurança de timeout
  }

  // ==========================================
  // MODAIS E DIÁLOGOS
  // ==========================================

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.95),
                      Colors.brown.withOpacity(0.3)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.amber.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.settings_voice,
                        color: Colors.amber, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'AJUSTES DE SOM',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SwitchListTile(
                      activeColor: Colors.greenAccent,
                      inactiveThumbColor: Colors.red,
                      inactiveTrackColor: Colors.red.withOpacity(0.3),
                      title: const Text('Música de Fundo',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      value: MusicService().isMusicEnabled,
                      onChanged: (val) {
                        setStateDialog(() {
                          MusicService().toggleMusic(val);
                        });
                      },
                    ),
                    SwitchListTile(
                      activeColor: Colors.greenAccent,
                      inactiveThumbColor: Colors.red,
                      inactiveTrackColor: Colors.red.withOpacity(0.3),
                      title: const Text('Efeitos Sonoros',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      value: SoundService().isSfxEnabled,
                      onChanged: (val) {
                        setStateDialog(() {
                          SoundService().toggleSfx(val);
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Concluir',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPenaltyDuelDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.redAccent, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.redAccent, width: 2),
                ),
                child: const Icon(
                  Icons.gavel,
                  color: Colors.redAccent,
                  size: 40,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '⚔️ JOKENPÔ DA MORTE ⚔️',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(color: Colors.red, blurRadius: 10),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Você perdeu o blefe!',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: const Text(
                  'JOGUE PARA SOBREVIVER',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: _buildPenaltyChoiceCard(
                        choice: 'ROCK', color: Colors.brown),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPenaltyChoiceCard(
                        choice: 'PAPER', color: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPenaltyChoiceCard(
                        choice: 'SCISSORS', color: Colors.red),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Escolha sabiamente...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPenaltyChoiceCard({
    required String choice,
    required Color color,
  }) {
    String cardImage = _getCardAssetPath(choice);
    String cardName = _getCardNamePtBr(choice);

    Color cardColor;
    switch (choice) {
      case 'ROCK':
        cardColor = Colors.brown;
        break;
      case 'PAPER':
        cardColor = Colors.grey;
        break;
      case 'SCISSORS':
        cardColor = Colors.red;
        break;
      default:
        cardColor = Colors.brown;
    }

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        widget.socket.emit('play_penalty', {
          'matchId': widget.matchId,
          'userId': widget.userId,
          'choice': choice,
        });
      },
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0.9, end: 1.0),
        duration: const Duration(milliseconds: 500),
        builder: (context, double scale, child) {
          return Transform.scale(
            scale: scale,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cardColor.withOpacity(0.9),
                    cardColor.withOpacity(0.5)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withOpacity(0.6), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: cardColor.withOpacity(0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.5), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.asset(
                        cardImage,
                        width: double.infinity,
                        height: 70,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        cardName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showResultDialog({
    required String title,
    required String message,
    required Color color,
    bool shouldQuitMenu = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.black.withOpacity(0.95), color.withOpacity(0.3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                title.contains('ELIMINADO') ? Icons.warning : Icons.celebration,
                color: color,
                size: 50,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  if (shouldQuitMenu) {
                    nav.pop();
                  }
                },
                child: Text(
                  shouldQuitMenu ? 'Sair da Mesa' : 'Continuar',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGameOverDialog(String? winnerId, String message) {
    bool iWon = winnerId == widget.userId;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: iWon
                  ? [
                      Colors.green.withOpacity(0.9),
                      Colors.black.withOpacity(0.9)
                    ]
                  : [
                      Colors.red.withOpacity(0.9),
                      Colors.black.withOpacity(0.9)
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
                color: iWon ? Colors.amber : Colors.redAccent, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                iWon ? Icons.emoji_events : Icons.sentiment_very_dissatisfied,
                color: iWon ? Colors.amber : Colors.white,
                size: 50,
              ),
              const SizedBox(height: 12),
              Text(
                iWon ? '🏆 VOCÊ VENCEU!' : '💀 FIM DE JOGO',
                style: TextStyle(
                  color: iWon ? Colors.amber : Colors.redAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: iWon ? Colors.amber : Colors.red,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                onPressed: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.pop();
                },
                child: const Text(
                  'Sair da Mesa',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor: isError ? Colors.red : Colors.green));
  }

  @override
  void dispose() {
    _playBannerTimer?.cancel();
    _actionTimeout
        ?.cancel(); // 👈 Lembre-se de destruir o timer ao sair da tela
    widget.socket.disconnect();
    super.dispose();
  }

  void _triggerPlayBanner() {
    setState(() => _showPlayBanner = true);
    _playBannerTimer?.cancel();
    _playBannerTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _showPlayBanner = false);
    });
  }

  String _nicknameFor(String? id) {
    if (id == null) return '';
    if (id == widget.userId) return widget.nickname;
    final player = tablePlayers.firstWhere(
      (p) => p['id'] == id,
      orElse: () => {},
    );
    return player['nickname'] ?? '';
  }

  // ==========================================
  // BUILD PRINCIPAL (INTERFACE)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final aliveOpponents = tablePlayers
        .where((p) => p['isAlive'] == true && p['id'] != widget.userId)
        .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (isMyTurn && amIAlive)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.red.withOpacity(0.35),
                      Colors.red.withOpacity(0.15),
                      Colors.transparent,
                      Colors.transparent,
                    ],
                    radius: 1.2,
                    center: Alignment.center,
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Image.network(
              'https://www.shutterstock.com/image-photo/empty-wooden-bar-counter-defocused-600nw-2558943755.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Colors.transparent, Colors.black87],
                  radius: 0.9,
                  focal: Alignment.center,
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon:
                  const Icon(Icons.exit_to_app, color: Colors.amber, size: 28),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.black87,
                    title: const Text('⚠️ Abandonar Partida?',
                        style: TextStyle(color: Colors.amber)),
                    content: const Text(
                        'Se você sair agora, será eliminado imediatamente. Tem certeza?',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 14))),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[900]),
                        onPressed: () {
                          widget.socket.emit('surrender', {
                            'matchId': widget.matchId,
                            'userId': widget.userId
                          });
                          final nav = Navigator.of(context);
                          nav.pop();
                          nav.pop();
                        },
                        child: const Text('Arregar',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.volume_up, color: Colors.amber, size: 28),
              onPressed: _showSettingsDialog,
            ),
          ),
          Positioned(
            top: 44,
            left: 60,
            right: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: aliveOpponents.isEmpty
                  ? [
                      const Text('Aguardando oponentes...',
                          style: TextStyle(color: Colors.white54, fontSize: 13))
                    ]
                  : aliveOpponents.map((player) {
                      final isTurn = currentTurnPlayerId == player['id'];
                      final justPlayed =
                          _showPlayBanner && _lastPlayerId == player['id'];
                      return Expanded(
                        child: _buildOpponentAvatar(
                          nickname: player['nickname'],
                          cardsLeft: player['cardsCount'],
                          isTurn: isTurn,
                          avatar: player['avatar'],
                          justPlayed: justPlayed,
                          playedCount: _lastPlayCount,
                        ),
                      );
                    }).toList(),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sports_esports, color: Colors.amber, size: 22),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withOpacity(0.85),
                        Colors.brown.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.amber.withOpacity(0.8), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber, width: 1),
                        ),
                        child: Image.asset(
                          _getCardAssetPath(roundCard),
                          width: 24,
                          height: 38,
                          fit: BoxFit.fill,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'CARTA DA RODADA',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            _getCardNamePtBr(roundCard),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 26,
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity:
                          (_showPlayBanner && _lastPlayerId != null) ? 1 : 0,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        offset: (_showPlayBanner && _lastPlayerId != null)
                            ? Offset.zero
                            : const Offset(0, -0.4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.greenAccent.withOpacity(0.7)),
                          ),
                          child: Text(
                            '${_nicknameFor(_lastPlayerId)} jogou $_lastPlayCount carta${_lastPlayCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 100,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: cardsOnTable > 0
                          ? Stack(
                              key: ValueKey('cards-$cardsOnTable'),
                              alignment: Alignment.center,
                              children: List.generate(
                                cardsOnTable > 5 ? 5 : cardsOnTable,
                                (index) => Transform.translate(
                                  offset: Offset((index * 2.5), (index * -1.2)),
                                  child: Transform.rotate(
                                    angle: (index * 0.05) - 0.1,
                                    child: Container(
                                      width: 55,
                                      height: 75,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: Colors.grey[300]!),
                                        boxShadow: const [
                                          BoxShadow(
                                              color: Colors.black54,
                                              blurRadius: 3,
                                              offset: Offset(2, 2))
                                        ],
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 40,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: Colors.red[900],
                                            borderRadius:
                                                BorderRadius.circular(3),
                                            border: Border.all(
                                                color: Colors.amber, width: 1),
                                          ),
                                          child: const Center(
                                              child: Icon(Icons.casino,
                                                  color: Colors.amber,
                                                  size: 18)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              key: const ValueKey('empty-table'),
                              width: 70,
                              height: 95,
                              decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.white24, width: 2),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Center(
                                  child: Text('Mesa\nVazia',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 13))),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: (isMyTurn && amIAlive)
                        ? const LinearGradient(
                            colors: [Colors.red, Colors.redAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [Colors.grey, Colors.grey],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (isMyTurn && amIAlive)
                          ? Colors.yellowAccent
                          : Colors.white24,
                      width: 1.5,
                    ),
                    boxShadow: (isMyTurn && amIAlive)
                        ? [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.8),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isMyTurn && amIAlive)
                        const Icon(Icons.touch_app,
                            color: Colors.white, size: 12),
                      if (isMyTurn && amIAlive) const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          gameStatus,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: (isMyTurn && amIAlive)
                                ? Colors.white
                                : (cardsOnTable > 0 && amIAlive
                                    ? Colors.redAccent
                                    : Colors.white70),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            shadows: (isMyTurn && amIAlive)
                                ? [
                                    const Shadow(
                                        color: Colors.black,
                                        blurRadius: 2,
                                        offset: Offset(1, 1)),
                                  ]
                                : [],
                          ),
                        ),
                      ),
                      if (isMyTurn && amIAlive) const SizedBox(width: 4),
                      if (isMyTurn && amIAlive)
                        const Icon(Icons.play_arrow,
                            color: Colors.white, size: 14),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: _buildPlayerBottomArea(),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGETS
  // ==========================================

  Widget _buildPlayerBottomArea() {
    return SizedBox(
      height: 180,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (myCards.isNotEmpty && amIAlive) _buildCardFanCarousel(),
          Positioned(
            bottom: 2,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isInPenaltyMode && amIAlive)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (cardsOnTable > 0 && isMyTurn)
                        _HoverActionButton(
                          label: 'DUVIDAR',
                          icon: Icons.cancel_outlined,
                          color: Colors.red[900]!,
                          borderColor: Colors.redAccent,
                          onTap: _callBluff,
                          compact: true,
                        ),

                      if (cardsOnTable > 0 && isMyTurn)
                        const SizedBox(width: 20),

                      if (isMyTurn)
                        _HoverActionButton(
                          label: 'JOGAR',
                          icon: Icons.check_circle_outline,
                          color: Colors.green[900]!,
                          borderColor: Colors.greenAccent,
                          onTap: selectedCardIndexes.isNotEmpty
                              ? _playSelectedCards
                              : null,
                          compact: true,
                        ),

                      // 👇 SE O APP ESTIVER ESPERANDO RESPOSTA, MOSTRA UM LOADING CHARMOSO 👇
                      if (!isMyTurn &&
                          _actionTimeout != null &&
                          _actionTimeout!.isActive)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.amber, strokeWidth: 3),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 10),
                _buildPlayerAvatar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFanCarousel() {
    return Positioned(
      bottom: 60,
      height: 155,
      width: MediaQuery.of(context).size.width,
      child: Center(
        child: SizedBox(
          width: math.min(
              MediaQuery.of(context).size.width, myCards.length * 18.0 + 30),
          child: Stack(
            alignment: Alignment.center,
            children: List.generate(myCards.length, (index) {
              return _buildAnimatedCard(index);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCard(int index) {
    bool isHovered = index == hoveredCardIndex;
    bool isSelected = selectedCardIndexes.contains(index);

    int totalCards = myCards.length;
    double centralCardIndex = (totalCards - 1) / 2;
    double indexFromCenter = index - centralCardIndex;

    double rotationAngle = indexFromCenter * (math.pi / 28);
    double arcYOffset = math.pow(indexFromCenter.abs(), 1.4) * 3;

    double targetTranslateY = (isHovered || isSelected) ? -25 : arcYOffset;
    double targetScale = (isHovered || isSelected) ? 1.12 : 1.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      transform: Matrix4.identity()
        ..translate(indexFromCenter * 14, targetTranslateY, 0)
        ..rotateZ(rotationAngle),
      transformAlignment: Alignment.bottomCenter,
      child: AnimatedScale(
        scale: targetScale,
        duration: const Duration(milliseconds: 300),
        child: MouseRegion(
          onEnter: (_) {
            setState(() => hoveredCardIndex = index);
            SoundService().playHoverSound();
          },
          onExit: (_) => setState(() => hoveredCardIndex = null),
          child: GestureDetector(
            onTap: () => _toggleCardSelection(index),
            child: Container(
              padding: const EdgeInsets.all(2),
              child: _buildCardVisual(index, isSelected),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardVisual(int index, bool isSelected) {
    if (index >= myCards.length) {
      return Container(
        width: 55,
        height: 80,
        color: Colors.grey,
        child: const Center(child: Text('?', style: TextStyle(fontSize: 16))),
      );
    }

    String cardType = myCards[index];

    return Container(
      width: 55,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? Colors.amber : Colors.white.withOpacity(0.4),
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? Colors.amber.withOpacity(0.5)
                : Colors.black.withOpacity(0.4),
            blurRadius: isSelected ? 10 : 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _getCardAssetPath(cardType),
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withOpacity(0.28),
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  _getCardNamePtBr(cardType),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpponentAvatar({
    required String nickname,
    required int cardsLeft,
    required bool isTurn,
    required String avatar,
    bool justPlayed = false,
    int playedCount = 0,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: justPlayed
                        ? Colors.greenAccent
                        : (isTurn ? Colors.amber : Colors.white24),
                    width: justPlayed ? 2.5 : 2),
                boxShadow: justPlayed
                    ? [
                        const BoxShadow(
                            color: Colors.greenAccent,
                            blurRadius: 10,
                            spreadRadius: 1)
                      ]
                    : (isTurn
                        ? [const BoxShadow(color: Colors.amber, blurRadius: 8)]
                        : []),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.brown,
                backgroundImage: AssetImage(_getAvatarPath(avatar)),
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
            ),
            if (justPlayed)
              Positioned(
                top: -6,
                right: -8,
                child: AnimatedScale(
                  scale: justPlayed ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.elasticOut,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green[700],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Text(
                      '+$playedCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(nickname,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.style, color: Colors.redAccent, size: 10),
              const SizedBox(width: 3),
              Text('$cardsLeft',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerAvatar() {
    final myInfo = tablePlayers.firstWhere(
      (p) => p['id'] == widget.userId,
      orElse: () => {'isAlive': true},
    );
    final isPlayerAlive = myInfo['isAlive'] ?? true;

    if (!isPlayerAlive || !amIAlive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
                radius: 14,
                backgroundColor: Colors.red,
                child: Text('💀', style: TextStyle(fontSize: 14))),
            const SizedBox(width: 8),
            Text(widget.nickname,
                style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    decoration: TextDecoration.lineThrough)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isMyTurn
            ? Colors.red.withOpacity(0.15)
            : Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isMyTurn ? Colors.redAccent : Colors.white24,
          width: isMyTurn ? 2 : 1.5,
        ),
        boxShadow: isMyTurn
            ? [
                BoxShadow(
                  color: Colors.red.withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 4,
                ),
              ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isMyTurn ? Colors.redAccent : Colors.white24,
                width: isMyTurn ? 2 : 1.5,
              ),
              boxShadow: isMyTurn
                  ? [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.brown,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.nickname,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.style, color: Colors.redAccent, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '${myCards.length} Cartas',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }
}

// ==========================================
// BOTÃO ANIMADO (VERSÃO COMPACTA)
// ==========================================
class _HoverActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color borderColor;
  final VoidCallback? onTap;
  final bool compact;

  const _HoverActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.borderColor,
    this.onTap,
    this.compact = false,
  });

  @override
  State<_HoverActionButton> createState() => _HoverActionButtonState();
}

class _HoverActionButtonState extends State<_HoverActionButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    bool disabled = widget.onTap == null;

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: disabled ? null : widget.onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: disabled ? 0.4 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.identity()
              ..scale(isHovered && !disabled ? 1.05 : 1.0),
            padding: widget.compact
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                : const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(widget.compact ? 16 : 20),
              border: Border.all(
                  color: isHovered && !disabled
                      ? Colors.white
                      : widget.borderColor,
                  width: widget.compact ? 1.5 : 2),
              boxShadow: disabled
                  ? []
                  : [
                      BoxShadow(
                        color: isHovered
                            ? widget.borderColor
                            : widget.borderColor.withOpacity(0.5),
                        blurRadius: isHovered ? (widget.compact ? 10 : 15) : 8,
                        spreadRadius: isHovered ? 1 : 0,
                      )
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon,
                    color: Colors.white, size: widget.compact ? 18 : 20),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: widget.compact ? 14 : 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
