import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'analysis_result_screen.dart';
import '../controllers/analyze_controller.dart';
import '../controllers/product_detail_controller.dart';
import '../config/product_categories.dart';
import '../models/api/api_models.dart';
import '../services/api_client.dart';
import '../utils/image_compression.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/product_analysis_sheet.dart';

class _ScanApiResult {
  final String productName;
  final int price;
  final int weightGram;
  final String category;
  final String dbProductId;

  const _ScanApiResult({
    required this.productName,
    required this.price,
    required this.weightGram,
    required this.category,
    required this.dbProductId,
  });

  factory _ScanApiResult.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return _ScanApiResult(
      productName: data['product_name']?.toString() ?? '',
      price: (data['price'] as num?)?.toInt() ?? 0,
      weightGram: (data['weight_gram'] as num?)?.toInt() ?? 0,
      category: data['category']?.toString() ?? '',
      dbProductId: data['db_product_id']?.toString() ?? '',
    );
  }
}

class _ScanApiException implements Exception {
  final int statusCode;
  final String message;

  const _ScanApiException(this.statusCode, this.message);
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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
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
      _scanStatusText = 'scanner_reading_price_text'.tr();
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
      _scanStatusText = 'scanner_reading_gallery_text'.tr();
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
    try {
      final scanResult = await _scanImageWithBackend(imagePath);
      final categoryKey = _categoryKeyFromBackend(scanResult.category);

      if (!mounted) return;
      setState(() {
        _detectedItemName = scanResult.productName;
        _detectedItemPrice = scanResult.price;
        _detectedItemWeight = _formatWeightGram(scanResult.weightGram);
        _detectedItemWeightUnitIndex = 0;
        _detectedItemCategoryKey = categoryKey;
        _lastOcrText = scanResult.productName;
      });

      _showReviewBottomSheet(
        prefillName: scanResult.productName,
        prefillPrice: _formatPriceInput(scanResult.price),
        prefillWeight: _formatWeightGram(scanResult.weightGram),
        prefillWeightUnitIndex: 0,
        prefillCategoryKey: categoryKey,
        dbProductId: scanResult.dbProductId,
        dbCategory: scanResult.category,
      );
    } on _ScanApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 404) {
        _showScannerMessage(
          'Barang belum ditemukan. Coba ketik nama barang secara manual.',
        );
        return;
      }
      _showScannerMessage('Gagal membaca gambar. Coba arahkan kamera lagi.');
    }
  }

  Future<_ScanApiResult> _scanImageWithBackend(String imagePath) async {
    final uploadBytes = await compressedScanImagePathForUpload(imagePath);
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiClient.baseUrl}/v1/scan'),
    );
    request.headers.addAll(
      await ApiClient.headers(requireAuth: true, json: false),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        uploadBytes,
        filename: 'worthit_scan.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
    );
    final response = await http.Response.fromStream(streamedResponse);
    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _ScanApiResult.fromJson(decoded);
    }

    throw _ScanApiException(
      response.statusCode,
      decoded['message']?.toString() ?? 'Gagal membaca gambar. Coba lagi.',
    );
  }

  String _formatWeightGram(int weightGram) {
    if (weightGram <= 0) return '';
    return weightGram.toString();
  }

  String _categoryKeyFromBackend(String category) =>
      officialProductCategories.contains(category) ? category : 'Lainnya';

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
    final itemName = _detectedItemName.isNotEmpty
        ? _detectedItemName
        : 'Produk';
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
    String? dbProductId,
    String? dbCategory,
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
        dbProductId: dbProductId,
        dbCategory: dbCategory,
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
                    _isScanning ? _scanStatusText : 'point_camera_hint'.tr(),
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
                              top:
                                  _scanLineAnimation.value *
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
                                      color: _accentGreen.withValues(
                                        alpha: 0.5,
                                      ),
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
                        icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
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
              Icon(
                Icons.videocam_off_outlined,
                size: 48,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'camera_unavailable'.tr(),
                style: GoogleFonts.urbanist(
                  color: Colors.white38,
                  fontSize: 14,
                ),
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
                'scanner_loading_camera'.tr(),
                style: GoogleFonts.urbanist(
                  color: Colors.white38,
                  fontSize: 13,
                ),
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
      child: Center(child: CameraPreview(camera)),
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
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)],
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
      final isTop = align == Alignment.topLeft || align == Alignment.topRight;
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

class _ReviewBottomSheet extends ConsumerStatefulWidget {
  final String prefillName;
  final String prefillPrice;
  final String prefillWeight;
  final int prefillWeightUnitIndex;
  final String? prefillCategoryKey;
  final String? dbProductId;
  final String? dbCategory;
  final bool autoFocusName;
  final bool showManualInputWarning;

  const _ReviewBottomSheet({
    this.prefillName = '',
    this.prefillPrice = '',
    this.prefillWeight = '',
    this.prefillWeightUnitIndex = 0,
    this.prefillCategoryKey,
    this.dbProductId,
    this.dbCategory,
    this.autoFocusName = false,
    this.showManualInputWarning = false,
  });

