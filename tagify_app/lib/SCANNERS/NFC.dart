import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../SERVICE/API.dart';
import '../models/models.dart';
import '../helpers/artigo_navigation_helper.dart';

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
  bool _isSessionActive = false;
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
      
      if (!mounted) return;
      
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
      if (!mounted) return;
      setState(() {
        _isNFCAvailable = false;
        _statusMessage = 'Erro ao verificar NFC';
      });
    }
  }

  void _startNFCSession() {
    if (_isSessionActive) return;
    
    NfcManager.instance.startSession(
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (NfcTag tag) async {
        print('Tag NFC detectada');
        
        if (!mounted) return;
        
        try {
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
        } catch (e) {
          print('Erro ao processar tag: $e');
          if (mounted) {
            setState(() {
              _statusMessage = 'Erro ao ler NFC';
            });
          }
        }
      },
    );

    _isSessionActive = true;
    print('Sessão NFC iniciada');
  }


  void _stopNFCSession() {
    if (!_isSessionActive) return;
    
    try {
      NfcManager.instance.stopSession();
      _isSessionActive = false;
      print('Sessão NFC parada');
    } catch (e) {
      print('Erro ao parar sessão NFC: $e');
    }
  }

  String? _extractNFCId(NfcTag tag) {
    try {
      final Map<String, dynamic> tagData = Map<String, dynamic>.from(tag.data as Map);
      
      print('Tag data keys: ${tagData.keys.toList()}');
      
      // Tentar ler NDEF primeiro (texto gravado na tag)
      if (tagData.containsKey('ndef')) {
        final ndefData = tagData['ndef'] as Map<String, dynamic>?;
        if (ndefData != null && ndefData.containsKey('cachedMessage')) {
          final cachedMessage = ndefData['cachedMessage'] as Map<String, dynamic>?;
          if (cachedMessage != null && cachedMessage.containsKey('records')) {
            final records = cachedMessage['records'] as List<dynamic>?;
            if (records != null && records.isNotEmpty) {
              final firstRecord = records.first as Map<String, dynamic>;
              if (firstRecord.containsKey('payload')) {
                final payload = firstRecord['payload'] as List<dynamic>;
                if (payload.length > 3) {
                  // Ignora os primeiros 3 bytes (language code)
                  final textBytes = payload.sublist(3);
                  String text = String.fromCharCodes(
                    textBytes.map((e) => e as int).toList()
                  ).trim();
                  print('NDEF Text: $text');
                  return text;
                }
              }
            }
          }
        }
      }
      
      // Fallback: extrair ID do hardware
      if (tagData.containsKey('nfca')) {
        final nfcaData = tagData['nfca'] as Map<String, dynamic>?;
        if (nfcaData != null && nfcaData.containsKey('identifier')) {
          final identifier = nfcaData['identifier'] as List<dynamic>;
          String id = identifier
              .map((byte) => (byte as int).toRadixString(16).padLeft(2, '0'))
              .join(':')
              .toUpperCase();
          print('NFC-A ID: $id');
          return id;
        }
      }
      
      // Tentar NFC-B
      if (tagData.containsKey('nfcb')) {
        final nfcbData = tagData['nfcb'] as Map<String, dynamic>?;
        if (nfcbData != null && nfcbData.containsKey('identifier')) {
          final identifier = nfcbData['identifier'] as List<dynamic>;
          String id = identifier
              .map((byte) => (byte as int).toRadixString(16).padLeft(2, '0'))
              .join(':')
              .toUpperCase();
          print('NFC-B ID: $id');
          return id;
        }
      }
      
      // Tentar NFC-F
      if (tagData.containsKey('nfcf')) {
        final nfcfData = tagData['nfcf'] as Map<String, dynamic>?;
        if (nfcfData != null && nfcfData.containsKey('identifier')) {
          final identifier = nfcfData['identifier'] as List<dynamic>;
          String id = identifier
              .map((byte) => (byte as int).toRadixString(16).padLeft(2, '0'))
              .join(':')
              .toUpperCase();
          print('NFC-F ID: $id');
          return id;
        }
      }
      
      // Tentar NFC-V (ISO 15693)
      if (tagData.containsKey('nfcv')) {
        final nfcvData = tagData['nfcv'] as Map<String, dynamic>?;
        if (nfcvData != null && nfcvData.containsKey('identifier')) {
          final identifier = nfcvData['identifier'] as List<dynamic>;
          String id = identifier
              .map((byte) => (byte as int).toRadixString(16).padLeft(2, '0'))
              .join(':')
              .toUpperCase();
          print('NFC-V ID: $id');
          return id;
        }
      }
      
      return null;
    } catch (e) {
      print('Erro ao extrair ID NFC: $e');
      return null;
    }
  }

  Future<void> _searchArticle(String nfcCode) async {
    if (_isSearching || !mounted) return;

    setState(() {
      _isSearching = true;
      _statusMessage = 'Procurando artigo...';
    });

    print('Procurando artigo com código NFC: $nfcCode');

    try {
      final artigo = await _apiService.getArtigoByCodigo(nfcCode);

      if (!mounted) return;

      if (artigo != null) {
        _stopNFCSession();
        
        await ArtigoNavigationHelper.navigateToArtigoDetail(context, artigo);
        
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        _showErrorDialog('Artigo não encontrado', 'Código NFC: $nfcCode');
        setState(() {
          _isSearching = false;
          _statusMessage = 'Aproxime a etiqueta NFC';
        });
      }
    } catch (e) {
      print('Erro ao buscar artigo: $e');
      if (!mounted) return;
      
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

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Scanner NFC'),
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFF6B35).withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animação de ondas NFC
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: _isNFCAvailable && !_isSearching
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFF6B35).withOpacity(
                                  0.3 * (1 - _animationController.value)
                                ),
                                blurRadius: 40 * _animationController.value,
                                spreadRadius: 20 * _animationController.value,
                              ),
                            ]
                          : [],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFF6B35).withOpacity(0.1),
                      ),
                      child: Icon(
                        _isNFCAvailable ? Icons.nfc : Icons.nfc_rounded,
                        size: 100,
                        color: _isNFCAvailable 
                            ? const Color(0xFFFF6B35)
                            : Colors.grey,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Mensagem de status
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 24),

              // Indicador de pesquisa
              if (_isSearching)
                Column(
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFFFF6B35),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Procurando artigo...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),

              // Instruções quando NFC não disponível
              if (!_isNFCAvailable)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Icon(
                        Icons.info_outline,
                        color: Colors.grey[400],
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Verifique se o NFC está ativado\nnas definições do dispositivo.',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}