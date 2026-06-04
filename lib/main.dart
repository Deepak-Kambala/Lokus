import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/constants/hive_constants.dart';
import 'features/chat/domain/entities/chat_message.dart';
import 'features/chat/domain/entities/conversation.dart';
import 'features/models/domain/entities/ai_model.dart';
import 'router/app_router.dart';
import 'shared/theme/app_theme.dart';

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

  runApp(
    const ProviderScope(
      child: LokusApp(),
    ),
  );
}

void _recordFatalError(Object error, StackTrace? stackTrace) {
  if (kDebugMode) {
    debugPrint('Uncaught app error: $error');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

class LokusApp extends ConsumerWidget {
  const LokusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
