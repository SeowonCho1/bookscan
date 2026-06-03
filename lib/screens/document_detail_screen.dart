import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_constants.dart';
import '../models/document_record.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

String _ocrStatusLabel(String s) {
  switch (s) {
    case 'PROCESSING':
      return 'OCR 처리 중';
    case 'DONE':
      return 'OCR 완료';
    case 'FAILED':
      return 'OCR 실패';
    default:
      return 'OCR 미실행';
  }
}

class _PdfPreview extends StatefulWidget {
  const _PdfPreview({required this.path});

  final String path;

  @override
  State<_PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<_PdfPreview> {
  PdfControllerPinch? _controller;

  @override
  void initState() {
    super.initState();
    _open();
  }

  void _open() {
    _controller?.dispose();
    _controller = PdfControllerPinch(
      document: PdfDocument.openFile(widget.path),
    );
  }

  @override
  void didUpdateWidget(_PdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _open();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return PdfViewPinch(controller: c);
  }
}

class DocumentDetailScreen extends ConsumerStatefulWidget {
  const DocumentDetailScreen({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<DocumentDetailScreen> createState() =>
      _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen> {
  double? _ocrProgress;

  Future<void> _sharePdf(String path, String title) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            path,
            mimeType: 'application/pdf',
            name: '$title.pdf',
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDocument() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('문서 삭제'),
        content: const Text('문서와 모든 페이지·PDF를 삭제할까요?'),
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
    if (ok != true || !mounted) return;
    await ref.read(documentRepositoryProvider).deleteDocument(widget.documentId);
    await ref.read(documentsProvider.notifier).reload();
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _runOcr() async {
    final plan = ref.read(userPlanProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (plan == UserPlan.free) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'OCR은 승인 모드에서 사용할 수 있습니다. 설정에서 «개발용 승인 모드»를 켜 주세요.',
          ),
        ),
      );
      return;
    }
    setState(() => _ocrProgress = 0);
    try {
      await ref.read(documentRepositoryProvider).runOcrForDocument(
            widget.documentId,
            onProgress: (p) {
              if (mounted) setState(() => _ocrProgress = p);
            },
          );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('OCR 처리를 마쳤습니다.')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('OCR 실패: $e')));
    } finally {
      if (mounted) setState(() => _ocrProgress = null);
    }
    ref.invalidate(documentDetailProvider(widget.documentId));
    ref.invalidate(documentPagesProvider(widget.documentId));
    ref.invalidate(documentOcrTextProvider(widget.documentId));
    await ref.read(documentsProvider.notifier).reload();
  }

  Widget _buildOcrProgressSection(DocumentRecord doc) {
    if (_ocrProgress != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _ocrProgress,
              minHeight: 8,
              backgroundColor: AppColors.sageMuted,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'OCR ${(_ocrProgress! * 100).round()}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B7F72),
                ),
          ),
        ],
      );
    }
    final done = doc.ocrStatus == 'DONE';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _ocrStatusLabel(doc.ocrStatus),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.forestDark,
                  ),
            ),
            if (done)
              Text(
                '100%',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.forest,
                      fontWeight: FontWeight.w700,
                    ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: done ? 1 : (doc.ocrStatus == 'PROCESSING' ? null : 0),
            minHeight: 8,
            backgroundColor: AppColors.sageMuted,
            color: AppColors.forest,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final docAsync = ref.watch(documentDetailProvider(widget.documentId));
    final pagesAsync = ref.watch(documentPagesProvider(widget.documentId));
    final ocrAsync = ref.watch(documentOcrTextProvider(widget.documentId));
    final dateFmt = DateFormat('yyyy.MM.dd');

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('문서'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _deleteDocument,
          ),
        ],
      ),
      body: docAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (doc) {
          if (doc == null) {
            return const Center(child: Text('문서를 찾을 수 없습니다.'));
          }

          final p = doc.pdfPath;
          final existingPdf =
              (p != null && File(p).existsSync()) ? p : null;

          return pagesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('페이지 오류: $e')),
            data: (pages) {
              final coverPath =
                  pages.isNotEmpty ? pages.first.processedImagePath : null;
              final snippet = ocrAsync.maybeWhen(
                data: (t) {
                  final s = t.trim();
                  if (s.length <= 200) return s;
                  return '${s.substring(0, 200)}…';
                },
                orElse: () => '',
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 3 / 4,
                              child: coverPath != null &&
                                      File(coverPath).existsSync()
                                  ? Image.file(
                                      File(coverPath),
                                      fit: BoxFit.cover,
                                    )
                                  : ColoredBox(
                                      color: AppColors.sage,
                                      child: Icon(
                                        Icons.menu_book_rounded,
                                        size: 72,
                                        color: AppColors.forest
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            doc.title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.forestDark,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${dateFmt.format(doc.createdAt)} · ${doc.pageCount}페이지',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF6B7F72),
                                ),
                          ),
                          const SizedBox(height: 20),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5EDE7)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: _buildOcrProgressSection(doc),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '페이지',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.forestDark,
                                ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 96,
                            child: pages.isEmpty
                                ? const Center(child: Text('페이지 없음'))
                                : ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: pages.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(width: 8),
                                    itemBuilder: (context, i) {
                                      final pg = pages[i];
                                      return GestureDetector(
                                        onTap: () => context.push(
                                          '/document/${widget.documentId}/page/${pg.pageId}/edit',
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: AspectRatio(
                                            aspectRatio: 3 / 4,
                                            child: Image.file(
                                              File(pg.processedImagePath),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '추출 텍스트 미리보기',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.forestDark,
                                    ),
                              ),
                              if (doc.ocrStatus == 'DONE')
                                TextButton(
                                  onPressed: () => context.push(
                                    '/document/${widget.documentId}/ocr',
                                  ),
                                  child: const Text('전체 보기'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5EDE7)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: ocrAsync.when(
                                loading: () => const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                ),
                                error: (e, _) => Text('텍스트 오류: $e'),
                                data: (full) {
                                  if (full.trim().isEmpty) {
                                    return Text(
                                      doc.ocrStatus == 'DONE'
                                          ? 'OCR 결과가 비어 있습니다.'
                                          : '문서 상세에서 OCR을 실행하면 텍스트가 표시됩니다.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: const Color(0xFF6B7F72),
                                          ),
                                    );
                                  }
                                  return Text(
                                    snippet,
                                    maxLines: 6,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonal(
                                onPressed: () => context.push(
                                  '/document/${widget.documentId}/pages',
                                ),
                                child: const Text('페이지 편집'),
                              ),
                              FilledButton.tonal(
                                onPressed: () => context.push(
                                  '/document/${widget.documentId}/export',
                                ),
                                child: const Text('PDF 생성·갱신'),
                              ),
                              FilledButton.tonal(
                                onPressed:
                                    _ocrProgress != null ? null : _runOcr,
                                child: const Text('OCR 실행'),
                              ),
                            ],
                          ),
                          if (existingPdf != null) ...[
                            const SizedBox(height: 20),
                            Text(
                              'PDF 미리보기',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.forestDark,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 280,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE5EDE7),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: _PdfPreview(path: existingPdf),
                                ),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 20),
                            OutlinedButton.icon(
                              onPressed: () => context.push(
                                '/document/${widget.documentId}/export',
                              ),
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                              label: const Text('PDF 만들기'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (existingPdf != null)
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Color(0xFFE5EDE7)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _sharePdf(existingPdf, doc.title),
                                icon: const Icon(Icons.ios_share_rounded),
                                label: const Text('공유'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => context.push(
                                  '/document/${widget.documentId}/export',
                                ),
                                icon: const Icon(Icons.save_rounded),
                                label: const Text('PDF 저장'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
