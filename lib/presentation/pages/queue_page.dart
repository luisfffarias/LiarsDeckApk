import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'match_page.dart';
import 'package:liarsDeck/core/constants/api_constants.dart';

class QueuePage extends StatefulWidget {
  final String nickname;
  final url = ApiConstants.baseUrl;

  const QueuePage({super.key, required this.nickname});

  @override
  State<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends State<QueuePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  IO.Socket? socket;
  String statusMessage = 'CONECTANDO AO SERVIDOR...';

  String _userId = '';

  // ---> AS NOVAS TRAVAS DE SEGURANÇA <---
  bool _matchFound = false;
  bool _isDisposing = false;

  final String serverUrl = ApiConstants.baseUrl;

  String _getUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return '';

      String normalized = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (normalized.length % 4) {
        case 0:
          break;
        case 2:
          normalized += '==';
          break;
        case 3:
          normalized += '=';
          break;
        default:
          return '';
      }

      final payloadStr = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(payloadStr);

      return payloadMap['sub'].toString();
    } catch (e) {
      print('Erro ao decodificar token: $e');
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _initSocketConnection();
  }

  Future<void> _initSocketConnection() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'jwt_token');

    if (token == null) {
      setState(() => statusMessage = 'ERRO: Token não encontrado!');
      return;
    }

    _userId = _getUserIdFromToken(token);

    socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setAuth({'token': token})
            .build());

    socket!.onConnect((_) {
      print('✅ Conectado ao Servidor Socket!');
      if (mounted && !_isDisposing) {
        setState(() => statusMessage = 'BUSCANDO OPONENTES...');
      }
      socket!.emit('find_match');
    });

    socket!.onDisconnect((_) {
      print('❌ Desconectado.');
      // Adicionado a trava !_isDisposing para evitar o Crash do setState
      if (mounted && !_isDisposing) {
        setState(() => statusMessage = 'CONEXÃO PERDIDA.');
      }
    });

    socket!.onError((data) {
      print('⚠️ ERRO: $data');
      if (mounted && !_isDisposing) {
        setState(() => statusMessage = 'ERRO NA CONEXÃO.');
      }
    });

    socket!.on('queue_update', (data) {
      print('⏳ Fila de Espera: ${data['message']}');
      if (mounted && !_isDisposing) {
        setState(() {
          statusMessage = data['message'] ?? 'Aguardando jogadores...';
        });
      }
    });

    socket!.on('game_ready', (data) {
      print('🎮 PARTIDA COMEÇOU! MatchID: ${data['matchId']}');

      _matchFound =
          true; // <--- AVISA QUE ACHOU PARTIDA PARA NÃO FECHAR O SOCKET
      _controller.stop();

      if (mounted && !_isDisposing) {
        setState(() => statusMessage = 'PARTIDA ENCONTRADA!');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MatchPage(
              nickname: widget.nickname,
              userId: _userId,
              matchId: data['matchId'],
              socket: socket!,
            ),
          ),
        );
      }
    });

    socket!.connect();
  }

  @override
  void dispose() {
    _isDisposing = true; // <--- AVISA PROS LISTENERS PARAREM DE DAR SETSTATE
    _controller.dispose();

    // SÓ desconecta se ele não tiver achado partida (ex: clicou em "Cancelar")
    if (socket != null && !_matchFound) {
      print('🔌 Fechando conexão do socket (Busca cancelada)...');
      // Opcional: remover os listeners antes de desconectar para garantir
      socket!.clearListeners();
      socket!.disconnect();
      socket!.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.9),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RotationTransition(
                  turns: _controller,
                  child: const Icon(
                    Icons.casino,
                    color: Colors.redAccent,
                    size: 80,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(color: Colors.red, blurRadius: 15),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Preparando as cartas para ${widget.nickname}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close, color: Colors.white),
                  label: const Text(
                    'CANCELAR BUSCA',
                    style: TextStyle(color: Colors.white, letterSpacing: 1.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24, width: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
