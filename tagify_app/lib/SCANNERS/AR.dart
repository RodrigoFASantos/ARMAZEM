import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:math';
import '../SERVICE/API.dart';
import '../models/models.dart';
import '../helpers/artigo_navigation_helper.dart';

///  AR Scanner com Reconhecimento REAL usando ML Kit
/// Otimizado para Zebra TC22
class ARScannerScreen extends StatefulWidget {
  const ARScannerScreen({super.key});

  @override
  State<ARScannerScreen> createState() => _ARScannerScreenState();
}

class _ARScannerScreenState extends State<ARScannerScreen> 
    with WidgetsBindingObserver {
  
  // Câmara
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  
  // ML Kit
  ObjectDetector? _objectDetector;
  bool _isProcessing = false;
  
  // Dados
  final _apiService = ApiService();
  List<Artigo> _artigosCache = [];
  
  // UI State
  String _statusMessage = 'Inicializando...';
  DetectedObject? _lastDetection;
  Artigo? _lastMatchedArtigo;
  double _matchConfidence = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAR();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _objectDetector?.close();
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

  /// 🚀 Inicializar sistema AR completo
  Future<void> _initializeAR() async {
    setState(() => _statusMessage = 'Carregando artigos...');
    
    // 1. Carregar artigos
    await _loadArtigos();
    
    // 2. Inicializar ML Kit
    setState(() => _statusMessage = 'Inicializando ML Kit...');
    await _initializeMLKit();
    
    // 3. Inicializar câmara
    setState(() => _statusMessage = 'Inicializando câmara...');
    await _initializeCamera();
    
    setState(() => _statusMessage = 'Pronto! Aponte para um artigo');
  }

  /// 📦 Carregar artigos
  Future<void> _loadArtigos() async {
    try {
      _artigosCache = await _apiService.getAllArtigos();
      print('✅ ${_artigosCache.length} artigos carregados');
    } catch (e) {
      print('⚠️ Erro ao carregar artigos: $e');
    }
  }

  /// 🧠 Inicializar ML Kit
  Future<void> _initializeMLKit() async {
    try {
      final options = ObjectDetectorOptions(
        mode: DetectionMode.single,
        classifyObjects: true,
        multipleObjects: false,
      );
      
      _objectDetector = ObjectDetector(options: options);
      print('✅ ML Kit inicializado');
    } catch (e) {
      print('❌ Erro ao inicializar ML Kit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ML Kit não disponível: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 📷 Inicializar câmara
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _statusMessage = 'Nenhuma câmara disponível');
        return;
      }

      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.medium, // Medium para melhor performance no TC22
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
      
      print('✅ Câmara AR inicializada');
    } catch (e) {
      print('❌ Erro câmara: $e');
      setState(() => _statusMessage = 'Erro câmara: $e');
    }
  }

  /// 📸 Capturar e processar com ML Kit
  Future<void> _captureAndProcess() async {
    if (_cameraController == null || 
        !_cameraController!.value.isInitialized ||
        _isProcessing ||
        _objectDetector == null) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Capturando...';
    });

    try {
      // 1. Capturar foto
      final image = await _cameraController!.takePicture();
      print('📸 Foto: ${image.path}');
      
      setState(() => _statusMessage = 'Analisando...');

      // 2. ML Kit - Detectar objetos
      final inputImage = InputImage.fromFilePath(image.path);
      final detectedObjects = await _objectDetector!.processImage(inputImage);
      
      if (detectedObjects.isEmpty) {
        setState(() => _statusMessage = 'Nenhum objeto detectado');
        await Future.delayed(const Duration(seconds: 2));
        setState(() => _statusMessage = 'Pronto! Aponte para um artigo');
        return;
      }

      final mainObject = detectedObjects.first;
      print(' Detectado: ${mainObject.labels.map((l) => l.text).join(", ")}');
      
      setState(() {
        _lastDetection = mainObject;
        _statusMessage = 'Objeto detectado! Procurando match...';
      });

      // 3. Extrair características visuais
      final imageFile = File(image.path);
      final imageBytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(imageBytes);
      
      if (decodedImage == null) {
        throw Exception('Erro ao processar imagem');
      }

      final visualFeatures = _extractVisualFeatures(decodedImage);
      print('🎨 Features: ${visualFeatures.toString()}');

      // 4. Encontrar melhor match
      final match = await _findBestMatch(mainObject, visualFeatures);
      
      if (match != null && mounted) {
        setState(() {
          _lastMatchedArtigo = match['artigo'];
          _matchConfidence = match['confidence'];
          _statusMessage = 'Match: ${_lastMatchedArtigo?.designacao}';
        });
        
        await _showMatchResult();
        
      } else {
        setState(() => _statusMessage = 'Sem match. Tente outro ângulo');
        await Future.delayed(const Duration(seconds: 2));
        setState(() => _statusMessage = 'Pronto! Aponte para um artigo');
      }

    } catch (e) {
      print('❌ Erro: $e');
      setState(() => _statusMessage = 'Erro: $e');
      await Future.delayed(const Duration(seconds: 2));
      setState(() => _statusMessage = 'Pronto! Aponte para um artigo');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// 🎨 Extrair características visuais
  Map<String, dynamic> _extractVisualFeatures(img.Image image) {
    final resized = img.copyResize(image, width: 100);
    
    Map<String, int> colorCounts = {};
    int totalPixels = 0;
    
    for (int y = 0; y < resized.height; y++) {
      for (int x = 0; x < resized.width; x++) {
        final pixel = resized.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        
        String colorCategory;
        if (r > 200 && g > 200 && b > 200) {
          colorCategory = 'branco';
        } else if (r < 50 && g < 50 && b < 50) {
          colorCategory = 'preto';
        } else if (r > max(g, b) * 1.2) {
          colorCategory = 'vermelho';
        } else if (g > max(r, b) * 1.2) {
          colorCategory = 'verde';
        } else if (b > max(r, g) * 1.2) {
          colorCategory = 'azul';
        } else if (r > 150 && g > 150 && b < 100) {
          colorCategory = 'amarelo';
        } else if (r > 150 && g < 100 && b < 100) {
          colorCategory = 'laranja';
        } else {
          colorCategory = 'outro';
        }
        
        colorCounts[colorCategory] = (colorCounts[colorCategory] ?? 0) + 1;
        totalPixels++;
      }
    }
    
    String dominantColor = 'outro';
    int maxCount = 0;
    colorCounts.forEach((color, count) {
      if (count > maxCount) {
        maxCount = count;
        dominantColor = color;
      }
    });
    
    double brightness = 0;
    for (int y = 0; y < resized.height; y++) {
      for (int x = 0; x < resized.width; x++) {
        final pixel = resized.getPixel(x, y);
        brightness += (pixel.r + pixel.g + pixel.b) / 3;
      }
    }
    brightness /= totalPixels;
    
    return {
      'dominantColor': dominantColor,
      'brightness': brightness,
      'aspectRatio': image.width / image.height,
    };
  }

  /// 🔍 Encontrar melhor match
  Future<Map<String, dynamic>?> _findBestMatch(
    DetectedObject detection,
    Map<String, dynamic> visualFeatures,
  ) async {
    if (_artigosCache.isEmpty) return null;

    List<Map<String, dynamic>> candidates = [];

    for (var artigo in _artigosCache) {
      double confidence = 0.0;
      
      // 1. Score baseado em labels ML Kit
      for (var label in detection.labels) {
        final labelText = label.text.toLowerCase();
        final artigoName = artigo.designacao.toLowerCase();
        
        // Match direto no nome
        if (artigoName.contains(labelText) || labelText.contains(artigoName)) {
          confidence += label.confidence * 40;
        }
        
        // Match por tipo
        if (artigo.tipo?.designacao != null) {
          final tipoName = artigo.tipo!.designacao.toLowerCase();
          if (tipoName.contains(labelText) || labelText.contains(tipoName)) {
            confidence += label.confidence * 20;
          }
        }
        
        // Match por referência
        if (artigo.referencia != null) {
          final refLower = artigo.referencia!.toLowerCase();
          if (refLower.contains(labelText)) {
            confidence += label.confidence * 15;
          }
        }
      }
      
      // 2. Bonus por tipo de artigo
      if (artigo.tipo?.designacao != null) {
        final tipo = artigo.tipo!.designacao.toLowerCase();
        
        if (tipo.contains('equipamento')) {
          if (['preto', 'branco', 'outro'].contains(visualFeatures['dominantColor'])) {
            confidence += 10;
          }
        }
        
        if (tipo.contains('materia') || tipo.contains('prima')) {
          if (!['preto', 'branco'].contains(visualFeatures['dominantColor'])) {
            confidence += 10;
          }
        }
      }
      
      // 3. Bonus por bounding box
      final boxArea = detection.boundingBox.width * detection.boundingBox.height;
      confidence += min(boxArea / 10000, 10);
      
      if (confidence > 25) {
        candidates.add({
          'artigo': artigo,
          'confidence': confidence / 100,
        });
      }
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => 
      (b['confidence'] as double).compareTo(a['confidence'] as double)
    );

    return candidates.first;
  }

  /// 📊 Mostrar resultado
  Future<void> _showMatchResult() async {
    if (_lastMatchedArtigo == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _matchConfidence > 0.6 
                ? Icons.check_circle 
                : Icons.help_outline,
              color: _matchConfidence > 0.6 
                ? Colors.green 
                : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Flexible(child: Text('Artigo Detectado')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _lastMatchedArtigo!.designacao,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_lastMatchedArtigo!.tipo != null)
              Text('Tipo: ${_lastMatchedArtigo!.tipo!.designacao}'),
            if (_lastMatchedArtigo!.referencia != null)
              Text('Ref: ${_lastMatchedArtigo!.referencia}'),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _matchConfidence,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _matchConfidence > 0.6 ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Confiança: ${(_matchConfidence * 100).toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Não é este'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ArtigoNavigationHelper.navigateToArtigoDetail(
        context, 
        _lastMatchedArtigo!,
      );
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } else {
      setState(() {
        _lastMatchedArtigo = null;
        _matchConfidence = 0.0;
        _statusMessage = 'Pronto! Aponte para um artigo';
      });
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
          if (_artigosCache.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '📦 ${_artigosCache.length}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Preview câmara
          if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

          // Overlay AR
          if (_isCameraInitialized)
            Positioned.fill(
              child: CustomPaint(
                painter: AROverlayPainter(
                  detection: _lastDetection,
                  imageSize: _cameraController?.value.previewSize,
                ),
              ),
            ),

          // Status bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.orange, width: 2),
              ),
              child: Row(
                children: [
                  Icon(
                    _isProcessing ? Icons.hourglass_bottom : Icons.view_in_ar,
                    color: Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.orange),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // Botão captura
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _isProcessing ? null : _captureAndProcess,
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

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(' Scanner AR'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              /*Text('Tecnologias:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• Google ML Kit (detecção objetos)'),
              Text('• Análise características visuais'),
              Text('• Matching inteligente com BD'),
              SizedBox(height: 16),*/
              Text('Como usar:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('1. Aponte câmara para artigo'),
              Text('2. Boa iluminação ajuda'),
              Text('3. Toque botão captura'),
              Text('4. Aguarde reconhecimento'),
              Text('5. Confirme se correto'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Painter para overlay AR
class AROverlayPainter extends CustomPainter {
  final DetectedObject? detection;
  final Size? imageSize;

  AROverlayPainter({this.detection, this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    _drawTargetReticle(canvas, size);
    
    if (detection != null && imageSize != null) {
      _drawDetectionBox(canvas, size);
    }
  }

  void _drawTargetReticle(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.fill;

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

    final borderPaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    const cornerLength = 40.0;
    final left = targetRect.left;
    final right = targetRect.right;
    final top = targetRect.top;
    final bottom = targetRect.bottom;

    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), borderPaint);
    canvas.drawLine(Offset(left, top), Offset(left, top + cornerLength), borderPaint);
    canvas.drawLine(Offset(right, top), Offset(right - cornerLength, top), borderPaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLength), borderPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLength, bottom), borderPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left, bottom - cornerLength), borderPaint);
    canvas.drawLine(Offset(right, bottom), Offset(right - cornerLength, bottom), borderPaint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cornerLength), borderPaint);

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

  void _drawDetectionBox(Canvas canvas, Size size) {
    final box = detection!.boundingBox;
    final scaleX = size.width / imageSize!.width;
    final scaleY = size.height / imageSize!.height;
    
    final rect = Rect.fromLTWH(
      box.left * scaleX,
      box.top * scaleY,
      box.width * scaleX,
      box.height * scaleY,
    );

    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawRect(rect, paint);

    if (detection!.labels.isNotEmpty) {
      final label = detection!.labels.first;
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${label.text} (${(label.confidence * 100).toInt()}%)',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.green,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(canvas, Offset(rect.left, rect.top - 25));
    }
  }

  @override
  bool shouldRepaint(covariant AROverlayPainter oldDelegate) {
    return detection != oldDelegate.detection;
  }
}