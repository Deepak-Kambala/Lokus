import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/chat/presentation/screens/chat_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/models/presentation/screens/model_manager_screen.dart';
import '../features/onboarding/presentation/screens/storage_setup_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../services/storage_service.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final storageService = ref.watch(storageServiceProvider);

  return GoRouter(
    initialLocation: storageService.isOnboardingComplete ? '/home' : '/setup',
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: '/setup',
        name: 'setup',
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const StorageSetupScreen()),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        pageBuilder: (context, state) =>
            _fadePage(key: state.pageKey, child: const HomeScreen()),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        name: 'chat',
        pageBuilder: (context, state) {
          final conversationId = state.pathParameters['conversationId']!;
          final modelId = state.uri.queryParameters['modelId'];
          final initialMessage =
              state.extra is String ? state.extra as String : null;
          return _fadePage(
            key: state.pageKey,
            child: ChatScreen(
              conversationId: conversationId,
              modelId: modelId,
              initialMessage: initialMessage,
            ),
          );
        },
      ),
      GoRoute(
        path: '/models',
        name: 'models',
        pageBuilder: (context, state) =>
            _slidePage(key: state.pageKey, child: const ModelManagerScreen()),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        pageBuilder: (context, state) =>
            _slidePage(key: state.pageKey, child: const SettingsScreen()),
      ),
    ],
    errorPageBuilder: (context, state) => _fadePage(
      key: state.pageKey,
      child: Scaffold(
        backgroundColor: Color(0xFF0E0E10),
        body: Center(
            child: Text('Not found', style: TextStyle(color: Colors.white70))),
      ),
    ),
  );
});

CustomTransitionPage<void> _fadePage(
    {required LocalKey key, required Widget child}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child),
  );
}

CustomTransitionPage<void> _slidePage(
    {required LocalKey key, required Widget child}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (_, animation, __, child) {
      final tween = Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
