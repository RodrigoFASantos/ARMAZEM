import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../SERVICE/API.dart';
import '../models/models.dart';
import '../SCREENS/SCREENS_artigo_detail_screen.dart';

class NFCScannerScreen extends StatefulWidget {
  const NFCScannerScreen({super.key});

  @override
  State<NFCScannerScreen> createState() => _NFCScannerScreenState();
}

class _NFCScannerScreenState extends State<NFCScannerScreen>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  bool _isSearching = false;
  bool _isNFCAvailable = false;
  String _statusMessage = 'Verificando NFC...';
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _checkNFCAvailability();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _stopNFCSession();
    super.dispose();
  }

  Future<void> _checkNFCAvailability() async {
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      
      setState(() {
        _isNFCAvailable = isAvailable;
        _statusMessage = isAvailable 
            ? 'Aproxime a etiqueta NFC' 
            : 'NFC não disponível neste dispositivo';
      });

      if (isAvailable) {
        _startNFCSession();
      }
    } catch (e) {
      print('Erro ao verificar NFC: $e');
      setState(() {
        _isNFCAvailable = false;
        _statusMessage = 'Erro ao verificar NFC';
      });
    }
  }

  void _startNFCSession() {
    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        print('🔵 Tag NFC detectada: ${tag.data}');
        
        String? nfcId = _extractNFCId(tag);
        
        if (nfcId != null) {
          await _searchArticle(nfcId);
        } else {
          if (mounted) {
            _showErrorDialog(
              'Erro ao ler NFC', 
              'Não foi possível extrair o ID da tag'
            );
          }
        }
      },
      onError: (error) async {
        print('❌ Erro NFC: $error');
        if (mounted) {
          setState(() {
            _statusMessage = 'Erro ao ler NFC';
          });
        }
        // Não retornar nada - só processar o erro
      },
    );

    print('🔵 Sessão NFC iniciada');
  }

  void _stopNFCSession() {
    try {
      NfcManager.instance.stopSession();
      print('🔵 Sessão NFC parada');
    } catch (e) {
      print('Erro ao parar sessão NFC: $e');
    }
  }

  String? _extractNFCId(NfcTag tag) {
    try {
      // Tentar ler como NDEF primeiro
      final ndef = Ndef.from(tag);
      if (ndef != null && ndef.cachedMessage != null) {
        final message = ndef.cachedMessage!;
        if (message.records.isNotEmpty) {
          // Ler o payload do primeiro record
          var payload = message.records.first.payload;
          
          // Remover byte de controle de idioma se existir (NDEF Text Record)
          if (payload.isNotEmpty && payload[0] == 0x02) {
            // 0x02 = UTF-8, seguido de código de língua de 2 bytes
            if (payload.length > 3) {
              payload = payload.sublist(3);
            }
          } else if (payload.isNotEmpty) {
            // Se começar com outro byte de controle, tentar ler após o primeiro byte
            payload = payload.sublist(1);
          }
          
          String text = String.fromCharCodes(payload).trim();
          print('📝 NDEF Text: $text');
          return text;
        }
      }
      
      // Se não for NDEF, usar ID do hardware
      // Tentar NfcA (tecnologia mais comum - ISO 14443-3A)
      final nfcA = NfcA.from(tag);
      if (nfcA != null && nfcA.identifier.isNotEmpty) {
        String id = nfcA.identifier
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join(':')
            .toUpperCase();
        print('🔑 NFC-A ID: $id');
        return id;
      }
      
      // Tentar NfcB
      final nfcB = NfcB.from(tag);
      if (nfcB != null && nfcB.identifier.isNotEmpty) {
        String id = nfcB.identifier
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join(':')
            .toUpperCase();
        print('🔑 NFC-B ID: $id');
        return id;
      }
      
      // Tentar NfcF
      final nfcF = NfcF.from(tag);
      if (nfcF != null && nfcF.identifier.isNotEmpty) {
        String id = nfcF.identifier
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join(':')
            .toUpperCase();
        print('🔑 NFC-F ID: $id');
        return id;
      }
      
      // Tentar NfcV
      final nfcV = NfcV.from(tag);
      if (nfcV != null && nfcV.identifier.isNotEmpty) {
        String id = nfcV.identifier
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join(':')
            .toUpperCase();
        print('🔑 NFC-V ID: $id');
        return id;
      }
      
      // Tentar extrair qualquer ID disponível dos dados brutos
      if (tag.data.containsKey('nfca')) {
        final data = tag.data['nfca'] as Map;
        if (data.containsKey('identifier')) {
          final id = (data['identifier'] as List)
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join(':')
              .toUpperCase();
          print('🔑 Raw NFC-A ID: $id');
          return id;
        }
      }
      
      print('⚠️ Não foi possível extrair ID da tag');
      print('📋 Dados disponíveis: ${tag.data.keys}');
      return null;
    } catch (e) {
      print('❌ Erro ao extrair ID NFC: $e');
      return null;
    }
  }

  Future<void> _searchArticle(String nfcCode) async {
    if (_isSearching) return;

    setState(() {
      _isSearching = true;
      _statusMessage = 'Procurando artigo...';
    });

    print('🔍 Procurando artigo com código NFC: $nfcCode');

    try {
      final artigo = await _apiService.getArtigoByCodigo(nfcCode);

      if (artigo != null && mounted) {
        _stopNFCSession();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ArtigoDetailScreen(artigo: artigo),
          ),
        );
      } else if (mounted) {
        _showErrorDialog('Artigo não encontrado', 'Código NFC: $nfcCode');
        setState(() {
          _isSearching = false;
          _statusMessage = 'Aproxime a etiqueta NFC';
        });
      }
    } catch (e) {
      print('❌ Erro ao buscar artigo: $e');
      if (mounted) {
        _showErrorDialog(
          'Erro na busca', 
          'Não foi possível buscar o artigo.\n\n$e'
        );
        setState(() {
          _isSearching = false;
          _statusMessage = 'Aproxime a etiqueta NFC';
        });
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Scanner NFC'),
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animação de ondas NFC
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_animationController.value * 0.1),
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFF6B35).withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.nfc,
                      size: 120,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            // Status
            if (_isSearching)
              const Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFFFF6B35)),
                  SizedBox(height: 16),
                  Text(
                    'Procurando artigo...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isNFCAvailable)
                    const Text(
                      '📲 Mantenha o dispositivo próximo\nà etiqueta NFC',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                ],
              ),

            const SizedBox(height: 40),

            // Info
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isNFCAvailable 
                    ? Colors.green.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isNFCAvailable ? Colors.green : Colors.orange,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _isNFCAvailable ? Icons.check_circle : Icons.info_outline,
                    color: _isNFCAvailable ? Colors.green : Colors.orange,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isNFCAvailable 
                        ? '✅ NFC Ativo e Pronto'
                        : '⚠️ NFC Não Disponível',
                    style: TextStyle(
                      color: _isNFCAvailable ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isNFCAvailable
                        ? 'Aproxime uma etiqueta NFC para começar'
                        : 'Verifique se o NFC está ativo\nnas definições do dispositivo',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}