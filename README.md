# Lokus — Local AI Chat App for Android

A production-quality Flutter app for running local AI models on-device.

---

## Screenshots Overview

| Screen | Description |
|--------|-------------|
| Storage Setup | First-launch folder picker |
| Home | Welcome screen with quick-start prompts |
| Chat | Full markdown chat with streaming tokens |
| Model Manager | Browse + download GGUF models |
| Settings | App configuration |

---

## Architecture

```
lib/
├── core/
│   └── constants/
│       ├── app_constants.dart        # App-wide constants
│       └── hive_constants.dart       # Hive box names & type IDs
├── features/
│   ├── onboarding/
│   │   └── presentation/screens/
│   │       └── storage_setup_screen.dart
│   ├── home/
│   │   ├── presentation/screens/
│   │   │   └── home_screen.dart
│   │   └── widgets/
│   │       ├── conversation_drawer.dart
│   │       └── model_selector_button.dart
│   ├── models/
│   │   ├── data/
│   │   │   ├── datasources/mock_model_data.dart
│   │   │   └── repositories/models_repository.dart
│   │   ├── domain/entities/
│   │   │   ├── ai_model.dart
│   │   │   └── ai_model.g.dart       # Hive adapter (manual)
│   │   ├── presentation/
│   │   │   ├── screens/model_manager_screen.dart
│   │   │   └── widgets/
│   │   │       ├── browse_model_card.dart
│   │   │       └── downloaded_model_card.dart
│   │   └── providers/models_provider.dart
│   ├── chat/
│   │   ├── domain/entities/
│   │   │   ├── chat_message.dart
│   │   │   ├── chat_message.g.dart
│   │   │   ├── conversation.dart
│   │   │   └── conversation.g.dart
│   │   └── presentation/screens/
│   │       └── chat_screen.dart
│   ├── conversations/
│   │   └── providers/
│   │       └── conversations_provider.dart
│   └── settings/
│       └── presentation/screens/
│           └── settings_screen.dart
├── router/
│   └── app_router.dart               # GoRouter configuration
├── services/
│   ├── storage_service.dart          # Onboarding + settings persistence
│   ├── download_service.dart         # Dio-based download with pause/resume
│   └── inference_service.dart        # Placeholder — replace with llama.cpp
├── shared/
│   ├── theme/app_theme.dart          # Full Material 3 dark theme
│   └── widgets/common_widgets.dart   # Reusable UI components
└── main.dart
```

---

## Setup Instructions

### 1. Prerequisites