  @override
  ConsumerState<_ReviewBottomSheet> createState() => _ReviewBottomSheetState();
}

class _ReviewBottomSheetState extends ConsumerState<_ReviewBottomSheet> {
  static const Color _accentGreen = Color(0xFF304423);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _weightCtrl;

  int _selectedUrgency = 1; // 0=Rendah, 1=Sedang, 2=Tinggi
  bool _isAnalyzing = false;

  // ── Kategori state ──
  String? _selectedKategori;
  final List<String> _categoryKeys = const [
    ...officialProductCategories,
    'Lainnya',
  ];

  // ── Weight unit toggle state ──
  int _weightUnitIndex = 0;
  static const _weightUnits = ['gram', 'kg', 'ml', 'L'];

  String? _itemNameError;
  ProductSummaryModel? _selectedProduct;
  Timer? _productVerificationDebounce;
  bool _isVerifyingProduct = false;
  int _verificationRequestId = 0;

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

    if (widget.dbProductId?.isNotEmpty == true &&
        widget.prefillName.isNotEmpty) {
      _selectedProduct = ProductSummaryModel(
        id: widget.dbProductId!,
        name: widget.prefillName,
        category: widget.dbCategory ?? widget.prefillCategoryKey,
      );
    }

    if (widget.prefillName.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(productDetailControllerProvider.notifier)
              .searchProducts(widget.prefillName);
          if (_selectedProduct == null) {
            _verifyProductAvailability(widget.prefillName);
          }
        }
      });
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
    _productVerificationDebounce?.cancel();
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
      ),
      errorStyle: GoogleFonts.urbanist(
        color: const Color(0xFFEF4444),
        fontSize: 12,
        fontWeight: FontWeight.w600,
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

    final product = await _verifyProductAvailability(
      currentItemName,
      showError: true,
    );
    final productId = product?.id;
    if (productId == null || productId.isEmpty) {
      setState(() {
        _itemNameError = 'Produk tidak tersedia di database';
      });
      return;
    }

    setState(() => _isAnalyzing = true);
    final scannedPrice = _parseNumber(_priceCtrl.text);
    final weightGram = _weightToGram(_parseNumber(_weightCtrl.text));
    ref
        .read(analyzeControllerProvider.notifier)
        .setManualScan(
          productId: productId,
          scannedPrice: scannedPrice,
          weightGram: weightGram,
        );
    ref
        .read(analyzeControllerProvider.notifier)
        .setUrgency(_selectedUrgency + 1);
    await ref.read(analyzeControllerProvider.notifier).analyzeProduct();
    if (!mounted) return;
    final analyzeState = ref.read(analyzeControllerProvider);
    if (analyzeState.errorMessage != null) {
      setState(() => _isAnalyzing = false);
      SnackbarHelper.showTopSnackbar(
        context,
        analyzeState.errorMessage!,
        icon: Icons.warning_amber_rounded,
      );
      return;
    }

    Navigator.pop(context); // close bottom sheet
    final weightText = _weightCtrl.text.trim().isEmpty
        ? ''
        : '${_weightCtrl.text.trim()} ${_weightUnits[_weightUnitIndex]}';
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AnalysisResultScreen(
          productName: product?.name ?? currentItemName,
          price: _priceCtrl.text,
          weight: weightText,
          urgency: _urgencyLabels[_selectedUrgency],
          category:
              widget.dbCategory ??
              _selectedKategori ??
              product?.category ??
              'Lainnya',
        ),
      ),
    );
  }

  Future<ProductSummaryModel?> _verifyProductAvailability(
    String name, {
    bool showError = false,
  }) async {
    final trimmedName = name.trim();
    final normalizedName = _normalizeProductName(trimmedName);

    if (trimmedName.isEmpty) {
      _productVerificationDebounce?.cancel();
      if (mounted) {
        setState(() {
          _isVerifyingProduct = false;
          _selectedProduct = null;
          _itemNameError = null;
        });
      }
      return null;
    }

    if (_selectedProduct != null &&
        _normalizeProductName(_selectedProduct!.name) == normalizedName) {
      return _selectedProduct;
    }

    final requestId = ++_verificationRequestId;
    if (mounted) {
      setState(() {
        _isVerifyingProduct = true;
        if (!showError) _itemNameError = null;
      });
    }

    await ref
        .read(productDetailControllerProvider.notifier)
        .searchProducts(name);
    if (!mounted || requestId != _verificationRequestId) return null;

    final results = ref.read(productDetailControllerProvider).searchResults;
    ProductSummaryModel? exactMatch;
    for (final item in results) {
      if (_normalizeProductName(item.name) == normalizedName) {
        exactMatch = item;
        break;
      }
    }

    setState(() {
      _isVerifyingProduct = false;
      _selectedProduct = exactMatch;
      if (exactMatch == null) {
        _itemNameError = 'Produk tidak tersedia di database';
      } else {
        _itemNameError = null;
        _selectedKategori = _categoryKeyFromBackend(exactMatch.category ?? '');
      }
    });
    return exactMatch;
  }

  void _scheduleProductVerification(String value) {
    _productVerificationDebounce?.cancel();
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) {
      ++_verificationRequestId;
      setState(() {
        _isVerifyingProduct = false;
        _selectedProduct = null;
        _itemNameError = null;
      });
      return;
    }

    _productVerificationDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _verifyProductAvailability(trimmedValue),
    );
  }

  String _normalizeProductName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _categoryKeyFromBackend(String category) =>
      officialProductCategories.contains(category) ? category : 'Lainnya';

  double _parseNumber(String value) {
    return double.tryParse(value.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
  }

  double _weightToGram(double value) {
    final unit = _weightUnits[_weightUnitIndex].toLowerCase();
    if (unit == 'kg' || unit == 'l') return value * 1000;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final catalogOptions = ref
        .watch(productCatalogProvider)
        .maybeWhen(
          data: (items) => items,
          orElse: () => const <ProductSummaryModel>[],
        );
    final searchedOptions = ref
        .watch(productDetailControllerProvider)
        .searchResults;
    final productOptionsById = <String, ProductSummaryModel>{};
    for (final product in [...catalogOptions, ...searchedOptions]) {
      productOptionsById[product.id] = product;
    }
    final productOptions = productOptionsById.values.toList(growable: false);
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
                Autocomplete<ProductSummaryModel>(
                  initialValue: TextEditingValue(text: widget.prefillName),
                  displayStringForOption: (option) => option.name,
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<ProductSummaryModel>.empty();
                    }
                    return productOptions.where(
                      (p) => p.name.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      ),
                    );
                  },
                  onSelected: (ProductSummaryModel selection) {
                    ++_verificationRequestId;
                    _productVerificationDebounce?.cancel();
                    _nameCtrl.text = selection.name;
                    setState(() {
                      _selectedProduct = selection;
                      _itemNameError = null;
                      _isVerifyingProduct = false;
                      _selectedKategori = _categoryKeyFromBackend(
                        selection.category ?? '',
                      );
                    });
                  },
                  fieldViewBuilder:
                      (
                        BuildContext context,
                        TextEditingController fieldTextEditingController,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted,
                      ) {
                        return TextFormField(
                          controller: fieldTextEditingController,
                          focusNode: focusNode,
                          autofocus: widget.autoFocusName,
                          style: GoogleFonts.urbanist(
                            color: const Color(0xFF1E293B),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration:
                              _fieldDecoration(
                                'item_name'.tr(),
                                Icons.label_outline,
                              ).copyWith(
                                errorText: _itemNameError,
                                suffixIcon:
                                    fieldTextEditingController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear,
                                          size: 18,
                                          color: Colors.grey.shade400,
                                        ),
                                        onPressed: () {
                                          ++_verificationRequestId;
                                          _productVerificationDebounce
                                              ?.cancel();
                                          fieldTextEditingController.clear();
                                          _nameCtrl.clear();
                                          setState(() {
                                            _itemNameError = null;
                                            _selectedProduct = null;
                                            _isVerifyingProduct = false;
                                            _selectedKategori = null;
                                          });
                                        },
                                      )
                                    : null,
                              ),
                          onChanged: (value) {
                            _nameCtrl.text = value;
                            _selectedProduct = null;
                            if (_itemNameError != null) {
                              setState(() {
                                _itemNameError = null;
                              });
                            }
                            ref
                                .read(productDetailControllerProvider.notifier)
                                .searchProducts(value);
                            _scheduleProductVerification(value);
                          },
                        );
                      },
                ),
                const SizedBox(height: 14),

                // ── Field: Kategori ──
                DropdownButtonFormField<String>(
                  value: _selectedKategori,
                  decoration: _fieldDecoration(
                    'category'.tr(),
                    Icons.category_outlined,
                  ),
                  style: GoogleFonts.urbanist(
                    color: const Color(0xFF1E293B),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade400,
                  ),
                  items: _categoryKeys.map((key) {
                    return DropdownMenuItem<String>(
                      value: key,
                      child: Text(
                        displayProductCategory(key),
                        style: GoogleFonts.urbanist(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
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
                      _fieldDecoration(
                        'item_price'.tr(),
                        Icons.attach_money,
                      ).copyWith(
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.urbanist(
                    color: const Color(0xFF1E293B),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration:
                      _fieldDecoration(
                        'weight_volume'.tr(),
                        Icons.scale_outlined,
                      ).copyWith(
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
                              horizontal: 14,
                              vertical: 12,
                            ),
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
                          margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
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
                    onPressed:
                        _isAnalyzing ||
                            _isVerifyingProduct ||
                            _selectedProduct == null
                        ? null
                        : _onAnalyze,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentGreen,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isAnalyzing || _isVerifyingProduct
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
                                _isVerifyingProduct
                                    ? 'scanner_checking_product'.tr()
                                    : 'Analyzing...',
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
