class AppConstants {
  // App Info
  static const String appName    = 'SwiftCall';
  static const String appVersion = '1.0.0';

  // LiveKit
  static const String livekitUrl         = 'wss://swiftcall-criz4m8x.livekit.cloud';
  static const String livekitTokenServer = 'https://swiftcall-backend.onrender.com';

  // Firestore Collections
  static const String usersCollection    = 'users';
  static const String chatsCollection    = 'chats';
  static const String messagesCollection = 'messages';
  static const String callsCollection    = 'calls';

  // Storage Paths
  static const String profileImagesPath  = 'profile_images';
  static const String chatImagesPath     = 'chat_images';
  static const String chatFilesPath      = 'chat_files';
  static const String chatAudioPath      = 'chat_audio';
  static const String chatVideosPath     = 'chat_videos';

  // SharedPreferences Keys
  static const String isDarkModeKey      = 'isDarkMode';
  static const String localeKey          = 'locale';
  static const String onboardingDoneKey  = 'onboardingDone';
  static const String userIdKey          = 'userId';

  // Timeouts
  static const Duration callTimeout    = Duration(seconds: 45);
  static const Duration typingTimeout  = Duration(seconds: 3);

  // Message limits
  static const int messagesPerPage       = 30;
  static const int maxImageSizeMB        = 10;
  static const int maxFileSizeMB         = 50;

  // Encryption key (replace with secure key management in production)
  static const String encryptionKey      = 'SwiftCall@2025!#SecureKey32Bytes';
  static const String encryptionIV       = 'SwiftCallIV16B!!';
}
