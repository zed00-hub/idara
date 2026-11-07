import 'package:flutter/material.dart';

class AppColors {
  // Brand & Accent Colors (Modern Fintech / POS Palette)
  static const Color primary = Color(0xFF0F172A); // Midnight Slate
  static const Color primaryIndigo = Color(0xFF4F46E5); // Vibrant Indigo
  static const Color primaryLight = Color(0xFF3B82F6); // Electric Blue
  static const Color primaryDark = Color(0xFF020617); // Obsidian

  static const Color accent = Color(0xFF10B981); // Emerald Mint
  static const Color accentLight = Color(0xFFD1FAE5);
  static const Color accentDark = Color(0xFF059669);

  // Status & Financial Indicators
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Light Theme Neutrals
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Dark Theme Neutrals
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color darkSurface = Color(0xFF161F30);
  static const Color darkBorder = Color(0xFF26334A);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // POS & Retail Specific
  static const Color cashColor = Color(0xFF10B981);
  static const Color creditColor = Color(0xFFF97316);
  static const Color partialColor = Color(0xFF0EA5E9);
  static const Color wholesaleColor = Color(0xFF8B5CF6);
  static const Color retailColor = Color(0xFF3B82F6);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient scannerReticleGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF34D399), Color(0xFF10B981)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
