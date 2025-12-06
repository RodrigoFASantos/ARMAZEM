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
  bool _isDisposed = false;
  bool _isSwitching = false; // NOVO: Flag para evitar múltiplas transições
  ScanMethod _selectedMethod = ScanMethod.ar;
  int _selectedBottomIndex = 1;
  
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
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
      // Reinicializa a câmara correta com base no modo atual
      _reinitializeCurrentScanner();
    }
  }

  /// Reinicializa o scanner correto com base no modo selecionado
  Future<void> _reinitializeCurrentScanner() async {
    if (_selectedMethod == ScanMethod.qrcode || _selectedMethod == ScanMethod.barcode) {
      await _initializeMobileScanner();
    } else if (_selectedMethod == ScanMethod.ar) {
      await _initializeCamera();
    }
  }

  /// Liberta TODAS as câmaras (CameraController e MobileScanner)
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
      await cameraController?.dispose();
      await mobileScannerController?.dispose();
      print('🔴 Câmaras libertadas');
    } catch (e) {
      print('Erro ao libertar câmaras: $e');
    }
  }

  /// Liberta apenas o CameraController (biblioteca camera)
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

  /// Liberta apenas o MobileScannerController
  Future<void> _disposeMobileScannerController() async {
    final controller = _mobileScannerController;
    _mobileScannerController = null;
    
    if (controller == null) {
      print('⚠️ MobileScannerController já era null');
      return;
    }
    
    try {
      await controller.dispose();
      print('🔴 MobileScannerController libertado');
    } catch (e) {
      print('Erro ao libertar MobileScannerController: $e');
    }
  }

  /// Inicializa o CameraController (para modo AR)
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

  /// Inicializa o MobileScannerController (para QR/Barcode)
  Future<void> _initializeMobileScanner() async {
    if (_isDisposed) return;
    
    print('📷 A criar MobileScannerController...');
    
    try {
      _mobileScannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        returnImage: false,
      );
      
      print('📷 MobileScannerController criado, a aguardar...');
      
      // Aguarda um momento para garantir inicialização
      await Future.delayed(const Duration(milliseconds: 200));
      
      if (mounted) {
        setState(() {});
        print('✅ MobileScannerController inicializado e UI atualizada');
      }
    } catch (e) {
      print('❌ Erro ao inicializar MobileScanner: $e');
    }
  }

  /// CORRIGIDO: Gestão correta da transição entre scanners
  Future<void> _handleScanMethodChange(ScanMethod method) async {
    if (method == _selectedMethod || _isSwitching) return;

    // Marca que estamos a mudar de scanner
    setState(() {
      _isSwitching = true;
    });

    // NFC e RFID abrem páginas dedicadas
    if (method == ScanMethod.nfc) {
      setState(() => _isSwitching = false);
      _navigateToExternalScanner('/nfc');
      return;
    } else if (method == ScanMethod.rfid) {
      setState(() => _isSwitching = false);
      _navigateToExternalScanner('/rfid');
      return;
    }

    final previousMethod = _selectedMethod;
    
    // Atualiza o método selecionado
    setState(() {
      _selectedMethod = method;
    });

    try {
      // TRANSIÇÃO: AR -> QR/Barcode
      if ((previousMethod == ScanMethod.ar) && 
          (method == ScanMethod.qrcode || method == ScanMethod.barcode)) {
        print('🔄 Transição: AR -> ${method.name}');
        
        // 1. PRIMEIRO: Libertar CameraController completamente
        await _disposeCameraController();
        
        // 2. Pausa para libertar recursos do hardware (aumentado para TC22)
        print('⏳ A aguardar libertação do hardware...');
        await Future.delayed(const Duration(milliseconds: 500));
        
        // 3. DEPOIS: Inicializar MobileScanner
        await _initializeMobileScanner();
      }
      // TRANSIÇÃO: QR/Barcode -> AR
      else if ((previousMethod == ScanMethod.qrcode || previousMethod == ScanMethod.barcode) && 
               method == ScanMethod.ar) {
        print('🔄 Transição: ${previousMethod.name} -> AR');
        
        // 1. PRIMEIRO: Libertar MobileScannerController
        await _disposeMobileScannerController();
        
        // 2. Pausa para libertar recursos (aumentado para TC22)
        print('⏳ A aguardar libertação do hardware...');
        await Future.delayed(const Duration(milliseconds: 500));
        
        // 3. DEPOIS: Inicializar CameraController
        await _initializeCamera();
      }
      // TRANSIÇÃO: QR <-> Barcode (mesmo tipo de scanner, só muda overlay)
      else if ((previousMethod == ScanMethod.qrcode && method == ScanMethod.barcode) ||
               (previousMethod == ScanMethod.barcode && method == ScanMethod.qrcode)) {
        print('🔄 Transição: ${previousMethod.name} -> ${method.name} (mesmo scanner)');
        // Não precisa reinicializar - ambos usam MobileScanner
        // Apenas atualiza a UI (overlay diferente)
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSwitching = false;
        });
      }
    }
  }

  /// Navega para scanner externo (NFC/RFID) LIBERTANDO a câmara
  Future<void> _navigateToExternalScanner(String route) async {
    await _disposeAllCameras();
    
    if (!mounted) return;
    
    await Navigator.pushNamed(context, route);
    
    if (mounted && !_isDisposed) {
      setState(() => _selectedMethod = ScanMethod.ar);
      await _initializeCamera();
    }
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
              });
              // Reinicia o scanner após voltar
              _mobileScannerController?.start();
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

  void _handleBottomNavigation(int index) async {
    if (index == _selectedBottomIndex) return;

    setState(() {
      _selectedBottomIndex = index;
    });

    if (index == 0) {
      await _disposeAllCameras();
      
      if (!mounted) return;
      
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const ArmazemScreen(),
        ),
      );
      
      if (mounted && !_isDisposed) {
        setState(() {
          _selectedBottomIndex = 1;
        });
        await _reinitializeCurrentScanner();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cameraSize = screenSize.width * 0.85;
    
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
                      if (_isSwitching)
                        // Mostrar loading durante transição
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'A mudar scanner...',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_selectedMethod == ScanMethod.qrcode || 
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
                              const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'A inicializar câmara...',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Overlays para QR/Barcode
                      if (!_isSwitching && _selectedMethod == ScanMethod.qrcode)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: QROverlayPainter(),
                          ),
                        ),

                      if (!_isSwitching && _selectedMethod == ScanMethod.barcode)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: BarcodeOverlayPainter(),
                          ),
                        ),

                      // Indicador de pesquisa
                      if (_isSearching)
                        Container(
                          color: Colors.black.withOpacity(0.7),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'A procurar artigo...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
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

            // Barra de métodos de scan
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
    // Verifica se o controller existe, se não, mostra loading
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