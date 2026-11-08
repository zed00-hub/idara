import 'package:flutter/material.dart';
import '../core/constants/app_strings.dart';
import '../core/services/storage_service.dart';

class AppSettingsProvider extends ChangeNotifier {
  String _language = 'ar';
  bool _isDarkMode = false;
  String _storeName = 'بقالة النور والبركة';
  String _storePhone = '';
  String _storeAddress = '';
  String? _pinCode;
  bool _protectReports = true;
  bool _protectSettings = true;
  bool _protectPrices = true;

  String get language => _language;
  bool get isDarkMode => _isDarkMode;
  String get storeName => _storeName;
  String get storePhone => _storePhone;
  String get storeAddress => _storeAddress;
  String? get pinCode => _pinCode;
  bool get isPinEnabled => _pinCode != null && _pinCode!.isNotEmpty;
  bool get protectReports => _protectReports;
  bool get protectSettings => _protectSettings;
  bool get protectPrices => _protectPrices;

  String tr(String key) => AppStrings.get(key, lang: _language);

  void loadSettings() {
    _language = StorageService.getLanguage();
    _isDarkMode = StorageService.isDarkMode();
    _storeName = StorageService.getStoreName();
    _storePhone = StorageService.getStorePhone();
    _storeAddress = StorageService.getStoreAddress();
    _pinCode = StorageService.getPinCode();
    _protectReports = StorageService.isReportsProtected();
    _protectSettings = StorageService.isSettingsProtected();
    _protectPrices = StorageService.isPricesProtected();
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    await StorageService.setLanguage(lang);
    notifyListeners();
  }

  Future<void> toggleTheme(bool dark) async {
    _isDarkMode = dark;
    await StorageService.setDarkMode(dark);
    notifyListeners();
  }

  Future<void> updateStoreDetails({
    required String name,
    required String phone,
    required String address,
  }) async {
    _storeName = name;
    _storePhone = phone;
    _storeAddress = address;
    await StorageService.setStoreName(name);
    await StorageService.setStorePhone(phone);
    await StorageService.setStoreAddress(address);
    notifyListeners();
  }

  Future<void> setPin(String? pin) async {
    _pinCode = pin;
    await StorageService.setPinCode(pin);
    notifyListeners();
  }

  Future<void> setProtectionRules({
    required bool reports,
    required bool settings,
    required bool prices,
  }) async {
    _protectReports = reports;
    _protectSettings = settings;
    _protectPrices = prices;
    await StorageService.setReportsProtected(reports);
    await StorageService.setSettingsProtected(settings);
    await StorageService.setPricesProtected(prices);
    notifyListeners();
  }

  bool verifyPin(String enteredPin) {
    return StorageService.verifyPin(enteredPin);
  }
}
