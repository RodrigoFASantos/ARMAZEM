import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../SCANNERS/NFC.dart';
import '../SCANNERS/RFID.dart';
import '../SCANNERS/AR.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isDisposed = false;
  ScanMode _currentMode = ScanMode.ar;

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
    _disposeCamera();
    super.dispose();
  }

  /// Observa mudanças de ciclo de vida da app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (_isDisposed) return;
    
    try {
      // Guarda lista de câmaras para reutilizar
      _cameras ??= await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        print('Nenhuma câmara disponível');
        return;
      }

      // Cria novo controller
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
      
      print(' Câmara inicializada');
    } catch (e) {
      print(' Erro ao inicializar câmara: $e');
    }
  }

  Future<void> _disposeCamera() async {
    if (_cameraController == null) return;
    
    final controller = _cameraController;
    _cameraController = null;
    
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
      });
    }
    
    try {
      await controller?.dispose();
      print(' Câmara libertada');
    } catch (e) {
      print('Erro ao libertar câmara: $e');
    }
  }

  /// Navega para ecrã externo LIBERTANDO a câmara completamente
  Future<void> _navigateToScreen(Widget screen) async {
    // IMPORTANTE: Libertar câmara ANTES de navegar (não apenas pausar!)
    await _disposeCamera();
    
    if (!mounted) return;
    
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    
    // Reinicializa câmara quando volta
    if (mounted && !_isDisposed) {
      await _initializeCamera();
    }
  }

  void _onScanModeChanged(ScanMode mode) {
    //  AGORA AR TAMBÉM NAVEGA PARA ECRÃ DEDICADO!
    if (mode == ScanMode.ar) {
      _navigateToScreen(const ARScannerScreen());
      return;
    }
    
    if (mode == ScanMode.rfid) {
      _navigateToScreen(const RFIDScannerScreen());
      return;
    }
    
    if (mode == ScanMode.nfc) {
      _navigateToScreen(const NFCScannerScreen());
      return;
    }
    
    setState(() => _currentMode = mode);
    print('Modo alterado para: ${mode.name}');
  }

  void _takePicture() async {
    if (_cameraController == null || 
        !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final image = await _cameraController!.takePicture();
      print('Foto guardada: ${image.path}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotografia guardada!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Erro ao tirar foto: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Câmara Preview
          if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Overlay escuro com recorte central
          Positioned.fill(
            child: CustomPaint(
              painter: ScannerOverlayPainter(),
            ),
          ),

          // Moldura em L nos cantos
          Positioned.fill(
            child: CustomPaint(
              painter: CornerFramePainter(),
            ),
          ),

          // Status do modo atual
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getModeLabel(_currentMode),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          // Barra de ferramentas inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                top: 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Modos de scan
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildModeButton(
                        icon: Icons.contactless,
                        label: 'RFID',
                        mode: ScanMode.rfid,
                        isActive: _currentMode == ScanMode.rfid,
                        color: const Color(0xFFE63946),
                      ),
                      _buildModeButton(
                        icon: Icons.nfc,
                        label: 'NFC',
                        mode: ScanMode.nfc,
                        isActive: _currentMode == ScanMode.nfc,
                        color: const Color(0xFFFF6B35),
                      ),
                      _buildModeButton(
                        icon: Icons.view_in_ar,
                        label: 'AR',
                        mode: ScanMode.ar,
                        isActive: _currentMode == ScanMode.ar,
                      ),
                      _buildModeButton(
                        icon: Icons.qr_code_scanner,
                        label: 'QR',
                        mode: ScanMode.qr,
                        isActive: _currentMode == ScanMode.qr,
                      ),
                      _buildModeButton(
                        icon: Icons.barcode_reader,
                        label: 'Código',
                        mode: ScanMode.barcode,
                        isActive: _currentMode == ScanMode.barcode,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Botões principais (Home e Câmara)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Botão Home
                      _buildMainButton(
                        icon: Icons.home,
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      
                      const SizedBox(width: 40),
                      
                      // Botão Câmara
                      _buildMainButton(
                        icon: Icons.camera_alt,
                        onPressed: _takePicture,
                        isPrimary: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getModeLabel(ScanMode mode) {
    switch (mode) {
      case ScanMode.rfid:
        return 'RFID Scanner';
      case ScanMode.nfc:
        return 'NFC Scanner';
      case ScanMode.ar:
        return 'Realidade Aumentada';
      case ScanMode.qr:
        return 'QR Code Scanner';
      case ScanMode.barcode:
        return 'Código de Barras';
    }
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required ScanMode mode,
    required bool isActive,
    Color? color,
  }) {
    final activeColor = color ?? Colors.blue;
    
    return GestureDetector(
      onTap: () => _onScanModeChanged(mode),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? activeColor : Colors.white.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white70,
              size: 28,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontSize: 9,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: isPrimary ? Colors.white : Colors.white.withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
        ),
        child: Icon(
          icon,
          color: isPrimary ? Colors.black : Colors.white,
          size: 36,
        ),
      ),
    );
  }
}

// Modos de identificação
enum ScanMode {
  rfid,
  nfc,
  ar,
  qr,
  barcode,
}

// Painter para a moldura em L nos cantos
class CornerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    const cornerLength = 40.0;
    const padding = 60.0;

    // Canto superior esquerdo
    canvas.drawLine(
      const Offset(padding, padding),
      const Offset(padding + cornerLength, padding),
      paint,
    );
    canvas.drawLine(
      const Offset(padding, padding),
      const Offset(padding, padding + cornerLength),
      paint,
    );

    // Canto superior direito
    canvas.drawLine(
      Offset(size.width - padding, padding),
      Offset(size.width - padding - cornerLength, padding),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - padding, padding),
      Offset(size.width - padding, padding + cornerLength),
      paint,
    );

    // Canto inferior esquerdo
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(padding + cornerLength, size.height - padding),
      paint,
    );
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(padding, size.height - padding - cornerLength),
      paint,
    );

    // Canto inferior direito
    canvas.drawLine(
      Offset(size.width - padding, size.height - padding),
      Offset(size.width - padding - cornerLength, size.height - padding),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - padding, size.height - padding),
      Offset(size.width - padding, size.height - padding - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Painter para overlay escuro com área central transparente
class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.5);

    const padding = 60.0;
    final scanArea = Rect.fromLTRB(
      padding,
      padding,
      size.width - padding,
      size.height - padding - 200, // Espaço para botões
    );

    // Desenha overlay escuro exceto na área de scan
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRect(scanArea),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}