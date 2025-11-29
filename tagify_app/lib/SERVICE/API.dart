import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tagify_app/models/models.dart';

class ApiService {
  // IMPORTANTE: 
  // Telemóvel físico -> usar o IP do PC: http://192.168.193.102:8000
  // Emulador Android: http://10.0.2.2:8000
  static const String baseUrl = 'http://192.168.193.102:8000';

  // ============================================
  // AUTENTICAÇÃO
  // ============================================
  
  Future<LoginResponse> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        return LoginResponse.fromJson(json);
      } else {
        return LoginResponse(
          success: false,
          message: 'Erro no servidor: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Erro no login: $e');
      return LoginResponse(
        success: false,
        message: 'Erro de conexão: $e',
      );
    }
  }

  // ============================================
  // HEALTH CHECK
  // ============================================

  Future<bool> healthCheck() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      print('Erro no health check: $e');
      return false;
    }
  }

  // ============================================
  // ARTIGOS
  // ============================================

  Future<List<Artigo>> getAllArtigos() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/artigos'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes)) as List;
        return json.map((item) => Artigo.fromJson(item)).toList();
      } else {
        print('Erro: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Erro ao buscar artigos: $e');
      return [];
    }
  }

  Future<Artigo?> getArtigoById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/artigos/$id'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        return Artigo.fromJson(json);
      } else {
        print('Erro: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Erro ao buscar artigo: $e');
      return null;
    }
  }

  Future<Artigo?> getArtigoByCodigo(String codigo) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/artigos/codigo/$codigo'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        return Artigo.fromJson(json);
      } else {
        print('Erro: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Erro ao buscar artigo por código: $e');
      return null;
    }
  }
}