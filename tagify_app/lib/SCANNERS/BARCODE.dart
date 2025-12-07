import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../SERVICE/API.dart';
import '../models/models.dart';
import '../helpers/artigo_navigation_helper.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  // Formatos de códigos de barras lineares permitidos
  static const List<BarcodeFormat> _allowedFormats = [
    BarcodeFormat.code128,
    BarcodeFormat.code39,
    BarcodeFormat.code93,
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
    BarcodeFormat.itf,
    BarcodeFormat.codabar,
  ];

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: _allowedFormats,
  );
  
  final _apiService = ApiService();
  bool _isSearching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Verifica se o formato é um código de barras linear (NÃO é QR Code)
  bool _isValidBarcodeFormat(BarcodeFormat? format) {
    if (format == null) return false;
    
    // REJEITAR explicitamente QR Code e outros 2D
    if (format == BarcodeFormat.qrCode ||
        format == BarcodeFormat.aztec ||
        format == BarcodeFormat.dataMatrix ||
        format == BarcodeFormat.pdf417) {
      print('⚠️ Formato rejeitado: $format (não é código de barras linear)');
      return false;
    }
    
    // Verificar se está na lista de permitidos
    return _allowedFormats.contains(format);
  }

  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isSearching) return;

    final List<Barcode> barcodes = capture.barcodes;
    
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      final BarcodeFormat? format = barcode.format;
      
      // VERIFICAÇÃO EXTRA: Ignorar se não for código de barras linear
      if (!_isValidBarcodeFormat(format)) {
        print('🚫 Ignorado: $code (formato: $format)');
        continue; // Ignora e continua a procurar
      }
      
      if (code != null && code.isNotEmpty) {
        setState(() => _isSearching = true);
        _controller.stop();

        print('📦 Código de Barras detectado: $code (formato: $format)');

        try {
          final artigo = await _apiService.getArtigoByCodigo(code);

          if (artigo != null && mounted) {
            await ArtigoNavigationHelper.navigateToArtigoDetail(context, artigo);
            
            if (mounted) {
              Navigator.of(context).pop();
            }
          } else if (mounted) {
            _showErrorDialog('Artigo não encontrado', 'Código: $code');
            setState(() => _isSearching = false);
            _controller.start();
          }
        } catch (e) {
          print('❌ Erro ao buscar artigo: $e');
          if (mounted) {
            _showErrorDialog('Erro na busca', 'Não foi possível buscar o artigo.\n\n$e');
            setState(() => _isSearching = false);
            _controller.start();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scanner de Código de Barras'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetected,
          ),

          CustomPaint(
            painter: ScannerOverlayPainter(),
            child: Container(),
          ),

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

          if (!_isSearching)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Text(
                    '📦 Aponte para o código de barras',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
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
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(scanArea, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}