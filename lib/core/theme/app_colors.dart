import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primaryBlue = Color(0xFF4A9EFF);
  static const Color brightBlue = Color(0xFF74CFFF);
  static const Color accentTeal = Color(0xFF43E0C8);
  static const Color darkNavy = Color(0xFF0A1628);
  static const Color backgroundBlue = Color(0xFFF8FAFF);
  static const Color successGreen = Color(0xFF1DB87A);
  static const Color warningAmber = Color(0xFFF5A623);
  static const Color errorRed = Color(0xFFE5534B);
  static const Color textPrimary = Color(0xFF0A1628);
  static const Color textSecondary = Color(0xFF6B7A99);
  static const Color cardBorder = Color(0xFFE8EFF8);
  static const Color lightBlue50 = Color(0xFFF0F6FF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color darkCard = Color(0xFF0D1628);
  static const Color darkBackground = Color(0xFF070E1C);

  // Status badge colors
  static const Color pillGreenBg = Color(0xFFE6F9F1);
  static const Color pillGreenText = Color(0xFF1DB87A);
  static const Color pillAmberBg = Color(0xFFFFF5E6);
  static const Color pillAmberText = Color(0xFFF5A623);
  static const Color pillRedBg = Color(0xFFFEEEED);
  static const Color pillRedText = Color(0xFFE5534B);
  static const Color pillBlueBg = Color(0xFFE8F3FF);
  static const Color pillBlueText = Color(0xFF4A9EFF);
  static const Color pillNavyBg = Color(0xFFECEFF5);
  static const Color pillNavyText = Color(0xFF6B7A99);

  // Avatar gradients — one unique pair per letter A–Z
  static const Map<String, List<Color>> avatarGradients = {
    'A': [Color(0xFF667EEA), Color(0xFF764BA2)],
    'B': [Color(0xFF11998E), Color(0xFF38EF7D)],
    'C': [Color(0xFFF7971E), Color(0xFFFFD200)],
    'D': [Color(0xFFFC5C7D), Color(0xFF6A3093)],
    'E': [Color(0xFF4FACFE), Color(0xFF00F2FE)],
    'F': [Color(0xFF43E97B), Color(0xFF38F9D7)],
    'G': [Color(0xFFFA709A), Color(0xFFFEE140)],
    'H': [Color(0xFF30CFD0), Color(0xFF330867)],
    'I': [Color(0xFFA18CD1), Color(0xFFFBC2EB)],
    'J': [Color(0xFF96FBC4), Color(0xFFF9F586)],
    'K': [Color(0xFFFCCF31), Color(0xFFF55555)],
    'L': [Color(0xFF43CBFF), Color(0xFF9708CC)],
    'M': [Color(0xFF3B41C5), Color(0xFFA981BB)],
    'N': [Color(0xFFFF9A9E), Color(0xFFFF6B35)],
    'O': [Color(0xFF0BA360), Color(0xFF3CBA92)],
    'P': [Color(0xFFDA22FF), Color(0xFF9733EE)],
    'Q': [Color(0xFFF093FB), Color(0xFFF5576C)],
    'R': [Color(0xFF4481EB), Color(0xFF04BEFE)],
    'S': [Color(0xFFFFB347), Color(0xFFFF6347)],
    'T': [Color(0xFF89F7FE), Color(0xFF66A6FF)],
    'U': [Color(0xFF79CBCA), Color(0xFFE684AE)],
    'V': [Color(0xFF9D50BB), Color(0xFF6E48AA)],
    'W': [Color(0xFF56CCF2), Color(0xFF2F80ED)],
    'X': [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
    'Y': [Color(0xFF48C774), Color(0xFF00D1B2)],
    'Z': [Color(0xFF363795), Color(0xFF005C97)],
  };

  static List<Color> gradientForName(String name) {
    if (name.isEmpty) return avatarGradients['A']!;
    final letter = name[0].toUpperCase();
    return avatarGradients[letter] ?? avatarGradients['A']!;
  }
}
