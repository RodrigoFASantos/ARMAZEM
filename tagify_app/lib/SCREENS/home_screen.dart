import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../SERVICE/API.dart';
import '../models/models.dart';
import '../helpers/artigo_navigation_helper.dart';
import 'armazem_screen.dart';

enum ScanMethod { rfid, nfc, ar, barcode, qrcode }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  MobileScannerController? _mobileScannerController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isSearching = false;
  ScanMethod _selectedMethod = ScanMethod.ar;
  int _selectedBottomIndex = 0; // 0 = Armazém, 1 = Câmara
  
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _mobileScannerController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _cameraController;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
      _mobileScannerController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        print('Nenhuma câmara disponível');
        return;
      }

      _cameraController = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('Erro ao inicializar câmara: $e');
    }
  }

  void _handleScanMethodChange(ScanMethod method) {
    if (method == _selectedMethod) return;

    setState(() {
      _selectedMethod = method;
    });

    // Se for QR ou Barcode, inicializar mobile_scanner
    if (method == ScanMethod.qrcode || method == ScanMethod.barcode) {
      _initializeMobileScanner();
    } else {
      // Voltar para câmara normal
      _mobileScannerController?.dispose();
      _mobileScannerController = null;
    }

    // NFC e RFID abrem páginas dedicadas
    if (method == ScanMethod.nfc) {
      Navigator.pushNamed(context, '/nfc').then((_) {
        setState(() => _selectedMethod = ScanMethod.ar);
      });
    } else if (method == ScanMethod.rfid) {
      Navigator.pushNamed(context, '/rfid').then((_) {
        setState(() => _selectedMethod = ScanMethod.ar);
      });
    }
  }

  void _initializeMobileScanner() {
    _mobileScannerController?.dispose();
    _mobileScannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isSearching) return;

    final List<Barcode> barcodes = capture.barcodes;
    
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      
      if (code != null && code.isNotEmpty) {
        setState(() => _isSearching = true);
        _mobileScannerController?.stop();

        print('📱 Código detectado: $code');

        try {
          final artigo = await _apiService.getArtigoByCodigo(code);

          if (artigo != null && mounted) {
            await ArtigoNavigationHelper.navigateToArtigoDetail(context, artigo);
            
            if (mounted) {
              setState(() {
                _isSearching = false;
                _selectedMethod = ScanMethod.ar;
              });
              _mobileScannerController?.dispose();
              _mobileScannerController = null;
            }
          } else if (mounted) {
            _showErrorDialog('Artigo não encontrado', 'Código: $code');
            setState(() => _isSearching = false);
            _mobileScannerController?.start();
          }
        } catch (e) {
          print('❌ Erro ao buscar artigo: $e');
          if (mounted) {
            _showErrorDialog('Erro na busca', 'Não foi possível buscar o artigo.\n\n$e');
            setState(() => _isSearching = false);
            _mobileScannerController?.start();
          }
        }

        break;
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

  void _handleBottomNavigation(int index) {
    if (index == _selectedBottomIndex) return;

    setState(() {
      _selectedBottomIndex = index;
    });

    if (index == 0) {
      // Navegar para Armazém
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const ArmazemScreen(),
        ),
      ).then((_) {
        setState(() {
          _selectedBottomIndex = 1;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cameraSize = screenSize.width * 0.85; // 85% da largura
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // Área da câmara QUADRADA e MAIOR
            Expanded(
              child: Center(
                child: Container(
                  width: cameraSize,
                  height: cameraSize,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // Preview da câmara ou mobile scanner
                      if (_selectedMethod == ScanMethod.qrcode || 
                          _selectedMethod == ScanMethod.barcode)
                        _buildMobileScanner()
                      else if (_isCameraInitialized && _cameraController != null)
                        Center(
                          child: CameraPreview(_cameraController!),
                        )
                      else
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.blue),
                              const SizedBox(height: 16),
                              Text(
                                'A inicializar câmara...',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Overlay para QR/Barcode
                      if (_selectedMethod == ScanMethod.qrcode)
                        CustomPaint(
                          painter: QROverlayPainter(),
                          child: Container(),
                        ),
                      
                      if (_selectedMethod == ScanMethod.barcode)
                        CustomPaint(
                          painter: BarcodeOverlayPainter(),
                          child: Container(),
                        ),

                      // Loading overlay
                      if (_isSearching)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: Colors.white),
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
                            ),
                          ),
                        ),

                      // Texto de instrução
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getInstructionText(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Barra de métodos de scan - NOVA ORDEM: RFID, NFC, AR, Barcode, QRCode
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildScanMethodButton(
                    method: ScanMethod.rfid,
                    icon: Icons.contactless,
                    label: 'RFID',
                  ),
                  _buildScanMethodButton(
                    method: ScanMethod.nfc,
                    icon: Icons.nfc,
                    label: 'NFC',
                  ),
                  _buildScanMethodButton(
                    method: ScanMethod.ar,
                    icon: Icons.view_in_ar,
                    label: 'AR',
                  ),
                  _buildScanMethodButton(
                    method: ScanMethod.barcode,
                    icon: Icons.barcode_reader,
                    label: 'Barras',
                  ),
                  _buildScanMethodButton(
                    method: ScanMethod.qrcode,
                    icon: Icons.qr_code_scanner,
                    label: 'QR',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Bottom navbar INVERTIDA: Armazém (esquerda), Câmara (direita)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedBottomIndex,
        onTap: _handleBottomNavigation,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey[600],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.warehouse, size: 28),
            label: 'Armazém',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt, size: 28),
            label: 'Câmara',
          ),
        ],
      ),
    );
  }

  Widget _buildMobileScanner() {
    if (_mobileScannerController == null) {
      _initializeMobileScanner();
    }
    
    return MobileScanner(
      controller: _mobileScannerController!,
      onDetect: _onBarcodeDetected,
    );
  }

  Widget _buildScanMethodButton({
    required ScanMethod method,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedMethod == method;

    return Expanded(
      child: InkWell(
        onTap: () => _handleScanMethodChange(method),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.blue : Colors.grey[700],
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.grey[700],
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInstructionText() {
    switch (_selectedMethod) {
      case ScanMethod.ar:
        return 'Aponte a câmara para o código do artigo';
      case ScanMethod.nfc:
        return 'Aproxime o dispositivo da etiqueta NFC';
      case ScanMethod.qrcode:
        return 'Posicione o QR Code dentro da moldura';
      case ScanMethod.barcode:
        return 'Alinhe o código de barras com a moldura';
      case ScanMethod.rfid:
        return 'Aproxime o dispositivo da etiqueta RFID';
    }
  }
}

// Painter para overlay QR Code
class QROverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.6);

    const padding = 60.0;
    final scanSize = size.width - (padding * 2);
    final scanArea = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: scanSize,
      height: scanSize,
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRect(scanArea),
      ),
      paint,
    );

    // Cantos verdes
    final cornerPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    const cornerLength = 40.0;
    final left = scanArea.left;
    final right = scanArea.right;
    final top = scanArea.top;
    final bottom = scanArea.bottom;

    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left, top + cornerLength), cornerPaint);
    canvas.drawLine(Offset(right, top), Offset(right - cornerLength, top), cornerPaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLength), cornerPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLength, bottom), cornerPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left, bottom - cornerLength), cornerPaint);
    canvas.drawLine(Offset(right, bottom), Offset(right - cornerLength, bottom), cornerPaint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cornerLength), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Painter para overlay Barcode
class BarcodeOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.6);

    const padding = 60.0;
    final scanArea = Rect.fromLTRB(
      padding,
      size.height / 2 - 100,
      size.width - padding,
      size.height / 2 + 100,
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRect(scanArea),
      ),
      paint,
    );

    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(scanArea, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}