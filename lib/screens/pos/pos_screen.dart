import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/cart_item.dart';
import '../../models/product.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/pos_provider.dart';
import 'checkout_dialog.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  late AnimationController _laserAnimController;
  late Animation<double> _laserAnimation;

  bool _isTorchOn = false;
  bool _isFrontCamera = false;
  bool _isScannerVisible = true;
  String? _lastScannedBanner;
  DateTime? _bannerDismissTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initController();

    // Laser scanning line animation
    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _laserAnimController, curve: Curves.easeInOut),
    );
  }

  void _initController() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 500,
      cameraResolution: const Size(1280, 720),
      facing: _isFrontCamera ? CameraFacing.front : CameraFacing.back,
      torchEnabled: _isTorchOn,
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.qrCode,
        BarcodeFormat.itf,
        BarcodeFormat.dataMatrix,
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerController.value.hasCameraPermission) return;

    if (state == AppLifecycleState.resumed) {
      if (_isScannerVisible) {
        _scannerController.start();
      }
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _scannerController.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _laserAnimController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _restartScanner() async {
    try {
      await _scannerController.stop();
    } catch (_) {}
    try {
      await _scannerController.start();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    final pos = Provider.of<POSProvider>(context, listen: false);

    for (final barcode in barcodes) {
      final code = barcode.rawValue?.trim();
      if (code != null && code.isNotEmpty) {
        final product = await pos.handleBarcodeScanned(code);
        if (product != null && mounted) {
          setState(() {
            _lastScannedBanner = '${product.name} • ${product.retailPrice.round()} دج';
            _bannerDismissTime = DateTime.now().add(const Duration(milliseconds: 2200));
          });

          // Auto clear banner
          Future.delayed(const Duration(milliseconds: 2300), () {
            if (mounted && _bannerDismissTime != null && DateTime.now().isAfter(_bannerDismissTime!)) {
              setState(() => _lastScannedBanner = null);
            }
          });
        }
        if (!pos.isMultiScan) {
          break; // Single scan takes first code
        }
      }
    }
  }

  void _showManualSearchDialog() {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final pos = Provider.of<POSProvider>(context, listen: false);
    final searchCtrl = TextEditingController();

    invProv.searchProducts('');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final products = Provider.of<InventoryProvider>(ctx).products;
            final isLoading = Provider.of<InventoryProvider>(ctx).isLoading;

            return Container(
              height: MediaQuery.of(context).size.height * 0.82,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchCtrl,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'ابحث في 42,000 منتج بالاسم أو الباركود...',
                            prefixIcon: const Icon(Icons.search, color: AppColors.primaryIndigo),
                            suffixIcon: searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 20),
                                    onPressed: () {
                                      searchCtrl.clear();
                                      invProv.searchProducts('');
                                      setSheetState(() {});
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (val) {
                            invProv.searchProducts(val);
                            setSheetState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    Expanded(
                      child: products.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  const Text('لا توجد منتجات مطابقة للبحث'),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: products.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final p = products[i];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  leading: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryIndigo.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryIndigo, size: 22),
                                  ),
                                  title: Text(
                                    p.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    'باركود: ${p.barcode} • تجزئة: ${p.retailPrice.round()} دج • جملة: ${p.wholesalePrice.round()} دج',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () {
                                      pos.addToCart(p);
                                      AudioService.playScanBeep();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('✅ تمت إضافة: ${p.name}'),
                                          duration: const Duration(milliseconds: 900),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryIndigo,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Text('إضافة +', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                );
                              },
                            ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCustomItemDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final pos = Provider.of<POSProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_shopping_cart, color: AppColors.primaryIndigo),
            SizedBox(width: 8),
            Text('سلعة متفرقة / بدون باركود', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'اسم السلعة (خبز، خضر، ميزان...)',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'السعر الإفرادي (دج) *',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الكمية / الوزن',
                prefixIcon: Icon(Icons.numbers_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim().isEmpty ? 'سلعة متفرقة' : nameCtrl.text.trim();
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;

              final customProduct = Product(
                barcode: 'CUSTOM-${DateTime.now().millisecondsSinceEpoch}',
                name: name,
                retailPrice: price,
                wholesalePrice: price,
                isCustom: true,
              );

              pos.addToCart(customProduct, qty: qty);
              AudioService.playScanBeep();
              Navigator.of(ctx).pop();
            },
            child: const Text('إضافة للسلة'),
          ),
        ],
      ),
    );
  }

  void _addQuickPreset(String name, double price) {
    final pos = Provider.of<POSProvider>(context, listen: false);
    final p = Product(
      barcode: 'QUICK-${name.hashCode.abs()}',
      name: name,
      retailPrice: price,
      wholesalePrice: price,
      isCustom: true,
    );
    pos.addToCart(p);
    AudioService.playScanBeep();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ أضيف: $name ($price دج)'),
        duration: const Duration(milliseconds: 700),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = Provider.of<POSProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryIndigo.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.point_of_sale, color: AppColors.primaryIndigo, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نظمها POS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('الكاشير ونقاط البيع', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          // Toggle Camera View Button
          IconButton(
            icon: Icon(
              _isScannerVisible ? Icons.videocam : Icons.videocam_off_outlined,
              color: _isScannerVisible ? AppColors.accent : Colors.grey,
            ),
            tooltip: _isScannerVisible ? 'تصغير الكاميرا' : 'تشغيل الكاميرا',
            onPressed: () {
              setState(() {
                _isScannerVisible = !_isScannerVisible;
                if (!_isScannerVisible) {
                  _scannerController.stop();
                } else {
                  _scannerController.start();
                }
              });
            },
          ),
          // Flashlight Toggle
          if (_isScannerVisible)
            IconButton(
              icon: Icon(
                _isTorchOn ? Icons.flash_on : Icons.flash_off,
                color: _isTorchOn ? Colors.amber : null,
              ),
              tooltip: 'فلاش الكاميرا',
              onPressed: () async {
                await _scannerController.toggleTorch();
                setState(() => _isTorchOn = !_isTorchOn);
              },
            ),
          // Manual Search in 42k
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.primaryIndigo),
            tooltip: 'بحث يدوي بالاسم أو الباركود',
            onPressed: _showManualSearchDialog,
          ),
          // Clear cart
          if (pos.cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.danger),
              tooltip: 'تفريغ السلة',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('تفريغ السلة؟'),
                    content: const Text('هل أنت متأكد من مسح جميع المنتجات من السلة الحالية؟'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                        onPressed: () {
                          pos.clearCart();
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('تفريغ'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Upper Portion: Smart Camera Barcode Scanner
          if (_isScannerVisible)
            Container(
              height: MediaQuery.of(context).size.height * 0.31,
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onDetect,
                    errorBuilder: (context, error, child) {
                      return Container(
                        color: const Color(0xFF0F172A),
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.camera_alt_outlined, color: Colors.amber, size: 38),
                              const SizedBox(height: 8),
                              Text(
                                error.errorCode == MobileScannerErrorCode.permissionDenied
                                    ? 'يرجى منح صلاحية الكاميرا لمسح الباركود'
                                    : 'جاري تشغيل الكاميرا...',
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _restartScanner,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('إعادة المحاولة'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // High-tech Viewfinder with Glowing Corners
                  Center(
                    child: Container(
                      width: 280,
                      height: 130,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: pos.isMultiScan ? AppColors.accent : Colors.white.withOpacity(0.85),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (pos.isMultiScan ? AppColors.accent : AppColors.primaryIndigo).withOpacity(0.35),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedBuilder(
                          animation: _laserAnimation,
                          builder: (context, _) {
                            return Align(
                              alignment: Alignment(0, (_laserAnimation.value * 2) - 1),
                              child: Container(
                                height: 2.5,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      pos.isMultiScan ? AppColors.accent : const Color(0xFFEF4444),
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (pos.isMultiScan ? AppColors.accent : Colors.red).withOpacity(0.8),
                                      blurRadius: 6,
                                      spreadRadius: 1,
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

                  // Top Scan Controls Overlay Pill
                  Positioned(
                    top: 10,
                    right: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                pos.isMultiScan ? Icons.bolt : Icons.filter_center_focus,
                                color: pos.isMultiScan ? AppColors.accent : Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                pos.isMultiScan ? 'مسح سريع مستمر ⚡' : 'مسح ذكي تلقائي 🎯',
                                style: TextStyle(
                                  color: pos.isMultiScan ? AppColors.accent : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              // Flip camera
                              InkWell(
                                onTap: () async {
                                  await _scannerController.switchCamera();
                                  setState(() => _isFrontCamera = !_isFrontCamera);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.flip_camera_android, color: Colors.white, size: 18),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Multi-scan switch
                              Transform.scale(
                                scale: 0.8,
                                child: Switch(
                                  value: pos.isMultiScan,
                                  activeColor: AppColors.accent,
                                  onChanged: (val) => pos.toggleMultiScan(val),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Floating Last Scanned Product Confirmation Banner
                  if (_lastScannedBanner != null)
                    Positioned(
                      bottom: 10,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.accentDark.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 3)),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
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
                ],
              ),
            ),

          // Quick Action Ribbon: Price Type & Quick Preset Items (خبز، حليب، بيض)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              children: [
                // Wholesale / Retail Segmented Toggle
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => pos.setGlobalPriceType(PriceType.retail),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: pos.globalPriceType == PriceType.retail ? AppColors.primaryIndigo : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'تجزئة 🛍️',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: pos.globalPriceType == PriceType.retail ? Colors.white : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => pos.setGlobalPriceType(PriceType.wholesale),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: pos.globalPriceType == PriceType.wholesale ? AppColors.wholesaleColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'جملة 🏷️',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: pos.globalPriceType == PriceType.wholesale ? Colors.white : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Quick Fast Add Chips (خبز، حليب، بيض، ماء...)
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickAddChip('🥖 خبز', 15.0),
                        _buildQuickAddChip('🥛 حليب', 25.0),
                        _buildQuickAddChip('🥚 بيض', 25.0),
                        _buildQuickAddChip('💧 ماء 1.5ل', 40.0),
                        // Custom unbarcoded item button
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 14, color: AppColors.primaryIndigo),
                          label: const Text('أخرى', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          onPressed: _showAddCustomItemDialog,
                          backgroundColor: AppColors.primaryIndigo.withOpacity(0.08),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lower Portion: Cart List and Live Totals
          Expanded(
            child: pos.cart.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.primaryIndigo.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.shopping_cart_outlined, size: 40, color: AppColors.primaryIndigo),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'سلة المشتريات فارغة',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _isScannerVisible
                                ? 'وجه الكاميرا نحو باركود أي سلعة للإضافة الفورية'
                                : 'اضغط على أيقونة الكاميرا أو ابحث بالاسم للإضافة',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _showManualSearchDialog,
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text('تصفح كتالوج 42,000 منتج'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    itemCount: pos.cart.length,
                    itemBuilder: (context, index) {
                      final item = pos.cart[index];
                      return Dismissible(
                        key: ValueKey('${item.product.barcode}_$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          child: const Row(
                            children: [
                              SizedBox(width: 16),
                              Icon(Icons.delete_outline, color: Colors.white, size: 26),
                              SizedBox(width: 8),
                              Text('حذف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        onDismissed: (_) {
                          pos.removeFromCart(index);
                          AudioService.playScanBeep();
                        },
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                // Item Number / Icon
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: (item.priceType == PriceType.wholesale ? AppColors.wholesaleColor : AppColors.primaryIndigo).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: item.priceType == PriceType.wholesale ? AppColors.wholesaleColor : AppColors.primaryIndigo,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Item Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          InkWell(
                                            onTap: () => pos.toggleItemPriceType(index),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: item.priceType == PriceType.wholesale
                                                    ? AppColors.wholesaleColor.withOpacity(0.12)
                                                    : AppColors.retailColor.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item.priceType == PriceType.wholesale ? 'جملة 🏷️' : 'تجزئة 🛍️',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: item.priceType == PriceType.wholesale ? AppColors.wholesaleColor : AppColors.retailColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${item.unitPrice.round()} دج',
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Quantity Controls (- / +)
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          pos.updateQuantity(index, item.quantity - 1);
                                          AudioService.playScanBeep();
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: const Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(Icons.remove, size: 18, color: AppColors.danger),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        child: Text(
                                          '${item.quantity.toInt()}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          pos.updateQuantity(index, item.quantity + 1);
                                          AudioService.playScanBeep();
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: const Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(Icons.add, size: 18, color: AppColors.accentDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Subtotal
                                SizedBox(
                                  width: 75,
                                  child: Text(
                                    CurrencyFormatter.format(item.subtotal),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom POS Summary & Checkout Action Panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Subtotal and Items Counter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shopping_bag_outlined, size: 18, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            'العدد: ${pos.totalItemsCount} سلع (${pos.cart.length} صنف)',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                      if (pos.discount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'تخفيض: -${pos.discount.round()} دج',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.danger),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Checkout Action Button
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: pos.cart.isEmpty ? null : AppColors.accentGradient,
                            color: pos.cart.isEmpty ? Colors.grey.shade400 : null,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: pos.cart.isEmpty
                                ? null
                                : [
                                    BoxShadow(
                                      color: AppColors.accent.withOpacity(0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: ElevatedButton(
                            onPressed: pos.cart.isEmpty ? null : () => CheckoutDialog.show(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.payment, size: 20),
                                    SizedBox(width: 8),
                                    Text('إتمام البيع (الدفع)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    CurrencyFormatter.format(pos.netTotal),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

  Widget _buildQuickAddChip(String label, double price) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        onPressed: () => _addQuickPreset(label.replaceAll(RegExp(r'[^\u0621-\u064A\s]'), '').trim(), price),
        backgroundColor: const Color(0xFFF1F5F9),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
