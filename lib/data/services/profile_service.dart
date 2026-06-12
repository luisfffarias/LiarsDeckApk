import 'dart:convert';
import 'package:http/http.dart' as http;
// Importe seu ApiConstants aqui:
import 'package:liarsDeck/core/constants/api_constants.dart';

class UserService {
  Future<Map<String, dynamic>> fetchUserProfile(String token) async {
    // Como a sua baseUrl já termina com "/", basta concatenar "user/me"
    final url = Uri.parse('${ApiConstants.baseUrl}user/me');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Sessão expirada. Faça login novamente.');
    } else {
      throw Exception('Erro no servidor: ${response.statusCode}');
    }
  }

  Future<void> updateUserAvatar(String token, String avatarName) async {
    final url = Uri.parse('${ApiConstants.baseUrl}user/me/avatar');

    final response = await http.patch(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'avatar': avatarName,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Erro ao atualizar o avatar: ${response.statusCode}');
    }
  }
}
