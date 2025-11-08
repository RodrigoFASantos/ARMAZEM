import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tagify_app/models/models.dart';

class ApiService {
  // IMPORTANTE: 
  // Telemóvel físico -> usar o IP do PC
  // Emulador Android: http://10.0.2.2:8000
  // Emulador iOS: http://127.0.0.1:8000
  static const String baseUrl = 'http://127.0.0.1:8000';

  // Testar ligação à API
  Future<bool> healthCheck() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      print('Erro no health check: $e');
      return false;
    }
  }

  // Buscar artigo por ID
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

  // Buscar artigo por código (QR/NFC/RFID/Referência)
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