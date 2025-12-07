import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../SERVICE/API.dart';
import '../models/models.dart';
import '../helpers/artigo_navigation_helper.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: [BarcodeFormat.qrCode],
  );
  
  final _apiService = ApiService();
  bool _isSearching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Verifica se o formato é QR Code
  bool _isValidQRFormat(BarcodeFormat? format) {
    if (format == null) return false;
    
    // ACEITAR apenas QR Code
    if (format == BarcodeFormat.qrCode) {
      return true;
    }
    
    print('⚠️ Formato rejeitado: $format (não é QR Code)');
    return false;
  }

  void _onQRDetected(BarcodeCapture capture) async {
    if (_isSearching) return;

    final List<Barcode> barcodes = capture.barcodes;
    
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      final BarcodeFormat? format = barcode.format;
      
      // VERIFICAÇÃO EXTRA: Ignorar se não for QR Code
      if (!_isValidQRFormat(format)) {
        print('🚫 Ignorado: $code (formato: $format)');
        continue; // Ignora e continua a procurar
      }
      
      if (code != null && code.isNotEmpty) {
        setState(() => _isSearching = true);
        _controller.stop();

        print('📱 QR Code detectado: $code (formato: $format)');

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
        title: const Text('Scanner de QR Code'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onQRDetected,
          ),

          CustomPaint(
            painter: QROverlayPainter(),
            child: Container(),
          ),

          CustomPaint(
            painter: QRCornersPainter(),
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
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Text(
                    '📱 Aponte para o QR Code',
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class QRCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    const padding = 60.0;
    const cornerLength = 40.0;
    final scanSize = size.width - (padding * 2);
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    final left = centerX - (scanSize / 2);
    final right = centerX + (scanSize / 2);
    final top = centerY - (scanSize / 2);
    final bottom = centerY + (scanSize / 2);

    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left, top + cornerLength), paint);

    canvas.drawLine(Offset(right, top), Offset(right - cornerLength, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLength), paint);

    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLength, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left, bottom - cornerLength), paint);

    canvas.drawLine(Offset(right, bottom), Offset(right - cornerLength, bottom), paint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}