import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';

class PagesEditorScreen extends ConsumerStatefulWidget {
  const PagesEditorScreen({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<PagesEditorScreen> createState() => _PagesEditorScreenState();
}

class _PagesEditorScreenState extends ConsumerState<PagesEditorScreen> {
  List<String>? _pageOrder;

  Future<void> _appendPages() async {
    final limit = ref.read(scanPageLimitProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final paths = await ref.read(scanServiceProvider).scan(maxPages: limit);
      if (!mounted) return;
      if (paths == null || paths.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('추가 스캔이 취소되었습니다.')),
        );
        return;
      }
      await ref
          .read(documentRepositoryProvider)
          .appendScannedPages(widget.documentId, paths);
      ref.invalidate(documentPagesProvider(widget.documentId));
      ref.invalidate(documentDetailProvider(widget.documentId));
      ref.invalidate(documentOcrTextProvider(widget.documentId));
      await ref.read(documentsProvider.notifier).reload();
      setState(() => _pageOrder = null);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('추가 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pagesAsync = ref.watch(documentPagesProvider(widget.documentId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('페이지'),
        actions: [
          TextButton(
            onPressed: () => context.push('/document/${widget.documentId}/export'),
            child: const Text('PDF'),
          ),
        ],
      ),
      body: pagesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (pages) {
          if (pages.isEmpty) {
            return const Center(child: Text('페이지가 없습니다.'));
          }
          final ids = pages.map((p) => p.pageId).toList();
          final idSet = ids.toSet();
          if (_pageOrder == null ||
              _pageOrder!.length != ids.length ||
              !_pageOrder!.every(idSet.contains)) {
            _pageOrder = List<String>.from(ids);
          }
          final order = _pageOrder!;

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: order.length,
            onReorder: (oldI, newI) async {
              setState(() {
                if (newI > oldI) newI -= 1;
                final id = order.removeAt(oldI);
                order.insert(newI, id);
              });
              await ref
                  .read(documentRepositoryProvider)
                  .reorderPages(widget.documentId, List<String>.from(order));
              ref.invalidate(documentPagesProvider(widget.documentId));
              ref.invalidate(documentDetailProvider(widget.documentId));
            },
            itemBuilder: (context, index) {
              final pageId = order[index];
              final page = pages.firstWhere((p) => p.pageId == pageId);
              return Card(
                key: ValueKey(pageId),
                child: ListTile(
                  leading: SizedBox(
                    width: 56,
                    height: 72,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(page.processedImagePath),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  title: Text('페이지 ${index + 1}'),
                  subtitle: Text(page.filterType.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => context.push(
                          '/document/${widget.documentId}/page/${page.pageId}/edit',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('페이지 삭제'),
                              content: const Text('이 페이지를 삭제할까요?'),
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
                          );
                          if (ok != true || !context.mounted) return;
                          await ref
                              .read(documentRepositoryProvider)
                              .deletePage(widget.documentId, page.pageId);
                          ref.invalidate(documentPagesProvider(widget.documentId));
                          ref.invalidate(documentDetailProvider(widget.documentId));
                          await ref.read(documentsProvider.notifier).reload();
                          setState(() => _pageOrder = null);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _appendPages,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('페이지 추가'),
      ),
    );
  }
}
