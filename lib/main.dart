import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/hive_constants.dart';
import 'features/chat/domain/entities/chat_message.dart';
import 'features/chat/domain/entities/conversation.dart';
import 'features/conversations/providers/conversations_provider.dart';
import 'features/models/domain/entities/ai_model.dart';
import 'router/app_router.dart';
import 'shared/theme/app_theme.dart';
import 'services/storage_service.dart';

void main() {
  runZonedGuarded(() async {
    await _bootstrap();
  }, _recordFatalError);
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _recordFatalError(details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    _recordFatalError(error, stack);
    return true;
  };

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0E0E10),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Hive
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(AiModelAdapter());
  Hive.registerAdapter(ModelStatusAdapter());
  Hive.registerAdapter(ModelCategoryAdapter());
  Hive.registerAdapter(ConversationAdapter());
  Hive.registerAdapter(ChatMessageAdapter());
  Hive.registerAdapter(MessageRoleAdapter());

  // Open boxes
  await Hive.openBox(HiveConstants.settingsBox);
  await Hive.openBox<AiModel>(HiveConstants.modelsBox);
  await Hive.openBox<Conversation>(HiveConstants.conversationsBox);
  await Hive.openBox<ChatMessage>(HiveConstants.messagesBox);

  await _prepareSessionState();

  runApp(
    const ProviderScope(
      child: LokusApp(),
    ),
  );
}

Future<void> _prepareSessionState() async {
  final settings = Hive.box(HiveConstants.settingsBox);
  final conversations = Hive.box<Conversation>(HiveConstants.conversationsBox);
  final messages = Hive.box<ChatMessage>(HiveConstants.messagesBox);

  await settings.delete(HiveConstants.selectedModelId);
  await settings.delete(HiveConstants.appTheme);

  final emptyConversationIds = conversations.values
      .where((convo) =>
          convo.messageCount == 0 &&
          !messages.values.any((msg) => msg.conversationId == convo.id))
      .map((convo) => convo.id)
      .toList();

  for (final id in emptyConversationIds) {
    await conversations.delete(id);
  }

  final storagePath = settings.get(HiveConstants.storageFolderPath) as String?;
  if (storagePath == null || storagePath.isEmpty) return;

  await ConversationsRepository(StorageService())
      .restoreConversationsFromStorage();

  final chatsDir = Directory('$storagePath/chats');
  if (!await chatsDir.exists()) return;

  for (final id in emptyConversationIds) {
    await for (final file
        in chatsDir.list(recursive: true, followLinks: false)) {
      if (file is File && file.path.endsWith('$id.json')) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }
}

void _recordFatalError(Object error, StackTrace? stackTrace) {
  if (kDebugMode) {
    debugPrint('Uncaught app error: $error');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

class LokusApp extends ConsumerStatefulWidget {
  const LokusApp({super.key});

  @override
  ConsumerState<LokusApp> createState() => _LokusAppState();
}

class _LokusAppState extends ConsumerState<LokusApp> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return MaterialApp(
        title: 'Lokus',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const _SplashScreen(),
      );
    }

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Lokus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.border),
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/images/splash_logo.svg',
                  width: 68,
                  height: 68,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Lokus',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
