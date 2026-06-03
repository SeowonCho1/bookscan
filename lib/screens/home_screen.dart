import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../config/app_constants.dart';
import '../models/document_record.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _startScan(BuildContext context, WidgetRef ref) async {
    final limit = ref.read(scanPageLimitProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final paths = await ref.read(scanServiceProvider).scan(maxPages: limit);
      if (!context.mounted) return;
      if (paths == null || paths.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('스캔이 취소되었거나 결과가 없습니다.')),
        );
        return;
      }
      final doc = await ref
          .read(documentRepositoryProvider)
          .createDocumentFromScanPaths(paths);
      await ref.read(documentsProvider.notifier).reload();
      ref.invalidate(documentDetailProvider(doc.documentId));
      ref.invalidate(documentPagesProvider(doc.documentId));
      ref.invalidate(documentOcrTextProvider(doc.documentId));
      if (!context.mounted) return;
      context.push('/document/${doc.documentId}/pages');
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('스캔 실패: $e')),
      );
    }
  }

  Future<void> _deleteDocument(
    BuildContext context,
    WidgetRef ref,
    DocumentRecord d,
  ) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('문서 삭제'),
            content: const Text('이 문서와 모든 페이지·PDF를 삭제할까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('삭제'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !context.mounted) return;
    await ref.read(documentRepositoryProvider).deleteDocument(d.documentId);
    await ref.read(documentsProvider.notifier).reload();
  }

  Widget _ocrChip(String ocrStatus) {
    late final String label;
    late final Color bg;
    late final Color fg;
    switch (ocrStatus) {
      case 'DONE':
        label = 'OCR 완료';
        bg = AppColors.sage;
        fg = AppColors.forest;
      case 'FAILED':
        label = 'OCR 실패';
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
      case 'PROCESSING':
        label = 'OCR 처리 중';
        bg = AppColors.sageMuted;
        fg = AppColors.forestDark;
      default:
        label = 'OCR 대기';
        bg = Colors.white;
        fg = const Color(0xFF6B7F72);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineSoft.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsProvider);
    final plan = ref.watch(userPlanProvider);
    final limit = ref.watch(scanPageLimitProvider);
    final dateFmt = DateFormat('yyyy.MM.dd');
    final search = ref.watch(homeSearchQueryProvider);

    return Scaffold(
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: AppColors.sage),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    '북스캔',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.forestDark,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('설정'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/settings');
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: const Text('북스캔'),
        actions: [
          IconButton(
            tooltip: '알림',
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('알림은 추후 제공 예정입니다.')),
              );
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SearchBar(
              hintText: '문서 검색',
              leading: const Icon(Icons.search, color: AppColors.forest),
              trailing: [
                if (search.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      ref.read(homeSearchQueryProvider.notifier).setQuery('');
                    },
                  ),
              ],
              onChanged: (v) {
                ref.read(homeSearchQueryProvider.notifier).setQuery(v);
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.sage,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.sageMuted),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      plan == UserPlan.free
                          ? Icons.workspace_premium_outlined
                          : Icons.verified_outlined,
                      color: AppColors.forest,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        plan == UserPlan.free
                            ? '무료 모드 · 한 스캔 세션당 연속 촬영 최대 $limit페이지'
                            : '승인 모드 · 연속 촬영 제한 해제 · OCR 사용 가능',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.forestDark,
                              height: 1.35,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: docsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('불러오기 오류: $e')),
              data: (docs) {
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            size: 64,
                            color: AppColors.outlineSoft,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            search.trim().isEmpty
                                ? '저장된 문서가 없습니다.\n아래 버튼으로 책이나 문서를 스캔해 보세요.'
                                : '검색 결과가 없습니다.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final cover = d.coverImagePath;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => context.push('/document/${d.documentId}'),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 52,
                                    height: 72,
                                    child: cover != null &&
                                            File(cover).existsSync()
                                        ? Image.file(
                                            File(cover),
                                            fit: BoxFit.cover,
                                          )
                                        : ColoredBox(
                                            color: AppColors.sageMuted,
                                            child: Icon(
                                              Icons.menu_book_rounded,
                                              color: AppColors.forest
                                                  .withValues(alpha: 0.45),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.forestDark,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${dateFmt.format(d.createdAt)} · ${d.pageCount}페이지'
                                        '${d.hasPdf ? '' : ' · PDF 없음'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFF6B7F72),
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      _ocrChip(d.ocrStatus),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.more_vert_rounded),
                                  color: AppColors.forestDark,
                                  onPressed: () async {
                                    final action = await showModalBottomSheet<
                                        String>(
                                      context: context,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(16),
                                        ),
                                      ),
                                      builder: (ctx) => SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ListTile(
                                              leading: const Icon(
                                                Icons.delete_outline,
                                              ),
                                              title: const Text('삭제'),
                                              onTap: () =>
                                                  Navigator.pop(ctx, 'delete'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                    if (action == 'delete' &&
                                        context.mounted) {
                                      await _deleteDocument(
                                        context,
                                        ref,
                                        d,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startScan(context, ref),
        icon: const Icon(Icons.photo_camera_outlined),
        label: const Text('새 스캔'),
      ),
    );
  }
}
