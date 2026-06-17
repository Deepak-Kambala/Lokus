class HiveConstants {
  static const String settingsBox = 'settings';
  static const String modelsBox = 'models';
  static const String conversationsBox = 'conversations';
  static const String messagesBox = 'messages';
  static const String memoriesBox = 'memories';

  // Settings keys
  static const String onboardingComplete = 'onboarding_complete';
  static const String storageFolderUri = 'storage_folder_uri';
  static const String storageFolderPath = 'storage_folder_path';
  static const String selectedModelId = 'selected_model_id';
  static const String appTheme = 'app_theme';
  static const String appLanguage = 'app_language';
  static const String systemPrompts = 'system_prompts';
  static const String activeSystemPromptTitle = 'active_system_prompt_title';
  static const String activeSystemPromptText = 'active_system_prompt_text';
}

class HiveTypeIds {
  static const int aiModel = 0;
  static const int modelStatus = 1;
  static const int modelCategory = 2;
  static const int conversation = 3;
  static const int chatMessage = 4;
  static const int messageRole = 5;
  // Memory feature
  static const int memoryModel = 6;
  static const int memoryCategory = 7;
}
