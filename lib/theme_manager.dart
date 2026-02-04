import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  final List<Map<String, dynamic>> allThemes = [
    // --- DUA TEMA BARU YANG MENARIK ---
    {
      "name": "Midnight Mint",
      "primary": const Color(0xFF00BFA5),
      "gradient": [const Color(0xFF1DE9B6), const Color(0xFF00796B)] // Hijau Toska Neon ke Teal Gelap
    },
    {
      "name": "Sunset Berry",
      "primary": const Color(0xFF6A1B9A),
      "gradient": [const Color(0xFFFF8A65), const Color(0xFF8E24AA)] // Peach ke Ungu Berry (Sangat Modern)
    },

    // --- TEMA LAMA YANG DIPERBAIKI (LEBIH MENARIK) ---
    {
      "name": "Citrus Gold", // Sebelumnya Orange
      "primary": const Color(0xFFFB8C00),
      "gradient": [const Color(0xFFFFE082), const Color(0xFFF57C00)]
    },
    {
      "name": "Forest Pro", // Sebelumnya Green
      "primary": const Color(0xFF1B5E20),
      "gradient": [const Color(0xFF43A047), const Color(0xFF1B5E20)]
    },
    {
      "name": "Deep Ocean", // Sebelumnya Ocean
      "primary": const Color(0xFF0D47A1),
      "gradient": [const Color(0xFF42A5F5), const Color(0xFF1565C0)]
    },
    {
      "name": "Royal Purple", // Sebelumnya Purple
      "primary": const Color(0xFF673AB7),
      "gradient": [const Color(0xFFD1C4E9), const Color(0xFF512DA8)]
    },
    {
      "name": "Soft Rose", // Sebelumnya Rose
      "primary": const Color(0xFFD81B60),
      "gradient": [const Color(0xFFF48FB1), const Color(0xFFAD1457)]
    },
    {
      "name": "Luxury Teal", // Sebelumnya Teal
      "primary": const Color(0xFF00695C),
      "gradient": [const Color(0xFF4DB6AC), const Color(0xFF004D40)]
    },
    {
      "name": "Champagne", // Sebelumnya Dark Gold
      "primary": const Color(0xFFB8860B),
      "gradient": [const Color(0xFFF7E7CE), const Color(0xFF8B4513)]
    },
    {
      "name": "Coffee Earth", // Sebelumnya Earth
      "primary": const Color(0xFF5D4037),
      "gradient": [const Color(0xFFA1887F), const Color(0xFF3E2723)]
    },
    {
      "name": "Sakura", // Sebelumnya Pink
      "primary": const Color(0xFFF06292),
      "gradient": [const Color(0xFFFCE4EC), const Color(0xFFE91E63)]
    },
    {
      "name": "Steel Grey", // Sebelumnya Grey
      "primary": const Color(0xFF455A64),
      "gradient": [const Color(0xFFB0BEC5), const Color(0xFF263238)]
    },
  ];

  int themeIndex = 0;
  bool isDarkMode = false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    themeIndex = prefs.getInt('theme_index') ?? 0;
    isDarkMode = prefs.getBool('is_dark_mode') ?? false;
  }

  Future<void> saveTheme(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_index', index);
    themeIndex = index;
  }

  Future<void> saveDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
    isDarkMode = value;
  }

  // Getters
  Color get primary => allThemes[themeIndex]['primary'];
  List<Color> get gradient => allThemes[themeIndex]['gradient'];
  Color get bgColor => isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
  Color get cardColor => isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get textColor => isDarkMode ? Colors.white : Colors.black87;
  Color get subTextColor => isDarkMode ? Colors.white70 : Colors.black54;
}