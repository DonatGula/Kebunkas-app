import 'package:flutter/material.dart';

class AppTheme {
  final String name;
  final Color primary;
  final Color secondary;
  final List<Color> gradient;

  AppTheme({
    required this.name,
    required this.primary,
    required this.secondary,
    required this.gradient,
  });
}

final List<AppTheme> allThemes = [
  AppTheme(
    name: "Orange Juice",
    primary: const Color(0xFFF9A825),
    secondary: const Color(0xFFE67E22),
    gradient: [const Color(0xFFFFD571), const Color(0xFFF9A825)],
  ),
  AppTheme(
    name: "Green Nature",
    primary: const Color(0xFF2D7D5D),
    secondary: const Color(0xFF1B5E20),
    gradient: [const Color(0xFF81C784), const Color(0xFF2D7D5D)],
  ),
  AppTheme(
    name: "Earth Tone",
    primary: const Color(0xFF8D6E63),
    secondary: const Color(0xFF5D4037),
    gradient: [const Color(0xFFD7CCC8), const Color(0xFF8D6E63)],
  ),
  AppTheme(
    name: "Ocean Blue",
    primary: const Color(0xFF1976D2),
    secondary: const Color(0xFF0D47A1),
    gradient: [const Color(0xFF64B5F6), const Color(0xFF1976D2)],
  ),

];