class Utilizador {
  final int id;
  final String nome;
  final String email;
  final String username;
  final String password; // Em produção, nunca expor password no modelo
  final bool ativo;
  final DateTime? dataCriacao;
  final DateTime? ultimoAcesso;

  Utilizador({
    required this.id,
    required this.nome,
    required this.email,
    required this.username,
    required this.password,
    required this.ativo,
    this.dataCriacao,
    this.ultimoAcesso,
  });

  factory Utilizador.fromJson(Map<String, dynamic> json) {
    return Utilizador(
      id: json['ID_utilizador'],
      nome: json['Nome'],
      email: json['Email'],
      username: json['Username'],
      password: json['Password'] ?? '', // Nunca devolver password da API em produção
      ativo: json['Ativo'] == 1 || json['Ativo'] == true,
      dataCriacao: json['Data_criacao'] != null
          ? DateTime.parse(json['Data_criacao'])
          : null,
      ultimoAcesso: json['Ultimo_acesso'] != null
          ? DateTime.parse(json['Ultimo_acesso'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ID_utilizador': id,
      'Nome': nome,
      'Email': email,
      'Username': username,
      'Password': password,
      'Ativo': ativo ? 1 : 0,
      'Data_criacao': dataCriacao?.toIso8601String(),
      'Ultimo_acesso': ultimoAcesso?.toIso8601String(),
    };
  }

  // Método para converter para JSON sem password (segurança)
  Map<String, dynamic> toJsonSafe() {
    return {
      'ID_utilizador': id,
      'Nome': nome,
      'Email': email,
      'Username': username,
      'Ativo': ativo ? 1 : 0,
      'Data_criacao': dataCriacao?.toIso8601String(),
      'Ultimo_acesso': ultimoAcesso?.toIso8601String(),
    };
  }

  // Cópia do objeto com campos atualizados
  Utilizador copyWith({
    int? id,
    String? nome,
    String? email,
    String? username,
    String? password,
    bool? ativo,
    DateTime? dataCriacao,
    DateTime? ultimoAcesso,
  }) {
    return Utilizador(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      username: username ?? this.username,
      password: password ?? this.password,
      ativo: ativo ?? this.ativo,
      dataCriacao: dataCriacao ?? this.dataCriacao,
      ultimoAcesso: ultimoAcesso ?? this.ultimoAcesso,
    );
  }
}

// Classe para request de login (apenas username e password)
class LoginRequest {
  final String username;
  final String password;

  LoginRequest({
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
    };
  }
}

// Classe para response de login
class LoginResponse {
  final bool success;
  final String? message;
  final Utilizador? utilizador;
  final String? token; // Para futuro (JWT)

  LoginResponse({
    required this.success,
    this.message,
    this.utilizador,
    this.token,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['success'] ?? false,
      message: json['message'],
      utilizador: json['utilizador'] != null
          ? Utilizador.fromJson(json['utilizador'])
          : null,
      token: json['token'],
    );
  }
}