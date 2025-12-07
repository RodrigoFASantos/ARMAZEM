import 'package:flutter/material.dart';
import '../SERVICE/API.dart';
import '../SERVICE/sync_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  final _syncService = SyncService();
  
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _obscurePassword = true;
  bool _isServerOnline = false;
  bool _hasSynced = false; // ✅ NOVO: Indica se já sincronizou
  String? _errorMessage;
  String? _syncMessage;

  @override
  void initState() {
    super.initState();
    _checkServerStatus();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Verifica se o servidor está acessível
  Future<void> _checkServerStatus() async {
    final isOnline = await _apiService.isServerAvailable();
    setState(() => _isServerOnline = isOnline);
    
    if (isOnline) {
      print('✅ Servidor online');
    } else {
      print('⚠️ Servidor offline - Modo offline ativado');
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      setState(() => _isLoading = false);

      if (response.success && response.utilizador != null) {
        if (mounted) {
          final modoOffline = !_isServerOnline;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    modoOffline ? Icons.offline_bolt : Icons.cloud_done,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      modoOffline
                          ? 'Bem-vindo, ${response.utilizador!.nome}! (Modo Offline)'
                          : 'Bem-vindo, ${response.utilizador!.nome}!',
                    ),
                  ),
                ],
              ),
              backgroundColor: modoOffline ? Colors.orange : Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Navega para a Home
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        setState(() {
          _errorMessage = response.message ?? 'Credenciais inválidas';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao fazer login: $e';
      });
    }
  }

  Future<void> _handleSync() async {
    // Verifica se servidor está online
    await _checkServerStatus();
    
    if (!_isServerOnline) {
      setState(() {
        _errorMessage = 'Servidor não está acessível. Verifique a conexão.';
      });
      return;
    }

    setState(() {
      _isSyncing = true;
      _syncMessage = 'Iniciando sincronização...';
      _errorMessage = null;
    });

    try {
      final result = await _syncService.syncAllData(
        onProgress: (message) {
          if (mounted) {
            setState(() => _syncMessage = message);
          }
        },
      );

      setState(() {
        _isSyncing = false;
        _syncMessage = null;
      });

      if (result.success) {
        // ✅ ALTERADO: Marca que sincronizou (botão fica verde)
        setState(() {
          _hasSynced = true;
        });
        
        // ✅ ALTERADO: Apenas SnackBar em vez de Dialog
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sincronizado! ${result.totalRecords} registos em ${result.durationFormatted}',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _isSyncing = false;
        _syncMessage = null;
        _errorMessage = 'Erro na sincronização: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.warehouse_rounded,
                    size: 80,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'RLSEE',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sistema de Informação',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  
                  const SizedBox(height: 32),

                  // Mensagem de sincronização
                  if (_isSyncing && _syncMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _syncMessage!,
                              style: TextStyle(color: Colors.blue[700]),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Mensagem de erro
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Username
                  TextFormField(
                    controller: _usernameController,
                    enabled: !_isSyncing,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira o username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    enabled: !_isSyncing,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, insira a password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Botão Login
                  ElevatedButton(
                    onPressed: (_isLoading || _isSyncing) ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Entrar',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (!_isServerOnline) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.offline_bolt, size: 20),
                              ],
                            ],
                          ),
                  ),

                  const SizedBox(height: 16),

                  // ✅ Botão Sincronizar - AZUL antes, VERDE depois
                  OutlinedButton.icon(
                    onPressed: (_isLoading || _isSyncing) ? null : _handleSync,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(
                        color: _isSyncing
                            ? Colors.grey
                            : _hasSynced
                                ? Colors.green  // ✅ VERDE depois de sincronizar
                                : _isServerOnline
                                    ? Colors.blue  // ✅ AZUL antes de sincronizar
                                    : Colors.grey,
                        width: 2,
                      ),
                      backgroundColor: _hasSynced 
                          ? Colors.green[50]  // Fundo verde claro depois de sincronizar
                          : null,
                    ),
                    icon: Icon(
                      _hasSynced ? Icons.check_circle : Icons.sync,
                      color: _isSyncing
                          ? Colors.grey
                          : _hasSynced
                              ? Colors.green  // ✅ VERDE depois de sincronizar
                              : _isServerOnline
                                  ? Colors.blue  // ✅ AZUL antes de sincronizar
                                  : Colors.grey,
                    ),
                    label: Text(
                      _hasSynced ? 'Dados Sincronizados' : 'Sincronizar Dados',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isSyncing
                            ? Colors.grey
                            : _hasSynced
                                ? Colors.green  // ✅ VERDE depois de sincronizar
                                : _isServerOnline
                                    ? Colors.blue  // ✅ AZUL antes de sincronizar
                                    : Colors.grey,
                      ),
                    ),
                  ),

                  // Instruções de uso offline
                  if (!_isServerOnline)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange[300]!),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.orange[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Modo Offline',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Use credenciais já sincronizadas. Para adicionar novos utilizadores, conecte ao servidor.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}