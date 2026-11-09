import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/audio_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/product.dart';
import '../../providers/pos_provider.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final bool isMultiBarcodeInitial;
  final bool isPriceChecker;
  final bool isBarcodePicker;

  const BarcodeScannerScreen({
    super.key,
    this.isMultiBarcodeInitial = false,
    this.isPriceChecker = false,
    this.isBarcodePicker = false,
  });

  static Future<Product?> open(
    BuildContext context, {
    bool isMultiScan = false,
    bool isMultiBarcodeInitial = false,
    bool isPriceChecker = false,
  }) async {
    return await Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(
          isMultiBarcodeInitial: isMultiScan || isMultiBarcodeInitial,
          isPriceChecker: isPriceChecker,
        ),
      ),
    );
  }

  /// Scans a single barcode and returns the raw barcode string directly
  static Future<String?> scanBarcodeString(BuildContext context) async {
    final product = await Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(
          isBarcodePicker: true,
        ),
      ),
    );
    return product?.barcode;
  }

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late MobileScannerController _controller;
  late AnimationController _laserAnimController;
  late Animation<double> _laserAnimation;

  bool _isTorchOn = false;
  bool _isFrontCamera = false;
  late bool _isMultiBarcodeMode; // true = scan all barcodes in frame, false = one by one
  String? _lastScannedBanner;
  final TextEditingController _manualBarcodeCtrl = TextEditingController();

  bool _isStartingCamera = false;
  bool _isHandlingDialog = false;
  bool _hasPermissionError = false;
  String? _errorMessage;

  // Barcode debounce map to avoid scanning same barcode 30 times a second
  final Map<String, int> _recentScans = {};
  List<Barcode> _lastDetectedBarcodes = [];
  double _zoomScale = 0.0;

  MobileScannerController _createController() {
    return MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 1000,
      facing: CameraFacing.back,
      torchEnabled: false,
      returnImage: false,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.itf,
        BarcodeFormat.qrCode,
      ],
      useNewCameraSelector: true,
    );
  }

  Future<void> _setZoom(double zoom) async {
    setState(() => _zoomScale = zoom);
    await _controller.setZoomScale(zoom);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isMultiBarcodeMode = widget.isMultiBarcodeInitial;
    _controller = _createController();

    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _laserAnimController, curve: Curves.easeInOut),
    );

    // Give the UI transition time to settle before opening hardware camera
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCameraSafely();
    });
  }

  Future<void> _startCameraSafely({bool forceRecreate = false}) async {
    if (_isStartingCamera || !mounted) return;
    _isStartingCamera = true;

    try {
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }

      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _hasPermissionError = true;
            _errorMessage = 'يرجى منح إذن استخدام الكاميرا لمسح الباركود';
          });
        }
        return;
      }

      if (forceRecreate) {
        try {
          await _controller.stop();
        } catch (_) {}
        try {
          await _controller.dispose();
        } catch (_) {}
        if (!mounted) return;
        setState(() {
          _controller = _createController();
        });
      }

      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      if (!_controller.value.isRunning) {
        await _controller.start();
      }

      if (mounted) {
        setState(() {
          _hasPermissionError = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'تعذر تشغيل الكاميرا المباشرة: $e';
        });
      }
    } finally {
      _isStartingCamera = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startCameraSafely();
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      try {
        _controller.stop();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _laserAnimController.dispose();
    _controller.dispose();
    _manualBarcodeCtrl.dispose();
    super.dispose();
  }

  /// Processes a single detected barcode string
  Future<void> _processBarcode(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty || _isHandlingDialog || !mounted) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (_recentScans.containsKey(code)) {
      final diff = now - _recentScans[code]!;
      if (diff < (_isMultiBarcodeMode ? 1200 : 1600)) {
        return;
      }
    }
    _recentScans[code] = now;

    final pos = Provider.of<POSProvider>(context, listen: false);
    final product = await pos.getProductByBarcode(code);
    if (!mounted) return;

    if (widget.isBarcodePicker) {
      AudioService.playScanBeep();
      Navigator.of(context).pop(product ?? Product(
        barcode: code,
        name: '',
        retailPrice: 0,
        wholesalePrice: 0,
      ));
      return;
    }

    if (widget.isPriceChecker) {
      if (product != null && mounted) {
        AudioService.playScanBeep();
        Navigator.of(context).pop(product);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ السلعة غير مسجلة في الكتالوج'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (product != null) {
      if (product.retailPrice > 0) {
        // Product exists and has price: Add directly to cart
        pos.addToCart(product);
        AudioService.playScanBeep();
        if (mounted) {
          setState(() {
            if (product.costPrice > 0) {
              _lastScannedBanner = '${product.name} • بيع: ${product.retailPrice.round()} دج (شراء: ${product.costPrice.round()} دج)';
            } else {
              _lastScannedBanner = '${product.name} • بيع: ${product.retailPrice.round()} دج';
            }
          });
        }
      } else {
        // Product exists in catalog, but retail price is 0 DZD: prompt to set price
        await _showSetPriceDialog(product);
      }
    } else {
      // Product not found in catalog: prompt to create new product
      await _showAddNewProductDialog(code);
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    _lastDetectedBarcodes = capture.barcodes;
    if (_isHandlingDialog) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    if (!_isMultiBarcodeMode) {
      // Single-item scan mode: Process first valid barcode in continuous scan
      final firstCode = barcodes.first.rawValue?.trim();
      if (firstCode != null && firstCode.isNotEmpty) {
        await _processBarcode(firstCode);
      }
    }
  }

  void _triggerMultiScanCapture() async {
    if (_lastDetectedBarcodes.isEmpty) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔍 وجّه الكاميرا نحو المنتجات واضغط الزر لإضافتها دفعة واحدة'),
          duration: Duration(milliseconds: 1000),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.heavyImpact();
    AudioService.playScanBeep();

    final Set<String> distinctCodes = {};
    for (final b in _lastDetectedBarcodes) {
      final val = b.rawValue?.trim();
      if (val != null && val.isNotEmpty) {
        distinctCodes.add(val);
      }
    }

    int addedCount = 0;
    for (final code in distinctCodes) {
      if (_isHandlingDialog || !mounted) break;
      await _processBarcode(code);
      addedCount++;
    }

    if (mounted && addedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ تم التقاط وإضافة $addedCount سلع بنجاح!'),
          backgroundColor: AppColors.accentDark,
          duration: const Duration(milliseconds: 900),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// BottomSheet to set price when product exists but has 0 DZD price
  Future<void> _showSetPriceDialog(Product product) async {
    _isHandlingDialog = true;
    final retailCtrl = TextEditingController(text: product.retailPrice > 0 ? product.retailPrice.toStringAsFixed(0) : '');
    final costCtrl = TextEditingController(text: product.costPrice > 0 ? product.costPrice.toStringAsFixed(0) : '');
    final pos = Provider.of<POSProvider>(context, listen: false);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final retail = double.tryParse(retailCtrl.text.trim()) ?? 0.0;
          final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
          final profit = retail > 0 ? (retail - cost) : 0.0;

          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.retailColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.price_change_outlined, color: AppColors.retailColor, size: 26),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('تحديد سعر البيع والشراء', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                            Text('السلعة موجودة في الكتالوج ولكن سعرها غير محدد', style: TextStyle(color: Colors.white60, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'الباركود: ${product.barcode}',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: retailCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      labelText: 'سعر البيع للتجزئة (دج) *',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.payments, color: AppColors.retailColor),
                      hintText: 'مثال: 150',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: costCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      labelText: 'سعر الشراء / التكلفة (سعر اللي شراه به) - اختياري',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.shopping_bag_outlined, color: AppColors.accent),
                      hintText: 'سعر جملة الشراء من المورّد',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  if (retail > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: profit >= 0 ? AppColors.accentDark.withOpacity(0.25) : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: profit >= 0 ? AppColors.accent : Colors.redAccent),
                      ),
                      child: Row(
                        children: [
                          Icon(profit >= 0 ? Icons.trending_up : Icons.warning_amber_rounded,
                              color: profit >= 0 ? AppColors.accent : Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            profit >= 0
                                ? 'هامش الربح المتوقع: +${profit.toStringAsFixed(0)} دج بالقطعة'
                                : 'تنبيه: سعر البيع أقل من التكلفة (${profit.toStringAsFixed(0)} دج)',
                            style: TextStyle(
                              color: profit >= 0 ? Colors.white : Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('تخطي'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryIndigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            final retailVal = double.tryParse(retailCtrl.text.trim()) ?? 0.0;
                            if (retailVal <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('⚠️ يرجى إدخال سعر بيع صحيح أكبر من 0 دج'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                              return;
                            }

                            final costVal = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                            final updatedProduct = product.copyWith(
                              retailPrice: retailVal,
                              costPrice: costVal,
                              wholesalePrice: retailVal,
                            );

                            final nav = Navigator.of(ctx);
                            await pos.saveProductAndAddToCart(product: updatedProduct);

                            if (mounted) {
                              setState(() {
                                if (costVal > 0) {
                                  _lastScannedBanner = '${updatedProduct.name} • بيع: ${retailVal.round()} دج (شراء: ${costVal.round()} دج)';
                                } else {
                                  _lastScannedBanner = '${updatedProduct.name} • بيع: ${retailVal.round()} دج';
                                }
                              });
                              nav.pop();
                            }
                          },
                          icon: const Icon(Icons.check, size: 20),
                          label: const Text('حفظ وإضافة للسلة ➔', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    _isHandlingDialog = false;
  }

  /// BottomSheet to register new product when barcode is not found in database
  Future<void> _showAddNewProductDialog(String barcode) async {
    _isHandlingDialog = true;
    final nameCtrl = TextEditingController();
    final retailCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final pos = Provider.of<POSProvider>(context, listen: false);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final retail = double.tryParse(retailCtrl.text.trim()) ?? 0.0;
          final cost = double.tryParse(costCtrl.text.trim()) ?? 0.0;
          final profit = retail > 0 ? (retail - cost) : 0.0;

          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add_shopping_cart, color: AppColors.accent, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('سلعة جديدة غير مسجلة', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                            Text('الباركود الممسوح: $barcode', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'اسم السلعة / المنتج *',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.shopping_bag_outlined, color: AppColors.accent),
                      hintText: 'مثال: بسكويت بيمبو شيكولا',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: retailCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      labelText: 'سعر البيع للتجزئة (دج) *',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.payments, color: AppColors.retailColor),
                      hintText: 'مثال: 120',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: costCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      labelText: 'سعر الشراء / التكلفة (سعر اللي شراه به) - اختياري',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.shopping_bag_outlined, color: AppColors.accent),
                      hintText: 'سعر جملة الشراء من المورّد',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  if (retail > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: profit >= 0 ? AppColors.accentDark.withOpacity(0.25) : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: profit >= 0 ? AppColors.accent : Colors.redAccent),
                      ),
                      child: Row(
                        children: [
                          Icon(profit >= 0 ? Icons.trending_up : Icons.warning_amber_rounded,
                              color: profit >= 0 ? AppColors.accent : Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            profit >= 0
                                ? 'هامش الربح المتوقع: +${profit.toStringAsFixed(0)} دج بالقطعة'
                                : 'تنبيه: سعر البيع أقل من التكلفة (${profit.toStringAsFixed(0)} دج)',
                            style: TextStyle(
                              color: profit >= 0 ? Colors.white : Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            final retailVal = double.tryParse(retailCtrl.text.trim()) ?? 0.0;
                            final costVal = double.tryParse(costCtrl.text.trim()) ?? 0.0;

                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('⚠️ يرجى إدخال اسم السلعة')),
                              );
                              return;
                            }

                            if (retailVal <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('⚠️ يرجى إدخال سعر بيع صحيح أكبر من 0 دج')),
                              );
                              return;
                            }

                            final newProduct = Product(
                              barcode: barcode,
                              name: name,
                              costPrice: costVal,
                              retailPrice: retailVal,
                              wholesalePrice: retailVal,
                              quantity: 100.0,
                              isCustom: true,
                            );

                            final nav = Navigator.of(ctx);
                            await pos.saveProductAndAddToCart(product: newProduct);

                            if (mounted) {
                              setState(() {
                                if (costVal > 0) {
                                  _lastScannedBanner = '$name • بيع: ${retailVal.round()} دج (شراء: ${costVal.round()} دج)';
                                } else {
                                  _lastScannedBanner = '$name • بيع: ${retailVal.round()} دج';
                                }
                              });
                              nav.pop();
                            }
                          },
                          icon: const Icon(Icons.check, size: 20),
                          label: const Text('حفظ وإضافة للسلة ➔', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    _isHandlingDialog = false;
  }

  void _onManualSubmit() async {
    final code = _manualBarcodeCtrl.text.trim();
    if (code.isEmpty) return;
    _manualBarcodeCtrl.clear();
    await _processBarcode(code);
  }

  void _scanFromSystemCamera() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera, maxWidth: 1600, maxHeight: 1600);
      if (photo != null) {
        final capture = await _controller.analyzeImage(photo.path);
        if (capture == null || capture.barcodes.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ لم يتم العثور على باركود واضح في الصورة. يرجى المحاولة بزاوية أوضح'),
                backgroundColor: AppColors.danger,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          _onDetect(capture);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في كاميرا النظام: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Widget _buildZoomChip({required String label, required double value}) {
    final isSelected = (_zoomScale - value).abs() < 0.05;
    return InkWell(
      onTap: () => _setZoom(value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.white12,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = Provider.of<POSProvider>(context);
    final cart = pos.cart;
    final mediaSize = MediaQuery.of(context).size;
    final Rect scanRect = Rect.fromCenter(
      center: Offset(mediaSize.width / 2, mediaSize.height / 2),
      width: 290,
      height: 180,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Fullscreen Live Camera View
          MobileScanner(
            controller: _controller,
            scanWindow: _isMultiBarcodeMode ? null : scanRect,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_hasPermissionError ? Icons.no_photography_outlined : Icons.camera_alt_outlined, color: Colors.amber, size: 54),
                      const SizedBox(height: 14),
                      Text(
                        'تعذر بدء الكاميرا المباشرة (${error.errorCode.name})\n'
                        '${_errorMessage ?? error.errorDetails?.message ?? "يرجى التأكد من منح إذن الكاميرا للهاتف"}',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _startCameraSafely(forceRecreate: true),
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                            onPressed: _scanFromSystemCamera,
                            icon: const Icon(Icons.photo_camera),
                            label: const Text('كاميرا النظام 📸'),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                            ),
                            onPressed: () => openAppSettings(),
                            icon: const Icon(Icons.settings),
                            label: const Text('إعدادات الهاتف'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. High-Tech Animated Viewfinder Frame
          Center(
            child: Container(
              width: 290,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isMultiBarcodeMode ? AppColors.accent : Colors.white,
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (_isMultiBarcodeMode ? AppColors.accent : AppColors.primaryIndigo).withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AnimatedBuilder(
                  animation: _laserAnimation,
                  builder: (context, _) {
                    return Align(
                      alignment: Alignment(0, (_laserAnimation.value * 2) - 1),
                      child: Container(
                        height: 3,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              _isMultiBarcodeMode ? AppColors.accent : const Color(0xFFEF4444),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isMultiBarcodeMode ? AppColors.accent : Colors.red).withOpacity(0.9),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // 3. Viewfinder Aim Indicator Text
          Positioned(
            top: MediaQuery.of(context).size.height * 0.14,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  _isMultiBarcodeMode
                      ? 'وضع المسح الجماعي ⚡ (يلتقط كل الباركودات الظاهرة بالفرايم)'
                      : 'وضع المسح الفردي 🎯 (مرر السلع سلعة بسلعة تباعاً)',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // 4. Top App Bar Controls
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close button -> Returns to POS
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 22),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),

                    // Mode Toggle: Single Item vs Multi-Barcode in frame
                    InkWell(
                      onTap: () => setState(() => _isMultiBarcodeMode = !_isMultiBarcodeMode),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isMultiBarcodeMode ? AppColors.accent : AppColors.primaryIndigo,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isMultiBarcodeMode ? Icons.view_comfortable : Icons.crop_free,
                              color: _isMultiBarcodeMode ? AppColors.accent : Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isMultiBarcodeMode ? 'مسح جماعي ⚡' : 'مسح فردي 🎯',
                              style: TextStyle(
                                color: _isMultiBarcodeMode ? AppColors.accent : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Controls: Torch, Flip, System Camera
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isTorchOn ? Icons.flash_on : Icons.flash_off,
                              color: _isTorchOn ? Colors.amber : Colors.white,
                              size: 18,
                            ),
                          ),
                          onPressed: () async {
                            await _controller.toggleTorch();
                            setState(() => _isTorchOn = !_isTorchOn);
                          },
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.flip_camera_android, color: Colors.white, size: 18),
                          ),
                          onPressed: () async {
                            await _controller.switchCamera();
                            setState(() => _isFrontCamera = !_isFrontCamera);
                          },
                        ),
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.photo_camera, color: AppColors.accent, size: 18),
                          ),
                          tooltip: 'التقاط صورة بكاميرا النظام',
                          onPressed: _scanFromSystemCamera,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4.5. Zoom Selector Pills (1.0x, 1.5x, 2.0x)
          Positioned(
            top: (mediaSize.height / 2) + 105,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildZoomChip(label: '1.0x', value: 0.0),
                    const SizedBox(width: 4),
                    _buildZoomChip(label: '1.5x', value: 0.2),
                    const SizedBox(width: 4),
                    _buildZoomChip(label: '2.0x', value: 0.4),
                  ],
                ),
              ),
            ),
          ),

          // 5. Floating Flash Confirmation Banner
          if (_lastScannedBanner != null)
            Positioned(
              top: (mediaSize.height / 2) + 155,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accentDark.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _lastScannedBanner!,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 6. LIVE SCANNED CART PANEL (ما تم إضافته لايف)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Big floating thumb trigger button in multi-scan mode
                    if (_isMultiBarcodeMode)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.accent, width: 1),
                              ),
                              child: const Text(
                                'اضغط الزر للمسح الجماعي لجميع السلع في الفرايم 🎯',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            InkWell(
                              onTap: _triggerMultiScanCapture,
                              borderRadius: BorderRadius.circular(38),
                              child: Container(
                                width: 74,
                                height: 74,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.primaryGradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accent.withOpacity(0.55),
                                      blurRadius: 18,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(color: Colors.white, width: 3),
                                ),
                                child: const Center(
                                  child: Icon(Icons.qr_code_scanner, color: Colors.white, size: 36),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Live Cart Box
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 1.2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header: Total & Scanned items count
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.shopping_cart, color: AppColors.accent, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'السلة المباشرة (${pos.totalItemsCount} سلع)',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.accent, width: 1),
                                  ),
                                  child: Text(
                                    'الإجمالي: ${CurrencyFormatter.format(pos.netTotal)}',
                                    style: const TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Live Scanned Items List (horizontal mini list)
                          if (cart.isNotEmpty)
                            Container(
                              height: 64,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                itemCount: cart.length,
                                itemBuilder: (ctx, idx) {
                                  final item = cart[cart.length - 1 - idx]; // newest first
                                  final actualIdx = cart.length - 1 - idx;
                                  return Container(
                                    width: 170,
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                item.product.name,
                                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${item.unitPrice.round()} دج',
                                                style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Quick - / + Quantity Adjuster
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: () => pos.updateQuantity(actualIdx, item.quantity - 1),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.white12,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Icon(Icons.remove, color: Colors.white, size: 12),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 5),
                                              child: Text(
                                                '${item.quantity.toInt()}',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () => pos.updateQuantity(actualIdx, item.quantity + 1),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryIndigo,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Icon(Icons.add, color: Colors.white, size: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),

                          // Checkout & Finish Button
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.check_circle_outline, size: 18),
                                label: Text(
                                  cart.isEmpty
                                      ? 'إنهاء والعودة للكاشير ➔'
                                      : 'متابعة الدفع في الكاشير ➔ (${CurrencyFormatter.format(pos.netTotal)})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: cart.isEmpty ? Colors.white24 : AppColors.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Manual Barcode Input Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.keyboard, color: Colors.white70, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _manualBarcodeCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'أو اكتب أرقام الباركود يدوياً...',
                                hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onSubmitted: (_) => _onManualSubmit(),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward, color: AppColors.accent, size: 20),
                            onPressed: _onManualSubmit,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
