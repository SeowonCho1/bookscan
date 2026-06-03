import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_constants.dart';
import '../data/document_repository.dart';
import '../database/app_database.dart';
import '../models/document_record.dart';
import '../models/scan_page_record.dart';
import '../services/image_processing_service.dart';
import '../services/ocr_service.dart';
import '../services/scan_service.dart';
import '../services/storage_service.dart';

final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('main에서 override 하세요'),
);

final storageServiceProvider = Provider((ref) => StorageService());

final imageProcessingServiceProvider = Provider(
  (ref) => ImageProcessingService(),
);

final ocrServiceProvider = Provider((ref) => OcrService());

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(storageServiceProvider),
    ref.watch(imageProcessingServiceProvider),
    ref.watch(ocrServiceProvider),
  );
});

final scanServiceProvider = Provider((ref) => ScanService());

/// 홈 검색어 (문서명 + OCR).
final homeSearchQueryProvider =
    NotifierProvider<HomeSearchNotifier, String>(HomeSearchNotifier.new);

class HomeSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
}

/// 서버 연동 전: 설정의 «개발용 승인»으로 승인 모드를 시뮬레이션합니다.
final simulatedApprovedProvider =
    AsyncNotifierProvider<SimulatedApprovedNotifier, bool>(
  SimulatedApprovedNotifier.new,
);

class SimulatedApprovedNotifier extends AsyncNotifier<bool> {
  static const _prefsKey = 'dev_simulated_plan_approved';

  @override
  Future<bool> build() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_prefsKey) ?? false;
  }

  Future<void> setApproved(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_prefsKey, value);
    state = AsyncData(value);
  }
}

final userPlanProvider = Provider<UserPlan>((ref) {
  return ref.watch(simulatedApprovedProvider).maybeWhen(
        data: (v) => v ? UserPlan.approved : UserPlan.free,
        orElse: () => UserPlan.free,
      );
});

final scanPageLimitProvider = Provider<int>((ref) {
  switch (ref.watch(userPlanProvider)) {
    case UserPlan.approved:
      return 100;
    case UserPlan.free:
      return kFreeContinuousScanLimit;
  }
});

final documentsProvider =
    AsyncNotifierProvider<DocumentsNotifier, List<DocumentRecord>>(
  DocumentsNotifier.new,
);

class DocumentsNotifier extends AsyncNotifier<List<DocumentRecord>> {
  @override
  Future<List<DocumentRecord>> build() async {
    final q = ref.watch(homeSearchQueryProvider);
    final repo = ref.read(documentRepositoryProvider);
    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      return repo.listDocuments();
    }
    return repo.searchDocuments(trimmed);
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final q = ref.read(homeSearchQueryProvider).trim();
      final repo = ref.read(documentRepositoryProvider);
      if (q.isEmpty) return repo.listDocuments();
      return repo.searchDocuments(q);
    });
  }
}

final documentDetailProvider =
    FutureProvider.family<DocumentRecord?, String>((ref, documentId) {
  return ref.watch(documentRepositoryProvider).getDocument(documentId);
});

final documentPagesProvider =
    FutureProvider.family<List<ScanPageRecord>, String>((ref, documentId) {
  return ref.watch(documentRepositoryProvider).listPages(documentId);
});

final documentOcrTextProvider =
    FutureProvider.family<String, String>((ref, documentId) {
  return ref.watch(documentRepositoryProvider).combinedOcrText(documentId);
});
