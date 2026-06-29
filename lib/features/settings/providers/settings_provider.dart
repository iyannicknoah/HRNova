import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/company_settings_model.dart';

final settingsProvider = StreamProvider<CompanySettings?>((ref) {
  final companyId = ref.watch(companyIdProvider);
  if (companyId == null) {
    return Stream.value(null);
  }
  
  return FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
      .collection('companies')
      .doc(companyId)
      .collection('settings')
      .doc('config')
      .snapshots()
      .map((snapshot) {
        if (!snapshot.exists) {
          return const CompanySettings();
        }
        return CompanySettings.fromFirestore(snapshot);
      });
});

class SettingsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  SettingsNotifier(this._ref) : super(const AsyncData(null));

  Future<void> updateSettings(CompanySettings settings) async {
    final companyId = _ref.read(companyIdProvider);
    if (companyId == null) {
      state = AsyncValue.error('No authenticated company found.', StackTrace.current);
      return;
    }

    state = const AsyncLoading();
    try {
      await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
          .collection('companies')
          .doc(companyId)
          .collection('settings')
          .doc('config')
          .set(settings.toFirestore(), SetOptions(merge: true));
      
      state = const AsyncData(null);
    } catch (e, stack) {
      state = AsyncValue.error('Failed to save settings: $e', stack);
    }
  }
}

final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, AsyncValue<void>>((ref) {
  return SettingsNotifier(ref);
});
