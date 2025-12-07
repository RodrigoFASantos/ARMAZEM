import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../SERVICE/API.dart';
import '../models/models.dart';
import '../helpers/artigo_navigation_helper.dart';
import 'armazem_screen.dart';
import '../SCANNERS/AR.dart';

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
  bool _isDisposed = false;
  bool _isSwitching = false;
  
  // ✅ ALTERADO: Agora inicia com BARCODE por defeito
  ScanMethod _selectedMethod = ScanMethod.barcode;
  int _selectedBottomIndex = 1;
  
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // ✅ ALTERADO: Inicia com MobileScanner (para barcode)
    _initializeMobileScanner();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _disposeAllCameras();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _disposeAllCameras();
    } else if (state == AppLifecycleState.resumed) {
      _reinitializeCurrentScanner();
    }
  }

  Future<void> _reinitializeCurrentScanner() async {
    if (_selectedMethod == ScanMethod.qrcode || _selectedMethod == ScanMethod.barcode) {
      await _initializeMobileScanner();
    } else if (_selectedMethod == ScanMethod.ar) {
      await _initializeCamera();
    }
  }

  Future<void> _disposeAllCameras() async {
    final cameraController = _cameraController;
    _cameraController = null;
    
    final mobileScannerController = _mobileScannerController;
    _mobileScannerController = null;
    
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
      });
    }
    
    try {
      // ✅ Para o MobileScanner antes de fazer dispose
      if (mobileScannerController != null) {
        await mobileScannerController.stop();
        await Future.delayed(const Duration(milliseconds: 100));
        await mobileScannerController.dispose();
      }
      
      await cameraController?.dispose();
      print('🔴 Câmaras libertadas');
    } catch (e) {
      print('Erro ao libertar câmaras: $e');
    }
  }

  Future<void> _disposeCameraController() async {
    final controller = _cameraController;
    _cameraController = null;
    
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
      });
    }
    
    try {
      await controller?.dispose();
      print('🔴 CameraController libertado');
    } catch (e) {
      print('Erro ao libertar CameraController: $e');
    }
  }

  Future<void> _disposeMobileScannerController() async {
    final controller = _mobileScannerController;
    _mobileScannerController = null;
    
    if (controller == null) {
      print('⚠️ MobileScannerController já era null');
      return;
    }
    
    try {
      // ✅ Para a câmara antes de fazer dispose
      await controller.stop();
      await Future.delayed(const Duration(milliseconds: 100));
      await controller.dispose();
      print('🔴 MobileScannerController libertado');
    } catch (e) {
      print('Erro ao libertar MobileScannerController: $e');
    }
  }

  Future<void> _initializeCamera() async {
    if (_isDisposed) return;
    
    try {
      _cameras ??= await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        print('Nenhuma câmara disponível');
        return;
      }

      final controller = CameraController(
        _cameras![0],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      
      if (_isDisposed) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
      
      print('✅ CameraController inicializado');
    } catch (e) {
      print('❌ Erro ao inicializar câmara: $e');
    }
  }

  Future<void> _initializeMobileScanner() async {
    if (_isDisposed) return;
    
    // ✅ Garante que o controller anterior foi libertado
    if (_mobileScannerController != null) {
      print('⚠️ MobileScannerController já existe, a libertar primeiro...');
      await _disposeMobileScannerController();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    print('📷 A criar MobileScannerController...');
    
    try {
      final controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        returnImage: false,
      );
      
      // ✅ Aguarda que o controller esteja realmente pronto
      await controller.start();
      
      print('📷 MobileScannerController iniciado, a aguardar...');
      
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (_isDisposed) {
        await controller.dispose();
        return;
      }
      
      _mobileScannerController = controller;
      
      if (mounted) {
        setState(() {});
        print('✅ MobileScannerController inicializado e UI atualizada');
      }
    } catch (e) {
      print('❌ Erro ao inicializar MobileScanner: $e');
      
      // ✅ Tenta novamente após um delay
      if (mounted && !_isDisposed) {
        print('🔄 A tentar reinicializar MobileScanner...');
        await Future.delayed(const Duration(milliseconds: 500));
        
        try {
          _mobileScannerController = MobileScannerController(
            detectionSpeed: DetectionSpeed.noDuplicates,
            facing: CameraFacing.back,
            returnImage: false,
          );
          
          if (mounted) {
            setState(() {});
            print('✅ MobileScannerController reinicializado com sucesso');
          }
        } catch (e2) {
          print('❌ Segunda tentativa falhou: $e2');
        }
      }
    }
  }

  Future<void> _handleScanMethodChange(ScanMethod method) async {
    if (method == _selectedMethod || _isSwitching) return;

    setState(() {
      _isSwitching = true;
    });

    // NFC, RFID e AR abrem páginas dedicadas
    if (method == ScanMethod.nfc) {
      setState(() => _isSwitching = false);
      _navigateToExternalScanner('/nfc');
      return;
    } else if (method == ScanMethod.rfid) {
      setState(() => _isSwitching = false);
      _navigateToExternalScanner('/rfid');
      return;
    } else if (method == ScanMethod.ar) {
      setState(() => _isSwitching = false);
      _navigateToARScanner();
      return;
    }

    final previousMethod = _selectedMethod;
    
    setState(() {
      _selectedMethod = method;
    });

    try {
      // TRANSIÇÃO: AR -> QR/Barcode
      if ((previousMethod == ScanMethod.ar) && 
          (method == ScanMethod.qrcode || method == ScanMethod.barcode)) {
        print('🔄 Transição: AR -> ${method.name}');
        
        await _disposeCameraController();
        
        print('⏳ A aguardar libertação do hardware...');
        await Future.delayed(const Duration(milliseconds: 500));
        
        await _initializeMobileScanner();
      }
      // TRANSIÇÃO: QR/Barcode -> AR
      else if ((previousMethod == ScanMethod.qrcode || previousMethod == ScanMethod.barcode) && 
               method == ScanMethod.ar) {
        print('🔄 Transição: ${previousMethod.name} -> AR');
        
        await _disposeMobileScannerController();
        
        print('⏳ A aguardar libertação do hardware...');
        await Future.delayed(const Duration(milliseconds: 500));
        
        await _initializeCamera();
      }
      // TRANSIÇÃO: QR <-> Barcode (mesmo tipo de scanner)
      else if ((previousMethod == ScanMethod.qrcode && method == ScanMethod.barcode) ||
               (previousMethod == ScanMethod.barcode && method == ScanMethod.qrcode)) {
        print('🔄 Transição: ${previousMethod.name} -> ${method.name} (mesmo scanner)');
        // Não precisa fazer nada, apenas muda o overlay
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSwitching = false;
        });
      }
    }
  }

  Future<void> _navigateToExternalScanner(String route) async {
    await _disposeAllCameras();
    
    if (!mounted) return;
    
    await Navigator.of(context).pushNamed(route);
    
    // ✅ CORRIGIDO: Aguarda mais tempo para libertar recursos da câmara
    if (mounted && !_isDisposed) {
      print('🔄 A voltar do scanner externo, aguardando libertação de recursos...');
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Força recriação do MobileScanner
      setState(() {
        _mobileScannerController = null;
      });
      
      await Future.delayed(const Duration(milliseconds: 200));
      await _reinitializeCurrentScanner();
    }
  }

  Future<void> _navigateToARScanner() async {
    await _disposeAllCameras();
    
    if (!mounted) return;
    
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ARScannerScreen()),
    );
    
    // ✅ CORRIGIDO: Aguarda mais tempo para libertar recursos da câmara
    if (mounted && !_isDisposed) {
      print('🔄 A voltar do AR, aguardando libertação de recursos...');
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Força recriação do MobileScanner
      setState(() {
        _mobileScannerController = null;
      });
      
      await Future.delayed(const Duration(milliseconds: 200));
      await _reinitializeCurrentScanner();
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isSearching) return;
    
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    
    setState(() => _isSearching = true);
    
    try {
      final artigo = await _apiService.getArtigoByCodigo(code);
      
      if (artigo != null && mounted) {
        await ArtigoNavigationHelper.navigateToArtigoDetail(context, artigo);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Artigo não encontrado: $code'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao procurar artigo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _handleBottomNavigation(int index) {
    if (index == 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ArmazemScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Área da câmara
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                child: Stack(
                  children: [
                    // Preview da câmara
                    Positioned.fill(
                      child: _buildCameraPreview(),
                    ),
                    
                    // Overlay
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _selectedMethod == ScanMethod.barcode
                            ? BarcodeOverlayPainter()
                            : QROverlayPainter(),
                      ),
                    ),
                    
                    // Indicador de pesquisa
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
                                'A procurar artigo...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Instrução
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
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

            const SizedBox(height: 16),

            // ✅ ALTERADO: Barra de métodos com BARRAS no centro
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
                  // ✅ BARRAS agora está no CENTRO (posição 3)
                  _buildScanMethodButton(
                    method: ScanMethod.barcode,
                    icon: Icons.barcode_reader,
                    label: 'Barras',
                  ),
                  // ✅ AR trocou de posição (posição 4)
                  _buildScanMethodButton(
                    method: ScanMethod.ar,
                    icon: Icons.view_in_ar,
                    label: 'AR',
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

  Widget _buildCameraPreview() {
    // Para AR usa CameraController
    if (_selectedMethod == ScanMethod.ar) {
      if (_isCameraInitialized && _cameraController != null) {
        return CameraPreview(_cameraController!);
      }
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    
    // Para QR/Barcode usa MobileScanner
    return _buildMobileScanner();
  }

  Widget _buildMobileScanner() {
    if (_mobileScannerController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'A inicializar scanner...',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    
    // ✅ Key única baseada no hashCode do controller para forçar recriação
    return MobileScanner(
      key: ValueKey(_mobileScannerController.hashCode),
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
        onTap: _isSwitching ? null : () => _handleScanMethodChange(method),
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: _isSwitching ? 0.5 : 1.0,
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
      ),
    );
  }

  String _getInstructionText() {
    if (_isSwitching) {
      return 'A preparar scanner...';
    }
    
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