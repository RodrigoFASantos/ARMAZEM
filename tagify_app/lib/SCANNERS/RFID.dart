import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../SERVICE/API.dart';
import '../models/models.dart';
import '../helpers/artigo_navigation_helper.dart';

// NOTA: Para RFID funcionar no Zebra TC22, precisa configurar DataWedge
// Documentação: https://techdocs.zebra.com/datawedge/

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
  String _statusMessage = 'Pronto para escanear';
  List<String> _detectedTags = [];
  late AnimationController _animationController;

  static const platform = MethodChannel('com.armazem.rfid');
  static const EventChannel scanChannel = EventChannel('com.armazem.rfid/scan');

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _initializeRFID();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _stopScanning();
    super.dispose();
  }

  Future<void> _initializeRFID() async {
    scanChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is String) {
          _onRFIDDetected(event);
        }
      },
      onError: (dynamic error) {
        print('❌ Erro no canal RFID: $error');
      },
    );
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Escaneando...';
      _detectedTags.clear();
    });

    print('📡 Scanner RFID iniciado (simulado)');
  }

  void _stopScanning() {
    setState(() {
      _isScanning = false;
      _statusMessage = 'Scan parado';
    });

    print('📡 Scanner RFID parado (simulado)');
  }

  void _onRFIDDetected(String rfidTag) async {
    if (_isSearching) return;

    print('📡 Tag RFID detectada: $rfidTag');

    if (!_detectedTags.contains(rfidTag)) {
      setState(() {
        _detectedTags.add(rfidTag);
      });
    }

    await _searchArticle(rfidTag);
  }

  Future<void> _searchArticle(String rfidCode) async {
    if (_isSearching) return;

    setState(() => _isSearching = true);
    _stopScanning();

    try {
      final artigo = await _apiService.getArtigoByCodigo(rfidCode);

      if (artigo != null && mounted) {
        await ArtigoNavigationHelper.navigateToArtigoDetail(context, artigo);
        
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else if (mounted) {
        _showErrorDialog('Artigo não encontrado', 'Tag RFID: $rfidCode');
        setState(() => _isSearching = false);
      }
    } catch (e) {
      print('❌ Erro ao buscar artigo: $e');
      if (mounted) {
        _showErrorDialog('Erro na busca', 'Não foi possível buscar o artigo.\n\n$e');
        setState(() => _isSearching = false);
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
              onPressed: () {
                Navigator.of(context).pop();
                _startScanning();
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
                    painter: RFIDWavePainter(_animationController.value),
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
                          child: const Icon(
                            Icons.contactless,
                            size: 80,
                            color: Color(0xFFE63946),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // Status
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
              else
                Column(
                  children: [
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_detectedTags.isNotEmpty)
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
                  ],
                ),

              const SizedBox(height: 40),

              // Botão Start/Stop
              if (!_isSearching)
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
                    icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow, size: 24),
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

              const SizedBox(height: 40),

              // Info Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                    width: 2,
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
                    const Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 36,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'NOTA: Para ativar RFID no Zebra TC22',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1. Configurar DataWedge no dispositivo\n'
                      '2. Criar canal nativo (MethodChannel)\n'
                      '3. Adicionar código Kotlin/Java\n'
                      '4. Descomentar código no ficheiro',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        height: 1.5,
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

// Painter para ondas RFID
class RFIDWavePainter extends CustomPainter {
  final double progress;

  RFIDWavePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
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
  bool shouldRepaint(RFIDWavePainter oldDelegate) => true;
}