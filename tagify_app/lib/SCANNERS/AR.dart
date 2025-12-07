import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:math';
import '../SERVICE/API.dart';
import '../models/models.dart';
import '../helpers/artigo_navigation_helper.dart';

/// =============================================================================
/// SCANNER AR COM RECONHECIMENTO REAL USANDO ML KIT
/// =============================================================================
/// Este ecrã usa a câmara e o Google ML Kit pra reconhecer objetos.
/// Quando captura uma foto, analisa as características visuais e tenta
/// encontrar um match na base de dados de artigos.
/// Otimizado pra funcionar bem no Zebra TC22.
/// =============================================================================
class ARScannerScreen extends StatefulWidget {
  const ARScannerScreen({super.key});

  @override
  State<ARScannerScreen> createState() => _ARScannerScreenState();
}

class _ARScannerScreenState extends State<ARScannerScreen> 
    with WidgetsBindingObserver {
  
  // =========================================================================
  // VARIÁVEIS DE CÂMARA
  // =========================================================================
  
  /// Controlador da câmara
  CameraController? _cameraController;
  
  /// Flag pra saber se a câmara já está inicializada
  bool _isCameraInitialized = false;
  
  /// Tamanho real da imagem capturada (pra escalar a bounding box)
  Size? _capturedImageSize;
  
  // =========================================================================
  // VARIÁVEIS DO ML KIT
  // =========================================================================
  
  /// Detetor de objetos do Google ML Kit
  ObjectDetector? _objectDetector;
  
  /// Flag pra evitar processar várias imagens ao mesmo tempo
  bool _isProcessing = false;
  
  // =========================================================================
  // VARIÁVEIS DE DADOS
  // =========================================================================
  
  /// Serviço da API pra buscar artigos
  final _apiService = ApiService();
  
  /// Cache de artigos carregados da BD
  List<Artigo> _artigosCache = [];
  
  // =========================================================================
  // VARIÁVEIS DE UI
  // =========================================================================
  
  /// Mensagem de estado mostrada no topo do ecrã
  String _statusMessage = 'Inicializando...';
  
  /// Última deteção do ML Kit (pra desenhar a caixa)
  DetectedObject? _lastDetection;
  
  /// Último artigo que fez match com a deteção
  Artigo? _lastMatchedArtigo;
  
  /// Nível de confiança do match (0.0 a 1.0)
  double _matchConfidence = 0.0;

  @override
  void initState() {
    super.initState();
    // Regista o observer pra saber quando a app vai pro background
    WidgetsBinding.instance.addObserver(this);
    // Inicializa todo o sistema AR
    _initializeAR();
  }

  @override
  void dispose() {
    // Remove o observer e liberta recursos
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _objectDetector?.close();
    super.dispose();
  }

  /// =========================================================================
  /// LIFECYCLE - GERIR MUDANÇAS DE ESTADO DA APP
  /// =========================================================================
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

  /// =========================================================================
  /// INICIALIZAR SISTEMA AR COMPLETO
  /// =========================================================================
  Future<void> _initializeAR() async {
    setState(() => _statusMessage = 'Carregando artigos...');
    
    await _loadArtigos();
    
    setState(() => _statusMessage = 'Inicializando ML Kit...');
    await _initializeMLKit();
    
    setState(() => _statusMessage = 'Inicializando câmara...');
    await _initializeCamera();
    
    setState(() => _statusMessage = 'Pronto! Aponte para um artigo');
  }

  /// =========================================================================
  /// CARREGAR ARTIGOS DA BD
  /// =========================================================================
  Future<void> _loadArtigos() async {
    try {
      _artigosCache = await _apiService.getAllArtigos();
      print('✅ ${_artigosCache.length} artigos carregados');
    } catch (e) {
      print('⚠️ Erro ao carregar artigos: $e');
    }
  }

  /// =========================================================================
  /// INICIALIZAR GOOGLE ML KIT
  /// =========================================================================
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
      print(' Erro ao inicializar ML Kit: $e');
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

  /// =========================================================================
  /// INICIALIZAR CÂMARA
  /// =========================================================================
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _statusMessage = 'Nenhuma câmara disponível');
        return;
      }

      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
      
      print('✅ Câmara AR inicializada');
    } catch (e) {
      print(' Erro câmara: $e');
      setState(() => _statusMessage = 'Erro câmara: $e');
    }
  }

  /// =========================================================================
  /// CAPTURAR E PROCESSAR IMAGEM
  /// =========================================================================
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
      _lastDetection = null; // Limpa deteção anterior
      _capturedImageSize = null;
    });

    try {
      // 1. Capturar foto
      final image = await _cameraController!.takePicture();
      print('📸 Foto: ${image.path}');
      
      setState(() => _statusMessage = 'Analisando...');

      // 2. Ler o tamanho real da imagem capturada
      final imageFile = File(image.path);
      final imageBytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(imageBytes);
      
      if (decodedImage == null) {
        throw Exception('Erro ao processar imagem');
      }
      
      // Guarda o tamanho real da imagem capturada
      _capturedImageSize = Size(
        decodedImage.width.toDouble(), 
        decodedImage.height.toDouble(),
      );
      print('📐 Tamanho imagem: ${_capturedImageSize!.width}x${_capturedImageSize!.height}');

      // 3. ML Kit - Detetar objetos na imagem
      final inputImage = InputImage.fromFilePath(image.path);
      final detectedObjects = await _objectDetector!.processImage(inputImage);
      
      if (detectedObjects.isEmpty) {
        setState(() => _statusMessage = 'Nenhum objeto detectado');
        await Future.delayed(const Duration(seconds: 2));
        setState(() => _statusMessage = 'Pronto! Aponte para um artigo');
        return;
      }

      // Pega o primeiro objeto detetado
      final mainObject = detectedObjects.first;
      print('🔍 Detectado: ${mainObject.labels.map((l) => l.text).join(", ")}');
      print('📦 BoundingBox: ${mainObject.boundingBox}');
      
      setState(() {
        _lastDetection = mainObject;
        _statusMessage = 'Objeto detectado! Procurando match...';
      });

      // 4. Extrair características visuais
      final visualFeatures = _extractVisualFeatures(decodedImage);
      print('🎨 Features: ${visualFeatures.toString()}');

      // 5. Encontrar melhor match na base de dados
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
        setState(() {
          _lastDetection = null;
          _statusMessage = 'Pronto! Aponte para um artigo';
        });
      }

    } catch (e) {
      print(' Erro: $e');
      setState(() => _statusMessage = 'Erro: $e');
      await Future.delayed(const Duration(seconds: 2));
      setState(() => _statusMessage = 'Pronto! Aponte para um artigo');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// =========================================================================
  /// EXTRAIR CARACTERÍSTICAS VISUAIS
  /// =========================================================================
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

  /// =========================================================================
  /// ENCONTRAR MELHOR MATCH NA BASE DE DADOS
  /// =========================================================================
  Future<Map<String, dynamic>?> _findBestMatch(
    DetectedObject detection,
    Map<String, dynamic> visualFeatures,
  ) async {
    if (_artigosCache.isEmpty) return null;

    List<Map<String, dynamic>> candidates = [];

    for (var artigo in _artigosCache) {
      double confidence = 0.0;
      
      for (var label in detection.labels) {
        final labelText = label.text.toLowerCase();
        final artigoName = artigo.designacao.toLowerCase();
        
        if (artigoName.contains(labelText) || labelText.contains(artigoName)) {
          confidence += label.confidence * 40;
        }
        
        if (artigo.tipo?.designacao != null) {
          final tipoName = artigo.tipo!.designacao.toLowerCase();
          if (tipoName.contains(labelText) || labelText.contains(tipoName)) {
            confidence += label.confidence * 20;
          }
        }
        
        if (artigo.referencia != null) {
          final refLower = artigo.referencia!.toLowerCase();
          if (refLower.contains(labelText)) {
            confidence += label.confidence * 15;
          }
        }
      }
      
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

  /// =========================================================================
  /// MOSTRAR RESULTADO DO MATCH
  /// =========================================================================
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
        _lastDetection = null;
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
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(),
          ),
        ],
      ),
      
      body: Stack(
        children: [
          // =========================================================
          // PREVIEW DA CÂMARA (ECRÃ INTEIRO)
          // =========================================================
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

          // =========================================================
          // OVERLAY AR - SÓ A CAIXA DE DETEÇÃO (SEM RETÍCULO)
          // =========================================================
          if (_isCameraInitialized && _lastDetection != null && _capturedImageSize != null)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    painter: ARDetectionPainter(
                      detection: _lastDetection!,
                      imageSize: _capturedImageSize!,
                      screenSize: Size(constraints.maxWidth, constraints.maxHeight),
                    ),
                  );
                },
              ),
            ),

          // =========================================================
          // BARRA DE ESTADO NO TOPO
          // =========================================================
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

          // =========================================================
          // OVERLAY DE LOADING
          // =========================================================
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

          // =========================================================
          // BOTÃO DE CAPTURA
          // =========================================================
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

  /// =========================================================================
  /// MOSTRAR DIÁLOGO DE INFORMAÇÃO
  /// =========================================================================
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scanner AR'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
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

