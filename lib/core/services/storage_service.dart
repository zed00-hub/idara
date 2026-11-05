import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyOnboarding = 'onboarding_done';
  static const String _keyLanguage = 'selected_language';
  static const String _keyDarkMode = 'is_dark_mode';
  static const String _keyStoreName = 'store_name';
  static const String _keyStorePhone = 'store_phone';
  static const String _keyStoreAddress = 'store_address';
  static const String _keyPinCode = 'security_pin';
  static const String _keyProtectReports = 'protect_reports';
  static const String _keyProtectSettings = 'protect_settings';
  static const String _keyProtectPrices = 'protect_prices';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static bool isOnboardingCompleted() => _prefs?.getBool(_keyOnboarding) ?? false;
  static Future<void> setOnboardingCompleted(bool value) async =>
      await _prefs?.setBool(_keyOnboarding, value);

  static String getLanguage() => _prefs?.getString(_keyLanguage) ?? 'ar';
  static Future<void> setLanguage(String lang) async =>
      await _prefs?.setString(_keyLanguage, lang);

  static bool isDarkMode() => _prefs?.getBool(_keyDarkMode) ?? false;
  static Future<void> setDarkMode(bool value) async =>
      await _prefs?.setBool(_keyDarkMode, value);

  static String getStoreName() => _prefs?.getString(_keyStoreName) ?? 'بقالة النور والبركة';
  static Future<void> setStoreName(String name) async =>
      await _prefs?.setString(_keyStoreName, name);

  static String getStorePhone() => _prefs?.getString(_keyStorePhone) ?? '';
  static Future<void> setStorePhone(String phone) async =>
      await _prefs?.setString(_keyStorePhone, phone);

  static String getStoreAddress() => _prefs?.getString(_keyStoreAddress) ?? '';
  static Future<void> setStoreAddress(String address) async =>
      await _prefs?.setString(_keyStoreAddress, address);

  static String? getPinCode() => _prefs?.getString(_keyPinCode);
  static Future<void> setPinCode(String? pin) async {
    if (pin == null || pin.isEmpty) {
      await _prefs?.remove(_keyPinCode);
    } else {
      await _prefs?.setString(_keyPinCode, pin);
    }
  }

  static bool isPinEnabled() => getPinCode() != null && getPinCode()!.isNotEmpty;

  static bool isReportsProtected() => _prefs?.getBool(_keyProtectReports) ?? true;
  static Future<void> setReportsProtected(bool value) async =>
      await _prefs?.setBool(_keyProtectReports, value);

  static bool isSettingsProtected() => _prefs?.getBool(_keyProtectSettings) ?? true;
  static Future<void> setSettingsProtected(bool value) async =>
      await _prefs?.setBool(_keyProtectSettings, value);

  static bool isPricesProtected() => _prefs?.getBool(_keyProtectPrices) ?? true;
  static Future<void> setPricesProtected(bool value) async =>
      await _prefs?.setBool(_keyProtectPrices, value);
}
