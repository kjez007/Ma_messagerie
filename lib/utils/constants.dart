// ============================================================
// CONFIGURATION SUPABASE
// Remplacez ces valeurs par vos vraies credentials Supabase
// ============================================================

class AppConstants {
  // 🔑 À remplacer avec vos credentials Supabase
  static const String supabaseUrl = 'https://thdobvukqojzjmaopatr.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZG9idnVrcW9qemptYW9wYXRyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI5Nzc5MzAsImV4cCI6MjA4ODU1MzkzMH0.oxHBOFxa3SWKxThXzNar1fFiqsb5-6NQEKOFe0A0oeg';

  // Storage Buckets
  static const String imageBucket = 'chat-images';
  static const String videoBucket = 'chat-videos';
  static const String avatarBucket = 'avatars';

  // Tables
  static const String profilesTable = 'profiles';
  static const String conversationsTable = 'conversations';
  static const String participantsTable = 'conversation_participants';
  static const String messagesTable = 'messages';

  // Message types
  static const String textType = 'text';
  static const String imageType = 'image';
  static const String videoType = 'video';

  // Realtime channels
  static const String messagesChannel = 'messages_channel';

  // UI
  static const String appName = 'Messagerie';
  static const double maxVideoSizeMB = 50.0;
  static const double maxImageSizeMB = 10.0;
}