/// =============================================================================
/// PAINTER PARA A CAIXA DE DETEÇÃO
/// =============================================================================
/// Desenha APENAS a caixa verde à volta do objeto detetado.
/// Sem retículo, sem quadrado do meio - ecrã limpo!
/// 
/// A conversão de coordenadas é feita corretamente considerando:
/// - A imagem capturada normalmente está em modo landscape (sensor rotacionado)
/// - O ecrã está em modo portrait
/// - Precisamos rodar e escalar as coordenadas corretamente
/// =============================================================================
class ARDetectionPainter extends CustomPainter {
  final DetectedObject detection;
  final Size imageSize;
  final Size screenSize;

  ARDetectionPainter({
    required this.detection,
    required this.imageSize,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final box = detection.boundingBox;
    
    // =======================================================================
    // CONVERSÃO DE COORDENADAS CORRIGIDA
    // =======================================================================
    // A imagem da câmara normalmente é capturada em landscape (ex: 1920x1080)
    // mas o ecrã está em portrait (ex: 1080x1920).
    // O ML Kit dá as coordenadas baseadas na imagem original.
    // Precisamos converter para as coordenadas do ecrã.
    // =======================================================================
    
    // Verifica se precisamos rodar (imagem landscape, ecrã portrait)
    final bool needsRotation = imageSize.width > imageSize.height && 
                               screenSize.height > screenSize.width;
    
    Rect scaledRect;
    
    if (needsRotation) {
      // A imagem está rotacionada 90° em relação ao ecrã
      // Precisamos trocar X por Y e ajustar a origem
      
      // Dimensões efetivas após rotação
      final rotatedImageWidth = imageSize.height;
      final rotatedImageHeight = imageSize.width;
      
      // Fatores de escala
      final scaleX = screenSize.width / rotatedImageWidth;
      final scaleY = screenSize.height / rotatedImageHeight;
      
      // Converter coordenadas (rotação 90° sentido horário)
      // X = imagem.height - box.bottom (espelhado)
      // Y = box.left
      final newLeft = (imageSize.height - box.bottom) * scaleX;
      final newTop = box.left * scaleY;
      final newWidth = box.height * scaleX;
      final newHeight = box.width * scaleY;
      
      scaledRect = Rect.fromLTWH(newLeft, newTop, newWidth, newHeight);
      
    } else {
      // Sem rotação necessária - escala direta
      final scaleX = screenSize.width / imageSize.width;
      final scaleY = screenSize.height / imageSize.height;
      
      scaledRect = Rect.fromLTWH(
        box.left * scaleX,
        box.top * scaleY,
        box.width * scaleX,
        box.height * scaleY,
      );
    }
    
    // Garante que o retângulo está dentro dos limites do ecrã
    scaledRect = Rect.fromLTWH(
      scaledRect.left.clamp(0, screenSize.width - scaledRect.width),
      scaledRect.top.clamp(0, screenSize.height - scaledRect.height),
      scaledRect.width.clamp(10, screenSize.width),
      scaledRect.height.clamp(10, screenSize.height),
    );

    // =======================================================================
    // DESENHAR CAIXA VERDE COM CANTOS ARREDONDADOS
    // =======================================================================
    
    // Fundo semi-transparente
    final fillPaint = Paint()
      ..color = Colors.green.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(scaledRect, const Radius.circular(8)),
      fillPaint,
    );
    
    // Borda verde
    final borderPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(scaledRect, const Radius.circular(8)),
      borderPaint,
    );
    
