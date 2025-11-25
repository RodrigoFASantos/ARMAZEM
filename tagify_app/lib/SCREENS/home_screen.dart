import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'armazem_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  ScanMode _currentMode = ScanMode.ar; // AR ativo por defeito

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('Nenhuma câmara disponível');
        return;
      }

      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      print('Erro ao inicializar câmara: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _onScanModeChanged(ScanMode mode) {
    setState(() => _currentMode = mode);
    print('Modo alterado para: ${mode.name}');
  }

  void _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Erro ao tirar foto: $e');
    }
  }

  void _goToArmazem() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ArmazemScreen(),
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sair'),
          content: const Text('Deseja terminar sessão?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              },
              child: const Text('Sair', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Câmara Preview (sempre ativa)
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

          // Moldura em L nos cantos (área de foco)
          Positioned.fill(
            child: CustomPaint(
              painter: CornerFramePainter(),
            ),
          ),

          // Contornos AR (simulados - em azul)
          if (_currentMode == ScanMode.ar)
            Positioned.fill(
              child: CustomPaint(
                painter: ARContoursPainter(),
              ),
            ),

          // Status do modo atual (topo central)
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
                  _getModeText(_currentMode),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // Botão de logout (canto superior direito)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white, size: 28),
              onPressed: _logout,
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
                  // Modos de identificação
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildModeButton(
                        icon: Icons.contactless,
                        label: 'RFID',
                        mode: ScanMode.rfid,
                        isActive: _currentMode == ScanMode.rfid,
                      ),
                      _buildModeButton(
                        icon: Icons.nfc,
                        label: 'NFC',
                        mode: ScanMode.nfc,
                        isActive: _currentMode == ScanMode.nfc,
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
                  
                  // Botões principais: Armazém (esquerda) e Câmara (direita)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Botão Armazém (esquerda)
                      _buildMainButton(
                        icon: Icons.warehouse,
                        onPressed: _goToArmazem,
                      ),
                      
                      const SizedBox(width: 40),
                      
                      // Botão Câmara/Home (direita) - principal
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

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required ScanMode mode,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () => _onScanModeChanged(mode),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Colors.blue : Colors.white.withOpacity(0.5),
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

  String _getModeText(ScanMode mode) {
    switch (mode) {
      case ScanMode.rfid:
        return 'RFID - Aproxime a etiqueta';
      case ScanMode.nfc:
        return 'NFC - Aproxime o equipamento';
      case ScanMode.ar:
        return 'AR - Aponte para o equipamento';
      case ScanMode.qr:
        return 'QR Code - Aponte para o código';
      case ScanMode.barcode:
        return 'Código de Barras - Aponte para o código';
    }
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

// Painter para contornos AR (simulados em azul)
class ARContoursPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Simula contornos de deteção AR
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    // Retângulos de deteção
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX, centerY - 50),
        width: 120,
        height: 80,
      ),
      paint,
    );
    
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX, centerY + 40),
        width: 100,
        height: 60,
      ),
      paint,
    );
    
    // Linhas de conexão
    canvas.drawLine(
      Offset(centerX, centerY - 10),
      Offset(centerX, centerY + 10),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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