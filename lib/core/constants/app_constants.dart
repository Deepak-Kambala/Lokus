class AppConstants {
  static const String appName = 'Lokus';
  static const String appVersion = '1.0.0';

  // API / Download
  static const String huggingFaceBaseUrl = 'https://huggingface.co';
  static const int downloadChunkSize = 1024 * 1024; // 1MB

  // Chat
  static const int maxContextLength = 4096;
  static const double defaultTemperature = 0.7;
  static const int defaultMaxTokens = 512;

  // UI
  static const double borderRadius = 14.0;
  static const double cardRadius = 14.0;
  static const double bubbleRadius = 18.0;
  static const double inputRadius = 24.0;

  // Animations
  static const Duration fastAnimation = Duration(milliseconds: 150);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);
}

class ModelProviders {
  static const String google = 'Google';
  static const String meta = 'Meta';
  static const String mistral = 'Mistral AI';
  static const String microsoft = 'Microsoft';
  static const String nvidia = 'NVIDIA';
  static const String alibaba = 'Alibaba';
  static const String deepseek = 'DeepSeek';
  static const String qwen = 'Qwen';
}
