import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import 'auth_service.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static ChatService get instance => _instance;
  static final ChatService _instance = ChatService._();
  ChatService._();

  String get _myUid => FirebaseAuth.instance.currentUser!.uid;

  // ── Chats ──────────────────────────────────────────────

  Stream<List<ChatModel>> watchChats() {
    // No orderBy → avoids composite-index requirement; sort client-side.
    return _db
        .collection('chats')
        .where('participantIds', arrayContains: _myUid)
        .snapshots()
        .asyncMap((snap) async {
      final chats = <ChatModel>[];
      for (final doc in snap.docs) {
        var chat = ChatModel.fromMap(doc.data(), doc.id);
        final otherUid = chat.participantIds.firstWhere(
          (id) => id != _myUid,
          orElse: () => '',
        );
        if (otherUid.isNotEmpty) {
          final user = await AuthService.instance.getUserById(otherUid);
          chat = chat.copyWith(otherUser: user);
        }
        chats.add(chat);
      }
      // Sort by most recent message client-side
      chats.sort((a, b) {
        final ta = a.lastMessage?.timestamp ?? DateTime(2000);
        final tb = b.lastMessage?.timestamp ?? DateTime(2000);
        return tb.compareTo(ta);
      });
      return chats;
    });
  }

  Future<String> getOrCreateChat(String otherUid) async {
    final snap = await _db
        .collection('chats')
        .where('participantIds', arrayContains: _myUid)
        .get();

    for (final doc in snap.docs) {
      final ids = List<String>.from(doc.data()['participantIds'] as List);
      if (ids.contains(otherUid)) return doc.id;
    }

    final ref = _db.collection('chats').doc();
    await ref.set({
      'participantIds': [_myUid, otherUid],
      'unreadCount': {_myUid: 0, otherUid: 0},
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
    return ref.id;
  }

  // ── Messages ────────────────────────────────────────────

  Stream<List<MessageModel>> watchMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MessageModel.fromMap(d.data(), d.id))
            .toList());
  }

  Future<void> sendMessage({
    required String chatId,
    required String content,
    required MessageType type,
    String? replyToId,
    String? replyToContent,
    String? replyToSenderName,
    String? fileUrl,
    String? fileName,
    int? fileSize,
    int? audioDuration,
  }) async {
    final me = await AuthService.instance.getCurrentUserModel();
    if (me == null) return;

    // Look up the other participant from the chat document
    final chatDoc = await _db.collection('chats').doc(chatId).get();
    final ids = List<String>.from(
        chatDoc.data()?['participantIds'] as List? ?? []);
    final otherUid =
        ids.firstWhere((id) => id != _myUid, orElse: () => '');

    final msgRef =
        _db.collection('chats').doc(chatId).collection('messages').doc();

    final msg = MessageModel(
      id: msgRef.id,
      chatId: chatId,
      senderId: _myUid,
      senderName: me.name,
      content: content,
      type: type,
      timestamp: DateTime.now(),
      replyToId: replyToId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
      fileUrl: fileUrl,
      fileName: fileName,
      fileSize: fileSize,
      audioDuration: audioDuration,
    );

    final chatUpdate = <String, dynamic>{
      'lastMessage': msg.toMap(),
      'updatedAt': Timestamp.now(),
    };
    if (otherUid.isNotEmpty) {
      chatUpdate['unreadCount.$otherUid'] = FieldValue.increment(1);
    }

    final batch = _db.batch();
    batch.set(msgRef, msg.toMap());
    batch.update(_db.collection('chats').doc(chatId), chatUpdate);
    await batch.commit();
  }

  Future<void> deleteChat(String chatId) async {
    final msgSnap = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();
    final batch = _db.batch();
    for (final doc in msgSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('chats').doc(chatId));
    await batch.commit();
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({'isDeleted': true, 'content': 'تم حذف هذه الرسالة'});
  }

  Future<void> markAsRead(String chatId) async {
    await _db.collection('chats').doc(chatId).update({
      'unreadCount.$_myUid': 0,
    });
    final unread = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: _myUid)
        .get();

    if (unread.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ── Typing ──────────────────────────────────────────────

  Future<void> setTyping(String chatId, bool isTyping) async {
    await _db.collection('chats').doc(chatId).update({
      'typing.$_myUid': isTyping,
    });
  }

  Stream<Map<String, bool>> watchTyping(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null || !data.containsKey('typing')) return {};
      return Map<String, bool>.from(data['typing'] as Map);
    });
  }

  Future<List<MessageModel>> loadMoreMessages(
    String chatId,
    DocumentSnapshot lastDoc,
  ) async {
    final snap = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .startAfterDocument(lastDoc)
        .limit(30)
        .get();
    return snap.docs.map((d) => MessageModel.fromMap(d.data(), d.id)).toList();
  }
}
