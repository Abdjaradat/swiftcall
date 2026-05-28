import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_constants.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static StorageService get instance => _instance;
  static final StorageService _instance = StorageService._();
  StorageService._();

  String get _uid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    assert(uid != null, 'StorageService used while unauthenticated');
    return uid ?? '';
  }

  Future<String?> uploadProfileImage(File file) async {
    return _upload(
      file: file,
      path: '${AppConstants.profileImagesPath}/$_uid.jpg',
    );
  }

  Future<String?> uploadChatImage(File file, String chatId) async {
    final ext = p.extension(file.path);
    final name = '${DateTime.now().millisecondsSinceEpoch}$ext';
    return _upload(
      file: file,
      path: '${AppConstants.chatImagesPath}/$chatId/$name',
    );
  }

  Future<String?> uploadChatFile(File file, String chatId) async {
    final name = p.basename(file.path);
    return _upload(
      file: file,
      path: '${AppConstants.chatFilesPath}/$chatId/$name',
    );
  }

  Future<String?> uploadChatAudio(File file, String chatId) async {
    final name = '${DateTime.now().millisecondsSinceEpoch}.m4a';
    return _upload(
      file: file,
      path: '${AppConstants.chatAudioPath}/$chatId/$name',
    );
  }

  Future<String?> uploadChatVideo(File file, String chatId) async {
    final ext = p.extension(file.path);
    final name = '${DateTime.now().millisecondsSinceEpoch}$ext';
    return _upload(
      file: file,
      path: '${AppConstants.chatVideosPath}/$chatId/$name',
    );
  }

  Future<String?> _upload({
    required File file,
    required String path,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref = _storage.ref(path);
      final mimeType = lookupMimeType(file.path);
      final metadata = mimeType != null
          ? SettableMetadata(contentType: mimeType)
          : null;

      final task = ref.putFile(file, metadata);

      if (onProgress != null) {
        task.snapshotEvents.listen((snapshot) {
          final progress =
              snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      final snapshot = await task;
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (_) {
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (_) {}
  }
}
