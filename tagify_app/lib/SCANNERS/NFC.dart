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
            : 'NFC nao disponivel neste dispositivo';
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
      pollingOptions: {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
        NfcPollingOption.iso18092,
      },
      onDiscovered: (NfcTag tag) async {
        print('Tag NFC detectada');
        
        try {
          String? nfcId = _extractNFCId(tag);
          
          if (nfcId != null) {
            await _searchArticle(nfcId);
          } else {
            if (mounted) {
              _showErrorDialog(
                'Erro ao ler NFC', 
                'Nao foi possivel extrair o ID da tag'
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

    print('Sessao NFC iniciada');
  }

  void _stopNFCSession() {
    try {
      NfcManager.instance.stopSession();
      print('Sessao NFC parada');
    } catch (e) {
      print('Erro ao parar sessao NFC: $e');
    }
  }

  String? _extractNFCId(NfcTag tag) {
    try {
      // Converter tag.data para Map
      final Map<String, dynamic> tagData = Map<String, dynamic>.from(tag.data as Map);
      
      print('Tag data keys: ${tagData.keys.toList()}');
      
      // Tentar ler NDEF primeiro (dados gravados na tag)
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
                // Converter payload para string (remover bytes de controle)
                if (payload.length > 3) {
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
      
      // Tentar extrair ID do hardware (fallback)
      // NfcA - mais comum
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
      
      // NfcB
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
      
      // NfcF
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
      
      // NfcV
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
      
      // MiFare
      if (tagData.containsKey('mifare')) {
        final mifareData = tagData['mifare'] as Map<String, dynamic>?;
        if (mifareData != null && mifareData.containsKey('identifier')) {
          final identifier = mifareData['identifier'] as List<dynamic>;
          String id = identifier
              .map((byte) => (byte as int).toRadixString(16).padLeft(2, '0'))
              .join(':')
              .toUpperCase();
          print('MiFare ID: $id');
          return id;
        }
      }
      
      // IsoDep
      if (tagData.containsKey('isodep')) {
        final isoDepData = tagData['isodep'] as Map<String, dynamic>?;
        if (isoDepData != null && isoDepData.containsKey('identifier')) {
          final identifier = isoDepData['identifier'] as List<dynamic>;
          String id = identifier
              .map((byte) => (byte as int).toRadixString(16).padLeft(2, '0'))
              .join(':')
              .toUpperCase();
          print('IsoDep ID: $id');
          return id;
        }
      }
      
      print('Nao foi possivel extrair ID da tag');
      print('Dados disponiveis: ${tagData.keys.toList()}');
      return null;
    } catch (e) {
      print('Erro ao extrair ID NFC: $e');
      return null;
    }
  }

  Future<void> _searchArticle(String nfcCode) async {
    if (_isSearching) return;

    setState(() {
      _isSearching = true;
      _statusMessage = 'Procurando artigo...';
    });

    print('Procurando artigo com codigo NFC: $nfcCode');

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
        _showErrorDialog('Artigo nao encontrado', 'Codigo NFC: $nfcCode');
        setState(() {
          _isSearching = false;
          _statusMessage = 'Aproxime a etiqueta NFC';
        });
      }
    } catch (e) {
      print('Erro ao buscar artigo: $e');
      if (mounted) {
        _showErrorDialog(
          'Erro na busca', 
          'Nao foi possivel buscar o artigo.\n\n$e'
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
            // Animacao de ondas NFC
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
                      'Mantenha o dispositivo proximo\na etiqueta NFC',
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
                        ? 'NFC Ativo e Pronto'
                        : 'NFC Nao Disponivel',
                    style: TextStyle(
                      color: _isNFCAvailable ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isNFCAvailable
                        ? 'Aproxime uma etiqueta NFC para comecar'
                        : 'Verifique se o NFC esta ativo\nnas definicoes do dispositivo',
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