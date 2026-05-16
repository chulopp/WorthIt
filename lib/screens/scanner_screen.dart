import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'analysis_result_screen.dart';
import '../services/ocr_parser_service.dart';
import '../utils/snackbar_helper.dart';
import '../utils/string_similarity.dart';
import '../widgets/product_analysis_sheet.dart';

const double _ocrSimilarityThreshold = 0.6;

class _CatalogProduct {
  final String name;
  final String categoryKey;

  const _CatalogProduct({
    required this.name,
    required this.categoryKey,
  });
}

const List<_CatalogProduct> _scannerProductCatalog = [
  _CatalogProduct(name: 'Beras Maknyuss 5kg', categoryKey: 'cat_sembako'),
  _CatalogProduct(name: 'Bimoli Minyak Goreng 2L', categoryKey: 'cat_sembako'),
  _CatalogProduct(name: 'Gula Pasir Gulaku 1kg', categoryKey: 'cat_sembako'),
  _CatalogProduct(name: 'Indomie Goreng', categoryKey: 'cat_sembako'),
  _CatalogProduct(name: 'Mie Sedap Kuah Soto', categoryKey: 'cat_sembako'),
  _CatalogProduct(name: 'Bear Brand Milk 189ml', categoryKey: 'cat_minuman'),
  _CatalogProduct(
    name: 'Susu Ultra Full Cream 1L',
    categoryKey: 'cat_minuman',
  ),
  _CatalogProduct(
    name: 'Chitato Sapi Panggang 68g',
    categoryKey: 'cat_cemilan',
  ),
  _CatalogProduct(name: 'Taro Snack Net 65g', categoryKey: 'cat_cemilan'),
  _CatalogProduct(
    name: 'Sabun Cair Lifebuoy 450ml',
    categoryKey: 'cat_alat_mandi',
  ),
  _CatalogProduct(name: 'Telur Ayam 1kg', categoryKey: 'cat_sembako'),
];

final List<String> _scannerProductDatabase = _scannerProductCatalog
    .map((product) => product.name)
    .toList(growable: false);

