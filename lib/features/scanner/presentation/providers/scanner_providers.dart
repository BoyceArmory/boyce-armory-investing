import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/enums.dart';
import '../../../../core/models/scanner_alert_model.dart';
import '../../../../core/providers/auth_state_provider.dart';
import '../../../../core/providers/service_providers.dart';
import '../../data/scanner_repository.dart';

final Provider<ScannerRepository> scannerRepositoryProvider =
    Provider<ScannerRepository>((Ref ref) {
  return ScannerRepository(
    firestoreService: ref.watch(firestoreServiceProvider),
  );
});

/// Public stream across all modes - used by the customers' default "All" tab
/// and by the home screen preview.
final StreamProvider<List<ScannerAlert>> publicScannerAlertsProvider =
    StreamProvider<List<ScannerAlert>>(
  (Ref ref) =>
      ref.watch(scannerRepositoryProvider).streamPublicAlerts(),
);

/// Per-mode public scanner alerts. Family parameter is the ScannerMode.
final StreamProviderFamily<List<ScannerAlert>, ScannerMode>
    publicScannerAlertsByModeProvider =
    StreamProvider.family<List<ScannerAlert>, ScannerMode>(
  (Ref ref, ScannerMode mode) => ref
      .watch(scannerRepositoryProvider)
      .streamPublicAlerts(mode: mode),
);

/// Admin-only stream across all modes - includes weak / WATCH-grade signals.
final StreamProvider<List<ScannerAlert>> adminScannerResultsProvider =
    StreamProvider<List<ScannerAlert>>((Ref ref) {
  final bool isAdmin = ref.watch(isAdminProvider);
  if (!isAdmin) {
    return Stream<List<ScannerAlert>>.value(<ScannerAlert>[]);
  }
  return ref.watch(scannerRepositoryProvider).streamAllResults();
});

/// Admin-only per-mode stream.
final StreamProviderFamily<List<ScannerAlert>, ScannerMode>
    adminScannerResultsByModeProvider =
    StreamProvider.family<List<ScannerAlert>, ScannerMode>(
  (Ref ref, ScannerMode mode) {
    final bool isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return Stream<List<ScannerAlert>>.value(<ScannerAlert>[]);
    }
    return ref.watch(scannerRepositoryProvider).streamAllResults(mode: mode);
  },
);

/// Live stream for a single scanner alert (detail screen).
final StreamProviderFamily<ScannerAlert?, String> scannerAlertByIdProvider =
    StreamProvider.family<ScannerAlert?, String>((Ref ref, String id) {
  return ref.watch(scannerRepositoryProvider).streamById(id);
});
