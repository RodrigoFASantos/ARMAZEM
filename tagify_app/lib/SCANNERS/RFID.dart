import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../SERVICE/API.dart';
import '../models/models.dart';
import '../SCREENS/SCREENS_artigo_detail_screen.dart';

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

    // TODO: Configurar DataWedge via Intent
    /*
    try {
      await platform.invokeMethod('configureDataWedge');
      setState(() {
        _statusMessage = 'RFID pronto';
      });
    } catch (e) {
      print('Erro ao configurar DataWedge: $e');
      setState(() {
        _statusMessage = 'Erro ao inicializar RFID';
      });
    }
    */
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Escaneando...';
      _detectedTags.clear();
    });

    // TODO: Enviar Intent para iniciar scan
    /*
    platform.invokeMethod('startRFIDScan');
    */

    print('📡 Scanner RFID iniciado (simulado)');
  }

  void _stopScanning() {
    setState(() {
      _isScanning = false;
      _statusMessage = 'Scan parado';
    });

    // TODO: Enviar Intent para parar scan
    /*
    platform.invokeMethod('stopRFIDScan');
    */

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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ArtigoDetailScreen(artigo: artigo),
          ),
        );
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
                _startScanning(); // Reinicia scan
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
      backgroundColor: const Color(0xFF0F0F23),
      appBar: AppBar(
        title: const Text('Scanner RFID'),
        backgroundColor: const Color(0xFFE63946),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: RFIDWavePainter(_animationController.value),
                  child: const SizedBox(
                    width: 250,
                    height: 250,
                    child: Center(
                      child: Icon(
                        Icons.contactless,
                        size: 120,
                        color: Color(0xFFE63946),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            if (_isSearching)
              const Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFFE63946)),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_detectedTags.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Tags detectadas:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._detectedTags.map(
                            (tag) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  color: Color(0xFFE63946),
                                  fontFamily: 'monospace',
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

            if (!_isSearching)
              ElevatedButton.icon(
                onPressed: _isScanning ? _stopScanning : _startScanning,
                icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
                label: Text(_isScanning ? 'PARAR SCAN' : 'INICIAR SCAN'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE63946),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            const SizedBox(height: 40),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: const Column(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'NOTA: Para ativar RFID no Zebra TC22',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Configurar DataWedge no dispositivo\n'
                    '2. Criar canal nativo (MethodChannel)\n'
                    '3. Adicionar código Kotlin/Java\n'
                    '4. Descomentar código no ficheiro',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
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
        ..color = const Color(0xFFE63946).withOpacity(opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(RFIDWavePainter oldDelegate) => true;
}