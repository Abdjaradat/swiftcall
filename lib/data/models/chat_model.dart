import 'package:cloud_firestore/cloud_firestore.dart';
import 'message_model.dart';
import 'user_model.dart';

class ChatModel {
  final String id;
  final List<String> participantIds;
  final MessageModel? lastMessage;
  final Map<String, int> unreadCount;
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final UserModel? otherUser; // populated on client side

  const ChatModel({
    required this.id,
    required this.participantIds,
    this.lastMessage,
    this.unreadCount = const {},
    this.updatedAt,
    this.createdAt,
    this.otherUser,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    MessageModel? lastMsg;
    if (map['lastMessage'] != null) {
      lastMsg = MessageModel.fromMap(
        Map<String, dynamic>.from(map['lastMessage'] as Map),
        'last',
      );
    }

    return ChatModel(
      id: id,
      participantIds: List<String>.from(map['participantIds'] as List? ?? []),
      lastMessage: lastMsg,
      unreadCount: Map<String, int>.from(map['unreadCount'] as Map? ?? {}),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participantIds': participantIds,
      'lastMessage': lastMessage?.toMap(),
      'unreadCount': unreadCount,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  ChatModel copyWith({UserModel? otherUser, MessageModel? lastMessage, Map<String, int>? unreadCount}) {
    return ChatModel(
      id: id,
      participantIds: participantIds,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt,
      createdAt: createdAt,
      otherUser: otherUser ?? this.otherUser,
    );
  }

  int unreadCountFor(String uid) => unreadCount[uid] ?? 0;
}
