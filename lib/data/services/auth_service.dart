import '../../core/network/dio_client.dart';

class AuthService {
  Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final res = await DioClient.dio.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    return res.data;
  }

  Future<Map<String, dynamic>> register(
    String nickname,
    String email,
    String password,
  ) async {
    final res = await DioClient.dio.post(
      '/auth/register',
      data: {
        'name': nickname,
        'email': email,
        'password': password,
      },
    );
    return res.data;
  }
}
