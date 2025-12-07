import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../SERVICE/API.dart';
import '../models/models.dart';
import '../helpers/artigo_navigation_helper.dart';

/// Scanner RFID para dispositivos Zebra TC22 com DataWedge
/// 
/// NOTA: Requer configuração do DataWedge no dispositivo Zebra.
/// O MainActivity.kt configura automaticamente o perfil DataWedge.
/// Documentação: https://techdocs.zebra.com/datawedge/
class RFIDScannerScreen extends StatefulWidget {
  const RFIDScannerScreen({super.key});

  @override
  State<RFIDScannerScreen> createState() => _RFIDScannerScreenState();
}

class _RFIDScannerScreenState extends State<RFIDScannerScreen>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  bool _isSearching = false;
  bool _isScanning = false;
  bool _isRFIDAvailable = false;
  String _statusMessage = 'A verificar dispositivo...';
  List<String> _detectedTags = [];
  late AnimationController _animationController;

  // Canais de comunicação com código nativo
  static const MethodChannel _methodChannel = MethodChannel('com.armazem.rfid');
  static const EventChannel _eventChannel = EventChannel('com.armazem.rfid/scan');
  
  StreamSubscription<dynamic>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _checkRFIDAvailability();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _stopScanning();
    _scanSubscription?.cancel();
    _scanSubscription = null;
    super.dispose();
  }

  /// Verifica se o dispositivo suporta RFID (Zebra com DataWedge)
  Future<void> _checkRFIDAvailability() async {
    try {
      final bool isAvailable = await _methodChannel.invokeMethod('isAvailable');
      
      if (!mounted) return;
      
      setState(() {
        _isRFIDAvailable = isAvailable;
        _statusMessage = isAvailable 
            ? 'Pronto para escanear' 
            : 'RFID não disponível neste dispositivo';
      });
      
      if (isAvailable) {
        _initializeRFIDStream();
      }
    } on PlatformException catch (e) {
      print(' Erro ao verificar RFID: ${e.message}');
      if (!mounted) return;
      setState(() {
        _isRFIDAvailable = false;
        _statusMessage = 'Erro ao verificar RFID';
      });
    } on MissingPluginException catch (e) {
      print(' Plugin RFID não implementado: ${e.message}');
      if (!mounted) return;
      setState(() {
        _isRFIDAvailable = false;
        _statusMessage = 'Plugin RFID não configurado';
      });
    }
  }

  /// Inicializa o stream de eventos RFID
  void _initializeRFIDStream() {
    _scanSubscription?.cancel();
    
    _scanSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (!mounted) return;
        if (event is String && event.isNotEmpty) {
          _onRFIDDetected(event);
        }
      },
      onError: (dynamic error) {
        print(' Erro no stream RFID: $error');
        if (!mounted) return;
        setState(() {
          _statusMessage = 'Erro na comunicação RFID';
        });
      },
      cancelOnError: false,
    );
    
    print('📡 Stream RFID inicializado');
  }

  /// Inicia o scan RFID
  Future<void> _startScanning() async {
    if (!_isRFIDAvailable) return;
    
    try {
      await _methodChannel.invokeMethod('startScan');
      
      if (!mounted) return;
      
      setState(() {
        _isScanning = true;
        _statusMessage = 'Escaneando...';
        _detectedTags.clear();
      });
      
      print('📡 Scanner RFID iniciado');
    } on PlatformException catch (e) {
      print(' Erro ao iniciar scan: ${e.message}');
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Erro ao iniciar scan';
      });
    }
  }

  /// Para o scan RFID
  Future<void> _stopScanning() async {
    try {
      await _methodChannel.invokeMethod('stopScan');
    } on PlatformException catch (e) {
      print(' Erro ao parar scan: ${e.message}');
    }
    
    if (!mounted) return;
    
    setState(() {
      _isScanning = false;
      if (_statusMessage == 'Escaneando...') {
        _statusMessage = 'Scan parado';
      }
    });
    
    print('📡 Scanner RFID parado');
  }

  /// Callback quando uma tag RFID é detectada
  void _onRFIDDetected(String rfidTag) async {
    if (_isSearching || !mounted) return;

    print('📡 Tag RFID detectada: $rfidTag');

    // Adiciona à lista de tags detectadas (sem duplicados)
    if (!_detectedTags.contains(rfidTag)) {
      setState(() {
        _detectedTags.add(rfidTag);
      });
    }

    await _searchArticle(rfidTag);
  }

  /// Pesquisa artigo pelo código RFID
  Future<void> _searchArticle(String rfidCode) async {
    if (_isSearching || !mounted) return;

    setState(() {
      _isSearching = true;
      _statusMessage = 'Procurando artigo...';
    });
    
    await _stopScanning();

    try {
      final artigo = await _apiService.getArtigoByCodigo(rfidCode);

      if (!mounted) return;

      if (artigo != null) {
        await ArtigoNavigationHelper.navigateToArtigoDetail(context, artigo);
        
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        _showErrorDialog('Artigo não encontrado', 'Tag RFID: $rfidCode');
        setState(() {
          _isSearching = false;
          _statusMessage = 'Pronto para escanear';
        });
      }
    } catch (e) {
      print(' Erro ao buscar artigo: $e');
      if (!mounted) return;
      
      _showErrorDialog(
        'Erro na busca', 
        'Não foi possível buscar o artigo.\n\n$e'
      );
      setState(() {
        _isSearching = false;
        _statusMessage = 'Pronto para escanear';
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
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (mounted && _isRFIDAvailable) {
                  _startScanning();
                }
              },
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
        title: const Text('Scanner RFID'),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFE63946).withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animação RFID
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: RFIDWavePainter(
                      _isScanning ? _animationController.value : 0,
                    ),
                    child: SizedBox(
                      width: 250,
                      height: 250,
                      child: Center(
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE63946).withOpacity(0.1),
                          ),
                          child: Icon(
                            _isRFIDAvailable 
                                ? Icons.contactless 
                                : Icons.portable_wifi_off,
                            size: 80,
                            color: _isRFIDAvailable 
                                ? const Color(0xFFE63946)
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
              
              // Mensagem de status
              Text(
                _statusMessage,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Status de pesquisa ou tags detectadas
              if (_isSearching)
                Column(
                  children: [
                    const CircularProgressIndicator(
                      color: Color(0xFFE63946),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Procurando artigo...',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              else if (_detectedTags.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE63946).withOpacity(0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Tags detectadas:',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._detectedTags.map(
                        (tag) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE63946).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                color: Color(0xFFE63946),
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 40),

              // Botão Start/Stop
              if (!_isSearching && _isRFIDAvailable)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE63946).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? _stopScanning : _startScanning,
                    icon: Icon(
                      _isScanning ? Icons.stop : Icons.play_arrow, 
                      size: 24,
                    ),
                    label: Text(
                      _isScanning ? 'PARAR SCAN' : 'INICIAR SCAN',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE63946),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              
              // Mensagem quando RFID não disponível
              if (!_isRFIDAvailable)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.grey[400],
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Este dispositivo não suporta RFID.\n'
                        'Use um dispositivo Zebra com DataWedge.',
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

/// Painter para ondas RFID animadas
class RFIDWavePainter extends CustomPainter {
  final double progress;

  RFIDWavePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return; // Não desenha ondas se não está a escanear
    
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final radius = maxRadius * ((progress + (i * 0.33)) % 1.0);
      final opacity = 1.0 - ((progress + (i * 0.33)) % 1.0);

      final paint = Paint()
        ..color = const Color(0xFFE63946).withOpacity(opacity * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(RFIDWavePainter oldDelegate) => 
      oldDelegate.progress != progress;
}