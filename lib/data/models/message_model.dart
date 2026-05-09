import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, video, audio, file, call }

String _typeToStr(MessageType t) {
  switch (t) {
    case MessageType.text:  return 'text';
    case MessageType.image: return 'image';
    case MessageType.video: return 'video';
    case MessageType.audio: return 'audio';
    case MessageType.file:  return 'file';
    case MessageType.call:  return 'call';
  }
}

MessageType _typeFromStr(String? s) {
  switch (s) {
    case 'image': return MessageType.image;
    case 'video': return MessageType.video;
    case 'audio': return MessageType.audio;
    case 'file':  return MessageType.file;
    case 'call':  return MessageType.call;
    default:      return MessageType.text;
  }
}

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;
  final String? replyToId;
  final String? replyToContent;
  final String? replyToSenderName;
  final bool isDeleted;
  final String? fileUrl;
  final String? fileName;
  final int? fileSize;
  final int? audioDuration;

  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.replyToId,
    this.replyToContent,
    this.replyToSenderName,
    this.isDeleted = false,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.audioDuration,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      chatId: map['chatId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? '',
      content: map['content'] as String? ?? '',
      type: _typeFromStr(map['type'] as String?),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] as bool? ?? false,
      replyToId: map['replyToId'] as String?,
      replyToContent: map['replyToContent'] as String?,
      replyToSenderName: map['replyToSenderName'] as String?,
      isDeleted: map['isDeleted'] as bool? ?? false,
      fileUrl: map['fileUrl'] as String?,
      fileName: map['fileName'] as String?,
      fileSize: map['fileSize'] as int?,
      audioDuration: map['audioDuration'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'type': _typeToStr(type),
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'replyToId': replyToId,
      'replyToContent': replyToContent,
      'replyToSenderName': replyToSenderName,
      'isDeleted': isDeleted,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'audioDuration': audioDuration,
    };
  }

  MessageModel copyWith({
    bool? isRead,
    bool? isDeleted,
    String? content,
  }) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      content: content ?? this.content,
      type: type,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      replyToId: replyToId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
      isDeleted: isDeleted ?? this.isDeleted,
      fileUrl: fileUrl,
      fileName: fileName,
      fileSize: fileSize,
      audioDuration: audioDuration,
    );
  }

  bool get isMedia => type == MessageType.image || type == MessageType.video;
}
