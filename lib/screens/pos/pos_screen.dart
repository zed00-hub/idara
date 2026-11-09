import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/audio_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/cart_item.dart';
import '../../models/product.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/pos_provider.dart';
import '../../widgets/app_drawer.dart';
import 'barcode_scanner_screen.dart';
import 'checkout_dialog.dart';

class POSScreen extends StatefulWidget {
  final bool isActive;
  const POSScreen({super.key, this.isActive = true});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> with WidgetsBindingObserver {
  MobileScannerController? _posCameraController;
  bool _isCameraCollapsed = false;
  bool _isTorchOn = false;
  bool _isFrontCamera = false;
  bool _isStartingCamera = false;
  bool _hasCameraPermission = true;
  double _posZoomScale = 0.0;
  String? _cameraErrorMessage;
  String? _recentScanBanner;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initPosCamera();
      });
    }
  }

  @override
  void didUpdateWidget(covariant POSScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        if (!_isCameraCollapsed) {
          _startCameraSafely();
        }
      } else {
        _stopCameraSafely();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerTimer?.cancel();
    _disposePosCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_posCameraController == null) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopCameraSafely();
    } else if (state == AppLifecycleState.resumed && widget.isActive && !_isCameraCollapsed) {
      _startCameraSafely();
    }
  }

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

  Future<void> _setPosZoom(double scale) async {
    setState(() => _posZoomScale = scale);
    await _posCameraController?.setZoomScale(scale);
  }

  Future<void> _initPosCamera() async {
    _posCameraController ??= _createController();
    await _startCameraSafely();
  }

  Future<void> _startCameraSafely() async {
    if (_isStartingCamera || !mounted || !widget.isActive || _isCameraCollapsed) return;
    _isStartingCamera = true;

    try {
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }

      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _hasCameraPermission = false;
            _cameraErrorMessage = 'يرجى منح إذن استخدام الكاميرا للمسح المباشر';
          });
        }
        return;
      }

      _posCameraController ??= _createController();

      if (!_posCameraController!.value.isRunning) {
        await _posCameraController!.start();
      }

      if (mounted) {
        setState(() {
          _hasCameraPermission = true;
          _cameraErrorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cameraErrorMessage = 'تعذر تشغيل الكاميرا، اضغط للمحاولة';
        });
      }
    } finally {
      _isStartingCamera = false;
    }
  }

  Future<void> _stopCameraSafely() async {
    if (_posCameraController != null) {
      try {
        if (_posCameraController!.value.isRunning) {
          await _posCameraController!.stop();
        }
      } catch (_) {}
    }
  }

  void _disposePosCamera() {
    try {
      _posCameraController?.stop();
    } catch (_) {}
    try {
      _posCameraController?.dispose();
    } catch (_) {}
    _posCameraController = null;
  }

  void _onPosBarcodeDetected(BarcodeCapture capture) async {
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;

    final pos = Provider.of<POSProvider>(context, listen: false);
    final product = await pos.handleBarcodeScanned(raw);

    if (product != null && mounted) {
      HapticFeedback.lightImpact();
      setState(() {
        if (product.costPrice > 0) {
          _recentScanBanner = '${product.name} • بيع: ${product.retailPrice.round()} دج (شراء: ${product.costPrice.round()} دج)';
        } else {
          _recentScanBanner = '${product.name} • بيع: ${CurrencyFormatter.format(product.retailPrice)}';
        }
      });
      _bannerTimer?.cancel();
      _bannerTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _recentScanBanner = null);
        }
      });

      // If product has 0 price or is unregistered placeholder, prompt pricing dialog
      if (product.retailPrice <= 0 || product.name.startsWith('منتج غير مسجل')) {
        _showSetPriceDialog(product);
      }
    }
  }

  void _openBarcodeScanner({bool isMultiScan = false}) async {
    await _stopCameraSafely();
    if (!mounted) return;
    final pos = Provider.of<POSProvider>(context, listen: false);
    await BarcodeScannerScreen.open(context, isMultiScan: isMultiScan || pos.isMultiScan);
    if (mounted && widget.isActive && !_isCameraCollapsed) {
      _startCameraSafely();
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
                              separatorBuilder: (context, index) => const Divider(height: 1),
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
                                    'باركود: ${p.barcode} • بيع: ${p.retailPrice.round()} دج • شراء: ${p.costPrice.round()} دج',
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryIndigo.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_shopping_cart, color: AppColors.primaryIndigo, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('سلعة متفرقة / بدون باركود', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text('إضافة سريعة لسلعة مباشرة للسلة', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'اسم السلعة (خبز، خضر، ميزان...)',
                  hintText: 'مثال: خبز تقليدي أو خضر',
                  prefixIcon: const Icon(Icons.label_outline, color: AppColors.primaryIndigo),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'السعر الإفرادي (دج) *',
                        hintText: 'مثال: 50',
                        prefixIcon: const Icon(Icons.payments_outlined, color: AppColors.retailColor),
                        filled: true,
                        fillColor: Colors.grey.withOpacity(0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'الكمية',
                        prefixIcon: const Icon(Icons.numbers_outlined),
                        filled: true,
                        fillColor: Colors.grey.withOpacity(0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // أسعار سريعة شائعة
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Text('سعر سريع: ', style: TextStyle(fontSize: 12, color: Colors.grey, height: 2.2)),
                  ActionChip(
                    label: const Text('10 دج'),
                    onPressed: () => priceCtrl.text = '10',
                  ),
                  ActionChip(
                    label: const Text('20 دج'),
                    onPressed: () => priceCtrl.text = '20',
                  ),
                  ActionChip(
                    label: const Text('50 دج'),
                    onPressed: () => priceCtrl.text = '50',
                  ),
                  ActionChip(
                    label: const Text('100 دج'),
                    onPressed: () => priceCtrl.text = '100',
                  ),
                  ActionChip(
                    label: const Text('200 دج'),
                    onPressed: () => priceCtrl.text = '200',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
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
                        backgroundColor: AppColors.primaryIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        final name = nameCtrl.text.trim().isEmpty ? 'سلعة متفرقة' : nameCtrl.text.trim();
                        final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                        final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;

                        if (price <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('⚠️ يرجى إدخال سعر صحيح أكبر من 0 دج'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                          return;
                        }

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
                      icon: const Icon(Icons.check, size: 20),
                      label: const Text('إضافة للسلة ➔', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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

  Future<void> _showSetPriceDialog(Product product) async {
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
                          color: AppColors.primaryIndigo.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.price_change_outlined, color: AppColors.primaryIndigo, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'باركود: ${product.barcode}',
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'هذه السلعة جديدة أو سعرها 0 دج، حدد سعر البيع والشراء لحفظها وإضافتها للسلة',
                            style: TextStyle(color: Colors.white, fontSize: 11),
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
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      labelText: 'سعر بيع التجزئة (دج) *',
                      labelStyle: const TextStyle(color: AppColors.primaryLight),
                      suffixText: 'دج',
                      suffixStyle: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: costCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      labelText: 'سعر الشراء / التكلفة (سعر اللي شراه به) - اختياري',
                      labelStyle: const TextStyle(color: Colors.white60),
                      hintText: 'سعر جملة الشراء من المورّد',
                      hintStyle: const TextStyle(color: Colors.white30),
                      suffixText: 'دج',
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                                  _recentScanBanner = '${updatedProduct.name} • بيع: ${retailVal.round()} دج (شراء: ${costVal.round()} دج)';
                                } else {
                                  _recentScanBanner = '${updatedProduct.name} • بيع: ${retailVal.round()} دج';
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
  }

  Widget _buildEmbeddedCamera(bool isDark) {
    if (_isCameraCollapsed) {
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primaryIndigo.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () {
                setState(() => _isCameraCollapsed = false);
                _startCameraSafely();
              },
              borderRadius: BorderRadius.circular(10),
              child: const Row(
                children: [
                  Icon(Icons.camera_alt_outlined, color: AppColors.primaryIndigo, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'فتح الكاميرا للمسح المباشر 📷',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryIndigo),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.primaryIndigo),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _openBarcodeScanner(isMultiScan: true),
              icon: const Icon(Icons.crop_free, size: 15),
              label: const Text('مسح متعدد ⚡', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryIndigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      height: 195,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryIndigo.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryIndigo.withOpacity(0.2),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Live Camera Preview
            if (_posCameraController != null && _hasCameraPermission)
              LayoutBuilder(
                builder: (context, constraints) {
                  final scanRect = Rect.fromCenter(
                    center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
                    width: 230,
                    height: 110,
                  );
                  return MobileScanner(
                    controller: _posCameraController!,
                    scanWindow: scanRect,
                    onDetect: _onPosBarcodeDetected,
                    errorBuilder: (context, error, child) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 36),
                              const SizedBox(height: 8),
                              Text(
                                _cameraErrorMessage ?? 'تعذر تشغيل الكاميرا',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _startCameraSafely,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      _cameraErrorMessage ?? 'الكاميرا متوقفة مؤقتاً',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _startCameraSafely,
                      child: const Text('تشغيل'),
                    ),
                  ],
                ),
              ),

            // 2. Aim guide & overlay
            Center(
              child: Container(
                width: 220,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accent.withOpacity(0.55), width: 1.5),
                ),
              ),
            ),

            // 3. Top Controls Overlay
            Positioned(
              top: 8,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Multi-scan pill
                  InkWell(
                    onTap: () => _openBarcodeScanner(isMultiScan: true),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accent, width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.crop_free, color: AppColors.accent, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'مسح متعدد ⚡',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Actions: Zoom, Torch, Switch camera, Minimize
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCameraMiniBtn(
                        child: Text(
                          _posZoomScale == 0.0 ? '1x' : (_posZoomScale == 0.2 ? '1.5x' : '2x'),
                          style: TextStyle(
                            color: _posZoomScale > 0.0 ? AppColors.accent : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        color: _posZoomScale > 0.0 ? AppColors.accent : Colors.white,
                        tooltip: 'تقريب الكاميرا',
                        onTap: () {
                          double nextZoom;
                          if (_posZoomScale == 0.0) {
                            nextZoom = 0.2;
                          } else if (_posZoomScale == 0.2) {
                            nextZoom = 0.4;
                          } else {
                            nextZoom = 0.0;
                          }
                          _setPosZoom(nextZoom);
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildCameraMiniBtn(
                        icon: _isTorchOn ? Icons.flash_on : Icons.flash_off,
                        color: _isTorchOn ? Colors.amber : Colors.white,
                        onTap: () async {
                          await _posCameraController?.toggleTorch();
                          setState(() => _isTorchOn = !_isTorchOn);
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildCameraMiniBtn(
                        icon: Icons.flip_camera_android,
                        color: Colors.white,
                        onTap: () async {
                          await _posCameraController?.switchCamera();
                          setState(() => _isFrontCamera = !_isFrontCamera);
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildCameraMiniBtn(
                        icon: Icons.keyboard_arrow_up,
                        color: Colors.white,
                        tooltip: 'تصغير الكاميرا',
                        onTap: () {
                          _stopCameraSafely();
                          setState(() => _isCameraCollapsed = true);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 4. Bottom Guidance Prompt
            Positioned(
              bottom: 6,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'امسح الباركود لإضافته فورياً للسلة ⚡',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

            // 5. Success Flash Banner
            if (_recentScanBanner != null)
              Positioned(
                top: 50,
                left: 16,
                right: 16,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentDark.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _recentScanBanner!,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraMiniBtn({
    IconData? icon,
    Widget? child,
    required Color color,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.65),
          shape: BoxShape.circle,
        ),
        child: child ?? Icon(icon, color: color, size: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = Provider.of<POSProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, size: 26),
            tooltip: 'القائمة الرئيسية',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryIndigo.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.point_of_sale, color: AppColors.primaryIndigo, size: 20),
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
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppColors.primaryIndigo),
            tooltip: 'مسح باركود بالكاميرا',
            onPressed: _openBarcodeScanner,
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.primaryIndigo),
            tooltip: 'بحث في 42,000 منتج',
            onPressed: _showManualSearchDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Embedded Smart Camera Viewport
          _buildEmbeddedCamera(isDark),

          // 2. Cart Status Bar & Quick Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryIndigo.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_cart_outlined, color: AppColors.primaryIndigo, size: 15),
                          const SizedBox(width: 4),
                          Text(
                            'السلة (${pos.cart.length} أصناف • ${pos.totalItemsCount} قطع)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryIndigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Manual search button
                    TextButton.icon(
                      onPressed: _showManualSearchDialog,
                      icon: const Icon(Icons.search, size: 15),
                      label: const Text('بحث بالاسم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryIndigo,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Clear cart if not empty
                    if (pos.cart.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.danger, size: 20),
                        tooltip: 'تفريغ السلة',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('تفريغ السلة؟'),
                              content: const Text('هل أنت متأكد من مسح جميع المنتجات من السلة؟'),
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
              ],
            ),
          ),

          // Quick Action Ribbon: Price Type & Common Quick Items
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

          // Main Cart List
          Expanded(
            child: pos.cart.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              color: AppColors.primaryIndigo.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.qr_code_scanner, size: 44, color: AppColors.primaryIndigo),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'سلة المشتريات فارغة',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'اضغط زر الباركود في الوسط أو الزر أعلاه للمسح الفوري',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: _openBarcodeScanner,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('تشغيل الماسح بالكاميرا'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryIndigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            ),
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
