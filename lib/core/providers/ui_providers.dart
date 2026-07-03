import 'package:flutter_riverpod/flutter_riverpod.dart';

// Seeded from SharedPreferences in main.dart before runApp
final mobileOnboardingSeenProvider = StateProvider<bool>((ref) => false);
