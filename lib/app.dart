import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme/app_theme.dart';

class BookScanApp extends StatelessWidget {
  const BookScanApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '북스캔',
      theme: buildBookScanTheme(),
      routerConfig: router,
    );
  }
}
