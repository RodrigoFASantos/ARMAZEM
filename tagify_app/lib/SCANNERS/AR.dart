import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../SERVICE/API.dart';
import '../models/models.dart';
import '../helpers/artigo_navigation_helper.dart';

/// Scanner AR - Versão Simplificada
/// 
/// Esta implementação usa câmara + manual input
/// Para AR completo com reconhecimento de imagem seria necessário:
/// - Google ML Kit
/// - TensorFlow Lite
/// - Modelo treinado personalizado
class ARScannerScreen extends StatefulWidget {
  const ARScannerScreen({super.key});

  @override
  State<ARScannerScreen> createState() => _ARScannerScreenState();
}

class _ARScannerScreenState extends State<ARScannerScreen> 
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  final _apiService = ApiService();
  
  String? _lastPhotoPath;
  final TextEditingController _searchController = TextEditingController();

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
    _searchController.dispose();
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
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('❌ Nenhuma câmara disponível');
        return;
      }

      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
      
      print('✅ Câmara inicializada');
    } catch (e) {
      print('❌ Erro ao inicializar câmara: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao inicializar câmara: $e')),
        );
      }
    }
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || 
        !_cameraController!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final image = await _cameraController!.takePicture();
      
      setState(() {
        _lastPhotoPath = image.path;
      });

      print('📸 Foto capturada: ${image.path}');
      
      // Mostrar diálogo para identificar artigo
      if (mounted) {
        _showIdentificationDialog();
      }
    } catch (e) {
      print('❌ Erro ao tirar foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao tirar foto: $e')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showIdentificationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Identificar Artigo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mostrar foto capturada
              if (_lastPhotoPath != null)
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_lastPhotoPath!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Digite o código do artigo:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Código/Referência',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                ),
                autofocus: true,
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    Navigator.of(context).pop();
                    _searchArticle(value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _searchController.clear();
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_searchController.text.isNotEmpty) {
                  Navigator.of(context).pop();
                  _searchArticle(_searchController.text);
                }
              },
              child: const Text('Buscar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _searchArticle(String code) async {
    setState(() => _isProcessing = true);

    try {
      print('🔍 Procurando artigo: $code');
      
      final artigo = await _apiService.getArtigoByCodigo(code);

      if (artigo != null && mounted) {
        // ✨ USAR NAVEGAÇÃO INTELIGENTE
        await ArtigoNavigationHelper.navigateToArtigoDetail(context, artigo);
        
        // Voltar para home após ver detalhes
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Artigo não encontrado: $code'),
            backgroundColor: Colors.red,
          ),
        );
        _searchController.clear();
      }
    } catch (e) {
      print('❌ Erro ao buscar artigo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao buscar artigo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scanner AR'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Scanner AR'),
                  content: const Text(
                    'Versão Simplificada:\n\n'
                    '1. Tire foto do artigo\n'
                    '2. Digite o código manualmente\n'
                    '3. Sistema busca o artigo\n\n'
                    'Para AR completo com reconhecimento '
                    'automático seria necessário ML Kit + '
                    'modelo treinado.'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Preview da câmara
          if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Inicializando câmara...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),

          // Overlay com mira AR
          if (_isCameraInitialized)
            Positioned.fill(
              child: CustomPaint(
                painter: AROverlayPainter(),
              ),
            ),

          // Instruções no topo
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.view_in_ar, color: Colors.orange, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Aponte para o artigo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.orange),
                    SizedBox(height: 16),
                    Text(
                      'Processando...',
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

          // Botão de captura (câmara)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _isProcessing ? null : _takePicture,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.orange, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: _isProcessing ? Colors.grey : Colors.orange,
                    size: 40,
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

/// Painter para overlay AR com mira central
class AROverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Área escurecida ao redor da mira
    const padding = 80.0;
    final targetSize = size.width - (padding * 2);
    final targetRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: targetSize,
      height: targetSize,
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRect(targetRect),
      ),
      paint,
    );

    // Mira AR com cantos
    final borderPaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    const cornerLength = 40.0;
    final left = targetRect.left;
    final right = targetRect.right;
    final top = targetRect.top;
    final bottom = targetRect.bottom;

    // Cantos superiores
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left, top + cornerLength),
      borderPaint,
    );

    canvas.drawLine(
      Offset(right, top),
      Offset(right - cornerLength, top),
      borderPaint,
    );
    canvas.drawLine(
      Offset(right, top),
      Offset(right, top + cornerLength),
      borderPaint,
    );

    // Cantos inferiores
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left + cornerLength, bottom),
      borderPaint,
    );
    canvas.drawLine(
      Offset(left, bottom),
      Offset(left, bottom - cornerLength),
      borderPaint,
    );

    canvas.drawLine(
      Offset(right, bottom),
      Offset(right - cornerLength, bottom),
      borderPaint,
    );
    canvas.drawLine(
      Offset(right, bottom),
      Offset(right, bottom - cornerLength),
      borderPaint,
    );

    // Cruz central
    final centerPaint = Paint()
      ..color = Colors.orange.withOpacity(0.5)
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(size.width / 2 - 20, size.height / 2),
      Offset(size.width / 2 + 20, size.height / 2),
      centerPaint,
    );
    canvas.drawLine(
      Offset(size.width / 2, size.height / 2 - 20),
      Offset(size.width / 2, size.height / 2 + 20),
      centerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}