String _normalizeCandidateForMatching(String value) {
  return value
      .replaceAll(RegExp(r'(?:Rp|rp|RP)\s*\.?\s*\d{1,3}(?:\.\d{3})*'), ' ')
      .replaceAll(
        RegExp(
          r'(\d+(?:[.,]\d+)?)\s*(g|kg|ml|l|gr)\b',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(RegExp(r'[^A-Za-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? findClosestProductMatch(
  String scannedText,
  List<String> database, {
  double threshold = _ocrSimilarityThreshold,
}) {
  double bestScore = 0;
  String? bestMatch;

  final lines = scannedText
      .split('\n')
      .map(_normalizeCandidateForMatching)
      .where((line) => line.isNotEmpty)
      .toList();

  for (final line in lines) {
    for (final product in database) {
      final score = calculateStringSimilarity(line, product);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = product;
      }
    }
  }

  return bestScore >= threshold ? bestMatch : null;
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with TickerProviderStateMixin {
  // ── Constants ──
  static const Color _accentGreen = Color(0xFF304423);
  static const Color _darkBg = Color(0xFF0A0A0A);

  // ── Camera ──
  CameraController? _cameraController;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isCameraReady = false;
  bool _isCameraError = false;

  // ── Scan State ──
  bool _isScanning = false;
  bool _isFrozen = false;
  bool _isFlashOn = false;
  String _scanStatusText = '';
  String _detectedItemName = '';
  int? _detectedItemPrice;
  String _detectedItemWeight = '';
  int _detectedItemWeightUnitIndex = 0;
  String? _detectedItemCategoryKey;
  String _lastOcrText = '';

  // ── Animations ──
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    // Immersive status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _isCameraError = true);
        return;
      }
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(FlashMode.off);
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      if (mounted) setState(() => _isCameraError = true);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _pulseController.dispose();
    _scanLineController.dispose();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    super.dispose();
  }

  // ── TUGAS 4: Scan Simulation ──
  Future<void> _triggerScan() async {
    if (_isScanning ||
        !_isCameraReady ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isScanning = true;
      _isFrozen = true;
      _scanStatusText = 'Membaca teks harga...';
    });
    _scanLineController.repeat();

    try {
      final photo = await _cameraController!.takePicture();
      await processImageForOCR(photo.path);
    } catch (_) {
      if (mounted) {
        _showScannerMessage('Gagal membaca gambar. Coba arahkan kamera lagi.');
      }
    } finally {
      if (!mounted) return;
      _scanLineController.stop();
      _scanLineController.reset();

      setState(() {
        _isScanning = false;
        _isFrozen = false;
        _scanStatusText = '';
      });
    }
  }

  // ── TUGAS 2: Review Bottom Sheet ──
  Future<void> pickImageFromGallery() async {
    if (_isScanning) return;

    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedImage == null) return;

    setState(() {
      _isScanning = true;
      _isFrozen = true;
      _scanStatusText = 'Membaca teks dari galeri...';
    });

    try {
      await processImageForOCR(pickedImage.path);
    } catch (_) {
      if (mounted) {
        _showScannerMessage('Gagal membaca gambar dari galeri.');
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _isFrozen = false;
        _scanStatusText = '';
      });
    }
  }

  Future<void> processImageForOCR(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await textRecognizer.processImage(inputImage);
      final rawText = recognizedText.blocks
          .expand((block) => block.lines)
          .map((line) => line.text.trim())
          .where((line) => line.isNotEmpty)
          .join('\n');
      final parsed = OcrParserService.parseSupermarketLabel(rawText);
      final candidateText =
          (parsed['nameCandidates'] as List<dynamic>? ?? const <dynamic>[])
              .map((candidate) => candidate.toString())
              .where((candidate) => candidate.trim().isNotEmpty)
              .join('\n');
      final matchedName = candidateText.isEmpty
          ? null
          : findClosestProductMatch(candidateText, _scannerProductDatabase);
      final matchedProduct = matchedName == null
          ? null
          : _findCatalogProductByName(matchedName);
      final price = parsed['price'] as int?;
      final weight = parsed['weight'] as double?;
      final weightUnit = parsed['weightUnit'] as String?;
      final fallbackToManualName = matchedProduct == null;

      if (!mounted) return;
      setState(() {
        _detectedItemName = matchedProduct?.name ?? '';
        _detectedItemPrice = price;
        _detectedItemWeight = _formatParsedWeight(weight);
        _detectedItemWeightUnitIndex = _unitIndexFromParsedUnit(weightUnit);
        _detectedItemCategoryKey = matchedProduct?.categoryKey;
        _lastOcrText = rawText;
      });

      final feedbackMessages = <String>[];
      if (fallbackToManualName) {
        feedbackMessages.add(
          'Teks tidak terbaca jelas, silakan input manual',
        );
      }
      if (price == null) {
        feedbackMessages.add(
          'Harga Rupiah tidak ditemukan. Pastikan label memuat format Rp.',
        );
      }
      if (!fallbackToManualName && feedbackMessages.isNotEmpty) {
        _showScannerMessage(feedbackMessages.join(' '));
      }

      _showReviewBottomSheet(
        prefillName: matchedProduct?.name ?? '',
        prefillPrice: price != null ? _formatPriceInput(price) : '',
        prefillWeight: _formatParsedWeight(weight),
        prefillWeightUnitIndex: _unitIndexFromParsedUnit(weightUnit),
        prefillCategoryKey: matchedProduct?.categoryKey,
        autoFocusName: fallbackToManualName,
        showManualInputWarning: fallbackToManualName,
      );
    } finally {
      await textRecognizer.close();
    }
  }

  int _unitIndexFromParsedUnit(String? rawUnit) {
    switch (rawUnit?.toLowerCase()) {
      case 'g':
      case 'gr':
        return 0;
      case 'kg':
        return 1;
      case 'ml':
        return 2;
      case 'l':
        return 3;
      default:
        return 0;
    }
  }

  String _formatParsedWeight(double? weight) {
    if (weight == null) return '';
    if (weight % 1 == 0) return weight.toInt().toString();
    return weight.toString();
  }

  _CatalogProduct? _findCatalogProductByName(String name) {
    for (final product in _scannerProductCatalog) {
      if (product.name.toLowerCase() == name.toLowerCase()) {
        return product;
      }
    }
    return null;
  }

  String _formatPriceInput(int price) {
    final digits = price.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  void _showProductAnalysisBottomSheet() {
    final itemName =
        _detectedItemName.isNotEmpty ? _detectedItemName : 'Produk';
    final itemPrice = _detectedItemPrice ?? 0;

    showProductAnalysisSheet(
      context,
      item: {
        'name': itemName,
        'price': itemPrice.toString(),
        'status': 'scanned',
        'score': '78',
        'decision': 'Hasil OCR',
        'category': 'Hasil Scan',
        'urgency': 'Sedang',
        'weight': '',
        'icon': _getItemIcon(itemName),
        'ocrText': _lastOcrText,
      },
    );
  }

  IconData _getItemIcon(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('mie')) return Icons.fastfood;
    if (normalized.contains('susu')) return Icons.emoji_food_beverage;
    if (normalized.contains('beras')) return Icons.rice_bowl;
    if (normalized.contains('minyak')) return Icons.water_drop;
    if (normalized.contains('kopi')) return Icons.coffee;
    if (normalized.contains('snack') ||
        normalized.contains('keripik') ||
        normalized.contains('chitato')) {
      return Icons.cookie;
    }
    return Icons.shopping_bag;
  }

  void _showScannerMessage(String message) {
    SnackbarHelper.showTopSnackbar(
      context,
      message,
      icon: Icons.warning_amber_rounded,
    );
  }

  void _showReviewBottomSheet({
    String prefillName = '',
    String prefillPrice = '',
    String prefillWeight = '',
    int prefillWeightUnitIndex = 0,
    String? prefillCategoryKey,
    bool autoFocusName = false,
    bool showManualInputWarning = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewBottomSheet(
        prefillName: prefillName,
        prefillPrice: prefillPrice,
        prefillWeight: prefillWeight,
        prefillWeightUnitIndex: prefillWeightUnitIndex,
        prefillCategoryKey: prefillCategoryKey,
        autoFocusName: autoFocusName,
        showManualInputWarning: showManualInputWarning,
      ),
    );
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    final nextFlashState = !_isFlashOn;

    try {
      await _cameraController!.setFlashMode(
        nextFlashState ? FlashMode.torch : FlashMode.off,
      );
      if (!mounted) return;
      setState(() => _isFlashOn = nextFlashState);
    } catch (_) {
      if (!mounted) return;
      _showScannerMessage('Flash tidak tersedia pada kamera ini.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final viewfinderSize = mq.size.width * 0.72;

    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1: Camera Preview ──
          _buildCameraPreview(),

          // ── Layer 2: Dark vignette overlay ──
          _buildVignetteOverlay(),

          // ── Layer 3: Viewfinder + Guide Text ──
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Guide text above viewfinder
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Opacity(
                    opacity: _isScanning ? 1.0 : _pulseAnimation.value,
                    child: child,
                  ),
                  child: Text(
                    _isScanning
                        ? _scanStatusText
                        : 'point_camera_hint'.tr(),
                    style: GoogleFonts.urbanist(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Viewfinder box
                GestureDetector(
                  onTap: _triggerScan,
                  child: SizedBox(
                    width: viewfinderSize,
                    height: viewfinderSize,
                    child: Stack(
                      children: [
                        // Corner brackets
                        ..._buildCornerBrackets(viewfinderSize),

                        // Scan line animation
                        if (_isScanning)
                          AnimatedBuilder(
                            animation: _scanLineAnimation,
                            builder: (context, _) => Positioned(
                              top: _scanLineAnimation.value *
                                  (viewfinderSize - 4),
                              left: 20,
                              right: 20,
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      _accentGreen.withValues(alpha: 0.8),
                                      _accentGreen,
                                      _accentGreen.withValues(alpha: 0.8),
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          _accentGreen.withValues(alpha: 0.5),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Layer 4: Top Overlay Bar ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: mq.padding.top + 16,
                left: 24,
                right: 24,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSquareButton(
                    icon: Icons.arrow_back_ios_new,
                    onTap: () => Navigator.pop(context),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSquareButton(
                        icon: _isFlashOn
                            ? Icons.flash_on
                            : Icons.flash_off,
                        onTap: _toggleFlash,
                      ),
                      const SizedBox(width: 8),
                      _buildSquareButton(
                        icon: Icons.photo_library,
                        onTap: pickImageFromGallery,
                      ),
                      const SizedBox(width: 8),
                      _buildSquareButton(
                        icon: Icons.edit,
                        onTap: () => _showReviewBottomSheet(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Layer 5: Bottom hint ──
          Positioned(
            bottom: mq.padding.bottom + 32,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Capture button
                GestureDetector(
                  onTap: _triggerScan,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    child: Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isScanning
                              ? _accentGreen
                              : Colors.white.withValues(alpha: 0.9),
                        ),
                        child: _isScanning
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt_rounded,
                                color: Color(0xFF1E293B),
                                size: 26,
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'scan_instruction'.tr(),
                  style: GoogleFonts.urbanist(
                    fontSize: 13,
                    color: Colors.white60,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  // ── Camera Preview Widget ──
  Widget _buildCameraPreview() {
    if (_isCameraError) {
      return Container(
        color: _darkBg,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_outlined,
                  size: 48, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text(
                'camera_unavailable'.tr(),
                style: GoogleFonts.urbanist(
                    color: Colors.white38, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
    if (!_isCameraReady || _cameraController == null) {
      return Container(
        color: _darkBg,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _accentGreen.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Mempersiapkan kamera...',
                style: GoogleFonts.urbanist(
                    color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // Full-screen camera with aspect ratio handling
    final camera = _cameraController!;
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * camera.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;

    return Transform.scale(
      scale: scale,
      child: Center(
        child: CameraPreview(camera),
      ),
    );
  }

  // ── Vignette Overlay ──
  Widget _buildVignetteOverlay() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.85,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.4),
            ],
          ),
        ),
      ),
    );
  }

  // ── Square Button (Tugas 1) ──
  Widget _buildSquareButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.grey[800], size: 22),
      ),
    );
  }

  // ── Corner Brackets ──
  List<Widget> _buildCornerBrackets(double size) {
    const bracketLen = 32.0;
    const strokeWidth = 2.5;
    const color = _accentGreen;

    Widget corner(Alignment align) {
      final isTop =
          align == Alignment.topLeft || align == Alignment.topRight;
      final isLeft =
          align == Alignment.topLeft || align == Alignment.bottomLeft;
      return Positioned(
        top: isTop ? 0 : null,
        bottom: !isTop ? 0 : null,
        left: isLeft ? 0 : null,
        right: !isLeft ? 0 : null,
        child: SizedBox(
          width: bracketLen,
          height: bracketLen,
          child: CustomPaint(
            painter: _BracketPainter(align, color, strokeWidth),
          ),
        ),
      );
    }

    return [
      corner(Alignment.topLeft),
      corner(Alignment.topRight),
      corner(Alignment.bottomLeft),
      corner(Alignment.bottomRight),
    ];
  }
}

// ══════════════════════════════════════════════════════════════
// ── REVIEW BOTTOM SHEET (Tugas 2 & 3) ──
// ══════════════════════════════════════════════════════════════

class _ReviewBottomSheet extends StatefulWidget {
  final String prefillName;
  final String prefillPrice;
  final String prefillWeight;
  final int prefillWeightUnitIndex;
  final String? prefillCategoryKey;
  final bool autoFocusName;
  final bool showManualInputWarning;

  const _ReviewBottomSheet({
    this.prefillName = '',
    this.prefillPrice = '',
    this.prefillWeight = '',
    this.prefillWeightUnitIndex = 0,
    this.prefillCategoryKey,
    this.autoFocusName = false,
    this.showManualInputWarning = false,
  });

  @override
  State<_ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends State<_ReviewBottomSheet> {
  static const Color _accentGreen = Color(0xFF304423);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _weightCtrl;

  int _selectedUrgency = 1; // 0=Rendah, 1=Sedang, 2=Tinggi
  bool _isAnalyzing = false;

  // ── Kategori state ──
  String? _selectedKategori;
  final List<String> _categoryKeys = [
    'cat_sembako',
    'cat_cemilan',
    'cat_minuman',
    'cat_alat_mandi',
    'cat_lainnya'
  ];

  // ── Weight unit toggle state ──
  int _weightUnitIndex = 0;
  static const _weightUnits = ['gram', 'kg', 'ml', 'L'];

  String? _itemNameError;

  List<String> get _urgencyLabels => ['low'.tr(), 'medium'.tr(), 'high'.tr()];
  static const _urgencyColors = [
    Color(0xFFC9E88A), // Green
    Color(0xFFFBBF24), // Yellow
    Color(0xFFEF4444), // Red
  ];
  static const _urgencyBgColors = [
    Color(0xFFD1FAE5), // Light green
    Color(0xFFFEF3C7), // Light yellow
    Color(0xFFFEE2E2), // Light red
  ];
  static const _urgencyTextColors = [
    Color(0xFF15803D), // Dark Green
    Color(0xFFB45309), // Dark Orange
    Color(0xFFB91C1C), // Dark Red
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.prefillName);
    _priceCtrl = TextEditingController(text: widget.prefillPrice);
    _weightCtrl = TextEditingController(text: widget.prefillWeight);
    _selectedKategori = widget.prefillCategoryKey;
    _weightUnitIndex = widget.prefillWeightUnitIndex;

    if (_selectedKategori == null && widget.prefillName.isNotEmpty) {
      _selectedKategori =
          _findCatalogProductByName(widget.prefillName)?.categoryKey;
    }

    if (widget.showManualInputWarning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        SnackbarHelper.showTopSnackbar(
          context,
          'Teks tidak terbaca jelas, silakan input manual',
          icon: Icons.warning_amber_rounded,
        );
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.urbanist(
        color: const Color(0xFF94A3B8),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, size: 20, color: _accentGreen),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _accentGreen, width: 1.5),
      ),
    );
  }

  Future<void> _onAnalyze() async {
    final currentItemName = _nameCtrl.text.trim();

    if (currentItemName.isEmpty) {
      setState(() {
        _itemNameError = 'item_not_found_error'.tr();
      });
      return;
    }

    final matchedProduct = _findCatalogProductByName(currentItemName);
    if (matchedProduct == null) {
      setState(() {
        _itemNameError = 'Barang tidak ditemukan di database kami.';
      });
      return;
    }

    setState(() => _isAnalyzing = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    Navigator.pop(context); // close bottom sheet
    final weightText = _weightCtrl.text.trim().isEmpty
        ? ''
        : '${_weightCtrl.text.trim()} ${_weightUnits[_weightUnitIndex]}';
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AnalysisResultScreen(
          productName: matchedProduct.name,
          price: _priceCtrl.text,
          weight: weightText,
          urgency: _urgencyLabels[_selectedUrgency],
          category: _selectedKategori ?? matchedProduct.categoryKey,
        ),
      ),
    );
  }

  _CatalogProduct? _findCatalogProductByName(String name) {
    for (final product in _scannerProductCatalog) {
      if (product.name.toLowerCase() == name.trim().toLowerCase()) {
        return product;
      }
    }
    return null;
  }

  void _syncCategoryForName(String value) {
    final matchedProduct = _findCatalogProductByName(value);
    final nextCategory = matchedProduct?.categoryKey;

    if (_selectedKategori != nextCategory) {
      setState(() {
        _selectedKategori = nextCategory;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Text(
                'review_data'.tr(),
                style: GoogleFonts.urbanist(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 24),

              // ── Field: Nama Barang (Autocomplete) ──
              Autocomplete<String>(
                initialValue: TextEditingValue(text: widget.prefillName),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return _scannerProductDatabase.where((p) =>
                    p.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                onSelected: (String selection) {
                  _nameCtrl.text = selection;
                  final matchedProduct = _findCatalogProductByName(selection);
                  if (_itemNameError != null) {
                    setState(() {
                      _itemNameError = null;
                      _selectedKategori = matchedProduct?.categoryKey;
                    });
                  } else {
                    _syncCategoryForName(selection);
                  }
                },
                fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                    return TextFormField(
                      controller: fieldTextEditingController,
                      focusNode: focusNode,
                      autofocus: widget.autoFocusName,
                      style: GoogleFonts.urbanist(
                        color: const Color(0xFF1E293B),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: _fieldDecoration('item_name'.tr(), Icons.label_outline).copyWith(
                        errorText: _itemNameError,
                        suffixIcon: fieldTextEditingController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 18, color: Colors.grey.shade400),
                                onPressed: () {
                                  fieldTextEditingController.clear();
                                  _nameCtrl.clear();
                                  setState(() {
                                    _itemNameError = null;
                                    _selectedKategori = null;
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        _nameCtrl.text = value;
                        if (_itemNameError != null) {
                          setState(() {
                            _itemNameError = null;
                          });
                        }
                        _syncCategoryForName(value);
                      },
                    );
                },
              ),
              const SizedBox(height: 14),

              // ── Field: Kategori ──
              DropdownButtonFormField<String>(
                value: _selectedKategori,
                decoration: _fieldDecoration(
                    'category'.tr(), Icons.category_outlined),
                style: GoogleFonts.urbanist(
                  color: const Color(0xFF1E293B),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(14),
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade400),
                items: _categoryKeys.map((key) {
                  return DropdownMenuItem<String>(
                    value: key,
                    child: Text(key.tr(),
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1E293B),
                        )),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedKategori = val),
              ),
              const SizedBox(height: 14),

              // ── Field: Harga Barang ──
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _ThousandSeparatorFormatter(),
                ],
                style: GoogleFonts.urbanist(
                  color: const Color(0xFF1E293B),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration:
                    _fieldDecoration('item_price'.tr(), Icons.attach_money).copyWith(
                  prefixText: 'Rp ',
                  prefixStyle: GoogleFonts.urbanist(
                    color: const Color(0xFF1E293B),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Field: Berat/Volume ──
              TextFormField(
                controller: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.urbanist(
                  color: const Color(0xFF1E293B),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: _fieldDecoration(
                    'weight_volume'.tr(), Icons.scale_outlined).copyWith(
                  suffixIcon: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      setState(() {
                        _weightUnitIndex =
                            (_weightUnitIndex + 1) % _weightUnits.length;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Text(
                        _weightUnits[_weightUnitIndex],
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _accentGreen,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Urgency Selector ──
              Text(
                'urgency_level'.tr(),
                style: GoogleFonts.urbanist(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: List.generate(3, (i) {
                  final isSelected = _selectedUrgency == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedUrgency = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: EdgeInsets.only(
                          right: i < 2 ? 8 : 0,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _urgencyBgColors[i]
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? _urgencyColors[i]
                                : Colors.grey.shade200,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              i == 0
                                  ? Icons.arrow_downward_rounded
                                  : i == 1
                                      ? Icons.remove_rounded
                                      : Icons.priority_high_rounded,
                              size: 18,
                              color: isSelected
                                  ? _urgencyColors[i]
                                  : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _urgencyLabels[i],
                              style: GoogleFonts.urbanist(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? _urgencyTextColors[i]
                                    : const Color(0xFF4B5563),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),

              // ── Analyze Button (Tugas 3) ──
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isAnalyzing ? null : _onAnalyze,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentGreen,
                    disabledBackgroundColor:
                        _accentGreen.withValues(alpha: 0.7),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isAnalyzing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Analyzing...',
                              style: GoogleFonts.urbanist(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'analyze_now'.tr(),
                          style: GoogleFonts.urbanist(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ── THOUSAND SEPARATOR FORMATTER ──
// ══════════════════════════════════════════════════════════════

class _ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final digits = newValue.text.replaceAll('.', '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ── BRACKET PAINTER ──
// ══════════════════════════════════════════════════════════════

class _BracketPainter extends CustomPainter {
  final Alignment alignment;
  final Color color;
  final double strokeWidth;
  _BracketPainter(this.alignment, this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    if (alignment == Alignment.topLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (alignment == Alignment.topRight) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (alignment == Alignment.bottomLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
