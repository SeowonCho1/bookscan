import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/app_constants.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sim = ref.watch(simulatedApprovedProvider);
    final plan = ref.watch(userPlanProvider);
    final limit = ref.watch(scanPageLimitProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          sim.when(
            loading: () => const ListTile(
              leading: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('설정 불러오는 중'),
            ),
            error: (e, _) => ListTile(
              title: Text('설정 오류: $e'),
            ),
            data: (approved) {
              return Card(
                child: SwitchListTile(
                  secondary: const Icon(Icons.developer_mode_outlined),
                  title: const Text('개발용 승인 모드'),
                  subtitle: const Text(
                    '서버 없이 승인 사용자처럼 동작합니다. 연속 촬영 제한이 풀리고 OCR을 실행할 수 있습니다.',
                  ),
                  value: approved,
                  onChanged: (v) {
                    ref.read(simulatedApprovedProvider.notifier).setApproved(v);
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: const Text('저장 위치'),
                  subtitle: const Text('내 기기 (로컬 저장)'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.filter_none_outlined),
                  title: const Text('연속 스캔 제한'),
                  subtitle: Text(
                    plan == UserPlan.free
                        ? '$limit페이지 (무료 모드)'
                        : '해제됨 (승인 모드)',
                  ),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.picture_as_pdf_outlined),
                  title: Text('파일 형식'),
                  subtitle: Text('PDF'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('카메라 권한'),
                  subtitle: const Text(
                    '스캔에 카메라가 필요합니다. 거부한 경우 시스템 설정에서 허용할 수 있습니다.',
                  ),
                  onTap: () async {
                    final s = await Permission.camera.status;
                    if (!context.mounted) return;
                    if (s.isPermanentlyDenied || s.isDenied) {
                      await openAppSettings();
                    } else {
                      await Permission.camera.request();
                    }
                  },
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('앱 정보'),
                  subtitle: Text('북스캔 — 로컬 스캔·PDF·OCR'),
                ),
              ],
            ),
          ),
          if (plan == UserPlan.free) ...[
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.forest,
                    AppColors.forest.withValues(alpha: 0.88),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '승인 모드로 업그레이드',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '관리자 승인 후 무제한 연속 스캔과 고급 OCR을 사용할 수 있습니다. 지금은 개발용 토글로 동작을 시험해 보세요.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.forest,
                      ),
                      onPressed: () {
                        ref
                            .read(simulatedApprovedProvider.notifier)
                            .setApproved(true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('개발용 승인 모드를 켰습니다.'),
                          ),
                        );
                      },
                      child: const Text('승인 모드 체험하기'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
