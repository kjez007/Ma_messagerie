import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:mime/mime.dart';
import 'package:messagerie/utils/constants.dart';

class StorageService {
  final SupabaseClient _client = Supabase.instance.client;
  final _uuid = const Uuid();

  /// Upload d'une image de chat
  Future<String> uploadChatImage(File file) async {
    return _uploadFile(
      file: file,
      bucket: AppConstants.imageBucket,
      folder: 'messages',
    );
  }

  /// Upload d'une vidéo de chat
  Future<String> uploadChatVideo(File file) async {
    return _uploadFile(
      file: file,
      bucket: AppConstants.videoBucket,
      folder: 'messages',
    );
  }

  /// Upload d'un avatar
  Future<String> uploadAvatar(File file) async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'unknown';
    return _uploadFile(
      file: file,
      bucket: AppConstants.avatarBucket,
      folder: userId,
      keepName: true,
    );
  }

  /// Upload générique
  Future<String> _uploadFile({
    required File file,
    required String bucket,
    required String folder,
    bool keepName = false,
  }) async {
    final extension = p.extension(file.path);
    final fileName = keepName
        ? 'avatar$extension'
        : '${_uuid.v4()}$extension';
    final path = '$folder/$fileName';

    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

    await _client.storage.from(bucket).upload(
      path,
      file,
      fileOptions: FileOptions(
        contentType: mimeType,
        upsert: keepName,
      ),
    );

    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// Supprimer un fichier media
  Future<void> deleteFile(String url, String bucket) async {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      // Extraire le chemin relatif depuis l'URL publique
      final bucketIndex = pathSegments.indexOf(bucket);
      if (bucketIndex != -1) {
        final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
        await _client.storage.from(bucket).remove([filePath]);
      }
    } catch (e) {
      // Ignorer les erreurs de suppression
    }
  }

  /// Vérifier la taille d'un fichier
  bool isFileSizeValid(File file, {bool isVideo = false}) {
    final maxSize = isVideo
        ? AppConstants.maxVideoSizeMB
        : AppConstants.maxImageSizeMB;
    final fileSizeMB = file.lengthSync() / (1024 * 1024);
    return fileSizeMB <= maxSize;
  }

  /// Obtenir la taille en MB
  double getFileSizeMB(File file) {
    return file.lengthSync() / (1024 * 1024);
  }
}
