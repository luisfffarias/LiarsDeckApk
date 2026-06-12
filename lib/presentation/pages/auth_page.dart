import 'dart:math';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'menu_page.dart';
import 'package:liarsDeck/core/constants/api_constants.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool isLogin = true;
  final url = ApiConstants.baseUrl;
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  late String randomCardImage;

  @override
  void initState() {
    super.initState();

    final cards = [
      'assets/images/cards/mimico.png',
      'assets/images/cards/papel.png',
      'assets/images/cards/pedra.png',
      'assets/images/cards/tesoura.png',
    ];

    randomCardImage = cards[Random().nextInt(cards.length)];
  }

  String handleError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    print('--- ERRO DETALHADO ---');
    print('Tipo: ${e.type}');
    print('Status: $status');
    print('Data: $data');

    if (data is Map && data['message'] != null) {
      return data['message'];
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Timeout de conexão';
      case DioExceptionType.receiveTimeout:
        return 'Timeout de resposta';
      case DioExceptionType.badResponse:
        return 'Erro do servidor ($status)';
      default:
        return 'Erro desconhecido';
    }
  }

  void onSubmit() async {
    if (!isLogin && passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('As senhas não coincidem!'),
            backgroundColor: Colors.red),
      );
      return;
    }

    const storage = FlutterSecureStorage();
    await storage.delete(key: 'jwt_token');

    try {
      if (isLogin) {
        final response = await dio.post(
          '/auth/login',
          data: {
            'email': emailController.text,
            'password': passwordController.text,
          },
        );

        final token = response.data['access_token'];
        final userNickname = response.data['nickname'] ?? 'Jogador';

        await storage.write(key: 'jwt_token', value: token);
        print('🔒 Token salvo com sucesso!');
        print('LOGIN OK');

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => LobbyPage(nickname: userNickname),
            ),
          );
        }
      } else {
        final response = await dio.post(
          '/auth/register',
          data: {
            'nickname': nameController.text,
            'email': emailController.text,
            'password': passwordController.text,
          },
        );

        print('CADASTRO OK');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Cadastro realizado com sucesso! Faça o login para entrar.'),
              backgroundColor: Colors.green,
            ),
          );

          setState(() {
            isLogin = true;
            passwordController.clear();
            confirmPasswordController.clear();
          });
        }
      }
    } on DioException catch (e) {
      final msg = handleError(e);
      print('ERRO NA API: $msg');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      print('ERRO DESCONHECIDO: $e');
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              'https://www.shutterstock.com/image-photo/empty-wooden-bar-counter-defocused-600nw-2558943755.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.85),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 70,
                      height: 105,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          randomCardImage,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "LIAR'S",
                      style: TextStyle(
                        fontSize: 48,
                        color: Colors.redAccent,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                        shadows: [
                          Shadow(color: Colors.red, blurRadius: 20),
                          Shadow(color: Colors.redAccent, blurRadius: 40),
                        ],
                      ),
                    ),
                    const Text(
                      "= DECK =",
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.redAccent,
                        letterSpacing: 4,
                        shadows: [
                          Shadow(color: Colors.red, blurRadius: 15),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      isLogin ? 'Faça login para continuar' : 'Crie sua conta',
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLogin
                          ? 'Entre no bar e prove que você tem lábia.'
                          : 'Entre no bar e comece a jogar.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (!isLogin) ...[
                      _buildDarkTextField(
                        controller: nameController,
                        hintText: 'Nome de usuário',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildDarkTextField(
                      controller: emailController,
                      hintText: 'E-mail ',
                      icon: Icons.mail_outline,
                    ),
                    const SizedBox(height: 16),
                    _buildDarkTextField(
                      controller: passwordController,
                      hintText: 'Senha',
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),
                    if (!isLogin) ...[
                      const SizedBox(height: 16),
                      _buildDarkTextField(
                        controller: confirmPasswordController,
                        hintText: 'Confirmar senha',
                        icon: Icons.lock_outline,
                        isPassword: true,
                      ),
                    ],
                    if (!isLogin) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: true,
                              onChanged: (val) {},
                              activeColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.white38),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: 'Li e aceito os ',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 11),
                                children: [
                                  TextSpan(
                                      text: 'Termos de Uso',
                                      style:
                                          TextStyle(color: Colors.redAccent)),
                                  TextSpan(text: ' e '),
                                  TextSpan(
                                      text: 'Política de Privacidade',
                                      style:
                                          TextStyle(color: Colors.redAccent)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          )
                        ],
                        gradient: LinearGradient(
                          colors: [
                            Colors.red.shade900,
                            Colors.red.shade700,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      child: ElevatedButton(
                        onPressed: onSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                                color: Colors.red.shade400, width: 1),
                          ),
                        ),
                        child: Text(
                          isLogin ? 'ENTRAR' : 'CRIAR CONTA',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        const Expanded(
                            child:
                                Divider(color: Colors.white12, thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            isLogin ? 'Em breve:' : 'Em breve:',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                          ),
                        ),
                        const Expanded(
                            child:
                                Divider(color: Colors.white12, thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSocialButton('G', Colors.white),
                        const SizedBox(width: 16),
                        _buildSocialButton('A', Colors.white),
                        const SizedBox(width: 16),
                        _buildSocialButton('D', const Color(0xFF5865F2)),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isLogin
                              ? 'Ainda não tem uma conta? '
                              : 'Já tem uma conta? ',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              isLogin = !isLogin;
                            });
                          },
                          child: Text(
                            isLogin ? 'Cadastre-se' : 'Entrar',
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    if (isLogin) ...[
                      const SizedBox(height: 30),
                      const Text(
                        'Ao continuar, você concorda com nossos\nTermos de Uso e Política de Privacidade',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.03),
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        suffixIcon: isPassword
            ? const Icon(Icons.remove_red_eye, color: Colors.white38, size: 20)
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white12, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
      ),
    );
  }

  Widget _buildSocialButton(String label, Color iconColor) {
    return Container(
      width: 70,
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
              color: iconColor, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
