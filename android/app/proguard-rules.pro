# ProGuard / R8 rules for Nadmha POS

# Keep Google ML Kit Barcode Scanning classes
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep Google Play Services vision
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Keep CameraX
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# Keep MobileScanner plugin
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn dev.steenbakker.mobile_scanner.**

# Keep Sqflite & SQLite
-keep class com.tekartik.sqflite.** { *; }
