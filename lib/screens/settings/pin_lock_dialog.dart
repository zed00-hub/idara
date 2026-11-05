import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/app_settings_provider.dart';

class PinLockDialog extends StatefulWidget {
  final String title;

  const PinLockDialog({super.key, this.title = 'أدخل رمز PIN للمتابعة'});

  static Future<bool> verify(BuildContext context, {String? title, required bool isProtected}) async {
    final settings = Provider.of<AppSettingsProvider>(context, listen: false);
    if (!settings.isPinEnabled || !isProtected) {
      return true; // Not protected or no PIN configured
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PinLockDialog(title: title ?? 'أدخل رمز PIN للمتابعة'),
    );
    return result ?? false;
  }

  @override
  State<PinLockDialog> createState() => _PinLockDialogState();
}

class _PinLockDialogState extends State<PinLockDialog> {
  final TextEditingController _pinController = TextEditingController();
  String _errorMessage = '';

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _checkPin() {
    final settings = Provider.of<AppSettingsProvider>(context, listen: false);
    if (settings.verifyPin(_pinController.text.trim())) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorMessage = 'رمز PIN غير صحيح!';
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 16))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinController,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: '••••',
              counterText: '',
            ),
            onSubmitted: (_) => _checkPin(),
          ),
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _checkPin,
          child: const Text('دخول'),
        ),
      ],
    );
  }
}