- Flutter SDK `>=3.16.0` ([install](https://flutter.dev/docs/get-started/install))
- Android Studio / VS Code with Flutter extension
- Android device or emulator (API 24+, Android 7+)

### 2. Clone & Install

```bash
git clone <your-repo-url>
cd lokus
flutter pub get
```

### 3. Fonts (Already Included)

Inter fonts are **already bundled** in `assets/fonts/`. No download required.

```
assets/fonts/
├── Geist-Regular.ttf
├── Geist-Medium.ttf
├── Geist-SemiBold.ttf
└── Geist-Bold.ttf
```

> **Alternative**: Replace with **Inter** from Google Fonts. Update `pubspec.yaml` font family to `Inter`.

### 4. Run

```bash
flutter run --debug
# or for release:
flutter run --release
```

---

## Key Features

### ✅ Implemented

| Feature | Details |
|---------|---------|
| **Storage Setup** | First-launch folder picker using `file_picker`, persisted via Hive |
| **Home Screen** | Welcome, what's new, quick-start prompts, chat input |
| **Conversation Drawer** | Slide drawer with search, pin, rename, delete |
| **Model Manager** | Two-tab UI — Downloaded + Browse |
| **Model Download** | Dio-based download with progress, pause, resume, cancel |
| **Chat Screen** | Full streaming chat, Markdown rendering, typing animation |
| **Message Actions** | Copy, Like, Dislike; token stats per message |
| **Settings Screen** | Storage, system prompts, language, export, about |
| **Dark Theme** | Charcoal + soft purple accent, full Material 3 |
| **Local Persistence** | All conversations and models stored via Hive |
| **Navigation** | GoRouter with fade/slide transitions |
| **State Management** | Riverpod throughout |

### 🔧 Placeholder / TODO

| Item | How to Complete |
|------|----------------|
| **Real inference** | Replace `InferenceService` with llama.cpp FFI bindings or HTTP to `llama-server` |
| **SAF folder picker** | Upgrade `file_picker` to use Android Storage Access Framework with persistent URI permissions |
| **Font files** | Add Geist `.ttf` files to `assets/fonts/` |
| **App icon** | Add icon to `android/app/src/main/res/mipmap-*/` |
| **Model download URLs** | Update `MockModelData` with verified HuggingFace GGUF URLs |

---

## Integrating a Real Inference Backend

The `InferenceService` class in `lib/services/inference_service.dart` is designed for easy swap-out.

### Option A: llama.cpp via FFI

```dart
// In inference_service.dart, replace generateStream() with:
import 'dart:ffi';
import 'package:ffi/ffi.dart';

final llamaLib = DynamicLibrary.open('libllama.so');
// Bind to llama_init, llama_eval, llama_token_to_str, etc.
```

Recommended package: [`llama_cpp_dart`](https://pub.dev/packages/llama_cpp_dart)

### Option B: Local HTTP server

Run `llama-server` (from llama.cpp) on the device or desktop, then call:

```dart
final response = await _dio.post(
  'http://localhost:8080/completion',
  data: {'prompt': prompt, 'n_predict': 512, 'stream': true},
);
```

---

## Supported Models (Browse Tab)

12 models pre-populated in `mock_model_data.dart`:

| Model | Provider | Size | Category |
|-------|----------|------|----------|
| Gemma 3 4B | Google | 2.5 GB | Instruct |
| Gemma 3 12B | Google | 7.3 GB | Instruct |
| Llama 3.2 3B | Meta | 2.0 GB | Instruct |
| Llama 3.1 8B | Meta | 4.9 GB | Instruct |
| Qwen2.5 7B | Alibaba | 4.7 GB | Instruct |
| Qwen2.5 Coder 7B | Alibaba | 4.7 GB | Coding |
| Phi-4 Mini | Microsoft | 2.5 GB | Reasoning |
| Phi-3.5 Mini | Microsoft | 2.4 GB | Instruct |
| Mistral 7B v0.3 | Mistral AI | 4.4 GB | Instruct |
| Nemotron Mini 4B | NVIDIA | 2.8 GB | Reasoning |
| DeepSeek R1 7B | DeepSeek | 4.7 GB | Reasoning |
| SmolLM2 1.7B | HuggingFace | 1.0 GB | Chat |

---

## Hive Type IDs

| Type | ID |
|------|----|
| `AiModel` | 0 |
| `ModelStatus` | 1 |
| `ModelCategory` | 2 |
| `Conversation` | 3 |
| `ChatMessage` | 4 |
| `MessageRole` | 5 |

---

## Theming

Colors defined in `AppTheme`:

```dart
background      = #0E0E10   // Deep charcoal
surface         = #161618
surfaceElevated = #1C1C1F
accent          = #8B5CF6   // Soft purple
accentLight     = #A78BFA
textPrimary     = #F5F5F7
textSecondary   = #8E8E93
```

---

## Android Requirements

- `minSdkVersion`: 24 (Android 7.0)
- `targetSdkVersion`: 34 (Android 14)
- Permissions: `INTERNET`, `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, `MANAGE_EXTERNAL_STORAGE`

---

## License

MIT License — free for personal and commercial use.

---

## Credits

- Local-first AI chat UI
- Fonts: [Geist](https://vercel.com/font) by Vercel
- Models: HuggingFace GGUF ecosystem
