import '../../../data/repositories/auth_repository.dart';
import '../../../core/storage/storage_service.dart';

class AuthController {
  final repo = AuthRepository();

  Future<void> login(String email, String password) async {
    final data = await repo.login(email, password);

    final token = data['access_token'];

    await StorageService.saveToken(token);
  }

  Future<void> register(
    String nickname,
    String email,
    String password,
  ) async {
    await repo.register(nickname, email, password);
  }
}
