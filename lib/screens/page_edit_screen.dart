import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';

import '../models/filter_type.dart';
import '../models/scan_page_record.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

final _pageByIdProvider =
    FutureProvider.family<ScanPageRecord?, String>((ref, pageId) {
  return ref.watch(documentRepositoryProvider).getPage(pageId);
});

class PageEditScreen extends ConsumerStatefulWidget {
  const PageEditScreen({
    super.key,
    required this.documentId,
    required this.pageId,
  });

  final String documentId;
  final String pageId;

  @override
  ConsumerState<PageEditScreen> createState() => _PageEditScreenState();
}

class _PageEditScreenState extends ConsumerState<PageEditScreen> {
  PageFilterType? _filter;
  double _sharpness = 40;
  bool _initialized = false;
  bool _showOriginal = false;

  @override
  void didUpdateWidget(PageEditScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageId != widget.pageId) {
      _initialized = false;
      _filter = null;
    }
  }

  Future<void> _crop(String processedPath) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: processedPath,
      compressFormat: ImageCompressFormat.png,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '영역 조정',
          toolbarColor: AppColors.forest,
          toolbarWidgetColor: Colors.white,
        ),
        IOSUiSettings(title: '영역 조정'),
      ],
    );
    if (cropped == null || !mounted) return;
    try {
      await ref.read(documentRepositoryProvider).applyCroppedProcessedImage(
            pageId: widget.pageId,
            croppedFilePath: cropped.path,
          );
      ref.invalidate(_pageByIdProvider(widget.pageId));
      ref.invalidate(documentPagesProvider(widget.documentId));
      ref.invalidate(documentDetailProvider(widget.documentId));
      ref.invalidate(documentOcrTextProvider(widget.documentId));
      setState(() => _initialized = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('크롭 적용 실패: $e')),
      );
    }
  }

  Future<void> _apply() async {
    final f = _filter;
    if (f == null) return;
    try {
      await ref.read(documentRepositoryProvider).updatePageFilterAndSharpness(
            pageId: widget.pageId,
            filter: f,
            sharpness: _sharpness.round(),
          );
      ref.invalidate(_pageByIdProvider(widget.pageId));
      ref.invalidate(documentPagesProvider(widget.documentId));
      ref.invalidate(documentDetailProvider(widget.documentId));
      ref.invalidate(documentOcrTextProvider(widget.documentId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('보정을 저장했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageAsync = ref.watch(_pageByIdProvider(widget.pageId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('편집'),
        actions: [
          TextButton(
            onPressed: _filter == null ? null : _apply,
            child: const Text('저장'),
          ),
        ],
      ),
      body: pageAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (page) {
          if (page == null) {
            return const Center(child: Text('페이지를 찾을 수 없습니다.'));
          }
          if (!_initialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _filter = page.filterType;
                _sharpness = page.sharpness.toDouble();
                _initialized = true;
              });
            });
          }
          if (_filter == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final f = _filter!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('보정 후')),
                  ButtonSegment(value: true, label: Text('원본')),
                ],
                selected: {_showOriginal},
                onSelectionChanged: (s) {
                  setState(() => _showOriginal = s.first);
                },
              ),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(
                      _showOriginal
                          ? page.originalImagePath
                          : page.processedImagePath,
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => _crop(page.processedImagePath),
                icon: const Icon(Icons.crop),
                label: const Text('수동 크롭'),
              ),
              const SizedBox(height: 24),
              Text('보정 모드', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<PageFilterType>(
                segments: const [
                  ButtonSegment(
                    value: PageFilterType.color,
                    label: Text('컬러'),
                  ),
                  ButtonSegment(
                    value: PageFilterType.grayscale,
                    label: Text('그레이'),
                  ),
                  ButtonSegment(
                    value: PageFilterType.blackWhite,
                    label: Text('흑백'),
                  ),
                ],
                selected: {f},
                onSelectionChanged: (s) {
                  setState(() => _filter = s.first);
                },
              ),
              const SizedBox(height: 24),
              Text('선명도', style: Theme.of(context).textTheme.titleMedium),
              Slider(
                value: _sharpness,
                max: 100,
                divisions: 20,
                label: '${_sharpness.round()}',
                onChanged: (v) => setState(() => _sharpness = v),
              ),
              const SizedBox(height: 8),
              Text(
                '선명도는 OCR(2차) 정확도에도 반영될 수 있도록 보정 이미지에 적용됩니다.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}
