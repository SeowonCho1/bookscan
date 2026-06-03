import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';

class PdfExportScreen extends ConsumerStatefulWidget {
  const PdfExportScreen({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<PdfExportScreen> createState() => _PdfExportScreenState();
}

class _PdfExportScreenState extends ConsumerState<PdfExportScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  bool _titleSeeded = false;

  @override
  void didUpdateWidget(PdfExportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId) {
      _titleSeeded = false;
    }
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(documentRepositoryProvider).savePdf(
            widget.documentId,
            _controller.text,
          );
      ref.invalidate(documentDetailProvider(widget.documentId));
      await ref.read(documentsProvider.notifier).reload();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('PDF를 생성했습니다.')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('PDF 생성 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docAsync = ref.watch(documentDetailProvider(widget.documentId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('PDF 저장')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: docAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('오류: $e'),
          data: (doc) {
            if (doc == null) {
              return const Text('문서를 찾을 수 없습니다.');
            }
            if (!_titleSeeded) {
              _titleSeeded = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _controller.text = doc.title;
              });
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '문서명',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '예: 경제학 개론 1장',
                  ),
                ),
                const SizedBox(height: 16),
                Text('총 ${doc.pageCount}페이지가 PDF에 포함됩니다.'),
                const Spacer(),
                FilledButton(
                  onPressed: _busy ? null : _generate,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('PDF 생성'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
