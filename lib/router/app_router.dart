import 'package:go_router/go_router.dart';

import '../screens/document_detail_screen.dart';
import '../screens/home_screen.dart';
import '../screens/ocr_result_screen.dart';
import '../screens/page_edit_screen.dart';
import '../screens/pages_editor_screen.dart';
import '../screens/pdf_export_screen.dart';
import '../screens/settings_screen.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/document/:id/page/:pageId/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final pageId = state.pathParameters['pageId']!;
          return PageEditScreen(documentId: id, pageId: pageId);
        },
      ),
      GoRoute(
        path: '/document/:id/pages',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PagesEditorScreen(documentId: id);
        },
      ),
      GoRoute(
        path: '/document/:id/export',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PdfExportScreen(documentId: id);
        },
      ),
      GoRoute(
        path: '/document/:id/ocr',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return OcrResultScreen(documentId: id);
        },
      ),
      GoRoute(
        path: '/document/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return DocumentDetailScreen(documentId: id);
        },
      ),
    ],
  );
}
