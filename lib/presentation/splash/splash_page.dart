import 'package:flutter/material.dart';
import '../../core/storage/storage_service.dart';
import '../pages/auth_page.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Verifica o usuário automaticamente ao carregar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkUser(context);
    });

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Splash Screen'),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Future<void> checkUser(BuildContext context) async {
    final token = await StorageService.getToken();

    await Future.delayed(const Duration(seconds: 1));

    if (token != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );
    }
  }
}
