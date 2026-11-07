import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/audio_service.dart';
import '../../models/product.dart';
import '../../providers/pos_provider.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final bool isMultiScanInitial;

  const BarcodeScannerScreen({
    super.key,
    this.isMultiScanInitial = false,
  });

  static Future<Product?> open(BuildContext context, {bool isMultiScan = false}) async {
    // 1. Request Camera Permission explicitly
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.camera_alt, color: AppColors.primaryIndigo),
                SizedBox(width: 8),
                Text('إذن الكاميرا مطلوب'),
              ],
            ),
            content: const Text(
              'يحتاج تطبيق نظمها إلى إذن الكاميرا لمسح باركود المنتجات وتصوير فواتير الموردين.\nيرجى منح الإذن للمتابعة.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  openAppSettings();
                },
                child: const Text('فتح إعدادات الهاتف'),
              ),
            ],
          ),
        );
      }
      return null;
    }

    if (!context.mounted) return null;
    return await Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(isMultiScanInitial: isMultiScan),
      ),
    );
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
  late bool _isMultiScan;
  int _scannedCount = 0;
  String? _lastScannedText;
  final TextEditingController _manualBarcodeCtrl = TextEditingController();

  MobileScannerController _createController() {
    return MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
      returnImage: false,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isMultiScan = widget.isMultiScanInitial;
    _controller = _createController();

    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _laserAnimController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _controller.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _controller.stop();
        break;
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

  void _onDetect(BarcodeCapture capture) async {
    final barcodes = capture.barcodes;
    final pos = Provider.of<POSProvider>(context, listen: false);

    for (final barcode in barcodes) {
      final code = barcode.rawValue?.trim();
      if (code != null && code.isNotEmpty) {
        final product = await pos.handleBarcodeScanned(code);
        if (product != null && mounted) {
          setState(() {
            _scannedCount++;
            _lastScannedText = '${product.name} • ${product.retailPrice.round()} دج';
          });

          AudioService.playScanBeep();

          if (!_isMultiScan) {
            // Single scan mode: Return immediately to POS with the scanned product
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted) {
              Navigator.of(context).pop(product);
            }
            return;
          }
        }
      }
    }
  }

  void _onManualSubmit() async {
    final code = _manualBarcodeCtrl.text.trim();
    if (code.isEmpty) return;

    final pos = Provider.of<POSProvider>(context, listen: false);
    final product = await pos.handleBarcodeScanned(code);
    _manualBarcodeCtrl.clear();

    if (product != null && mounted) {
      setState(() {
        _scannedCount++;
        _lastScannedText = '${product.name} • ${product.retailPrice.round()} دج';
      });
      AudioService.playScanBeep();

      if (!_isMultiScan) {
        Navigator.of(context).pop(product);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fullscreen Live Camera View
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined, color: Colors.amber, size: 54),
                      const SizedBox(height: 14),
                      Text(
                        'تعذر تشغيل الكاميرا (${error.errorCode.name})\n'
                        'يرجى التأكد من إعطاء إذن الكاميرا للتطبيق.',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _controller.stop();
                              await _controller.start();
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                          ),
                          const SizedBox(width: 10),
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

          // High-Tech Animated Viewfinder Frame
          Center(
            child: Container(
              width: 290,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isMultiScan ? AppColors.accent : Colors.white,
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (_isMultiScan ? AppColors.accent : AppColors.primaryIndigo).withOpacity(0.4),
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
                              _isMultiScan ? AppColors.accent : const Color(0xFFEF4444),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isMultiScan ? AppColors.accent : Colors.red).withOpacity(0.9),
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

          // Viewfinder Aim Text
          Positioned(
            top: MediaQuery.of(context).size.height * 0.23,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _isMultiScan ? 'وضع المسح المستمر ⚡ (مرر السلع تباعاً)' : 'وجه الكاميرا نحو باركود السلعة 🎯',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),

          // Top App Bar Controls
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Close button
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

                    // Single / Multi Scan Toggle
                    InkWell(
                      onTap: () => setState(() => _isMultiScan = !_isMultiScan),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isMultiScan ? AppColors.accent : Colors.white24,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isMultiScan ? Icons.bolt : Icons.filter_center_focus,
                              color: _isMultiScan ? AppColors.accent : Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isMultiScan ? 'مسح مستمر ⚡' : 'مسح أحادي 🎯',
                              style: TextStyle(
                                color: _isMultiScan ? AppColors.accent : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Flashlight & Camera Flip
                    Row(
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
                              size: 20,
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
                            child: const Icon(Icons.flip_camera_android, color: Colors.white, size: 20),
                          ),
                          onPressed: () async {
                            await _controller.switchCamera();
                            setState(() => _isFrontCamera = !_isFrontCamera);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Floating Last Scanned Product Confirmation Banner
          if (_lastScannedText != null)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.62,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accentDark.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('✅ تمت الإضافة للسلة:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          Text(
                            _lastScannedText!,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Bar: Manual Barcode Entry + Done Button
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Manual Barcode Input Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.keyboard, color: Colors.white70, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _manualBarcodeCtrl,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
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
                            icon: const Icon(Icons.arrow_forward, color: AppColors.accent),
                            onPressed: _onManualSubmit,
                          ),
                        ],
                      ),
                    ),

                    if (_isMultiScan) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.check, size: 20),
                          label: Text(
                            'تم إنهاء المسح (تم مسح $_scannedCount سلع) ➔',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
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