    // =======================================================================
    // DESENHAR CANTOS DESTACADOS
    // =======================================================================
    final cornerPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    const cornerLength = 20.0;
    final left = scaledRect.left;
    final right = scaledRect.right;
    final top = scaledRect.top;
    final bottom = scaledRect.bottom;
    
    // Canto superior esquerdo
    canvas.drawLine(Offset(left, top + cornerLength), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), cornerPaint);
    
    // Canto superior direito
    canvas.drawLine(Offset(right - cornerLength, top), Offset(right, top), cornerPaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLength), cornerPaint);
    
    // Canto inferior esquerdo
    canvas.drawLine(Offset(left, bottom - cornerLength), Offset(left, bottom), cornerPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLength, bottom), cornerPaint);
    
    // Canto inferior direito
    canvas.drawLine(Offset(right - cornerLength, bottom), Offset(right, bottom), cornerPaint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cornerLength), cornerPaint);

    // =======================================================================
    // DESENHAR LABEL (SE HOUVER)
    // =======================================================================
    if (detection.labels.isNotEmpty) {
      final label = detection.labels.first;
      final labelText = '${label.text} (${(label.confidence * 100).toInt()}%)';
      
      final textSpan = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      
      // Fundo do label
      final labelBgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left,
          top - textPainter.height - 8,
          textPainter.width + 16,
          textPainter.height + 8,
        ),
        const Radius.circular(4),
      );
      
      final labelBgPaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.fill;
      
      canvas.drawRRect(labelBgRect, labelBgPaint);
      
      // Texto do label
      textPainter.paint(
        canvas, 
        Offset(left + 8, top - textPainter.height - 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ARDetectionPainter oldDelegate) {
    return detection != oldDelegate.detection ||
           imageSize != oldDelegate.imageSize ||
           screenSize != oldDelegate.screenSize;
  }
}