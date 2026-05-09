part of 'chat_bloc.dart';

abstract class ChatEvent {}

class ChatLoadMessages extends ChatEvent {
  final String chatId;
  ChatLoadMessages(this.chatId);
}

class ChatSendText extends ChatEvent {
  final String chatId;
  final String content;
  final String? replyToId;
  final String? replyToContent;
  final String? replyToSenderName;
  ChatSendText({
    required this.chatId,
    required this.content,
    this.replyToId,
    this.replyToContent,
    this.replyToSenderName,
  });
}

class ChatSendImage extends ChatEvent {
  final String chatId;
  final String filePath;
  ChatSendImage({required this.chatId, required this.filePath});
}

class ChatSendFile extends ChatEvent {
  final String chatId;
  final String filePath;
  final String fileName;
  ChatSendFile({required this.chatId, required this.filePath, required this.fileName});
}

class ChatSendAudio extends ChatEvent {
  final String chatId;
  final String filePath;
  final int duration;
  ChatSendAudio({required this.chatId, required this.filePath, required this.duration});
}

class ChatSendVideo extends ChatEvent {
  final String chatId;
  final String filePath;
  final String fileName;
  ChatSendVideo({required this.chatId, required this.filePath, required this.fileName});
}

class ChatDeleteMessage extends ChatEvent {
  final String chatId;
  final String messageId;
  ChatDeleteMessage({required this.chatId, required this.messageId});
}

class ChatTypingChanged extends ChatEvent {
  final String chatId;
  final bool isTyping;
  ChatTypingChanged({required this.chatId, required this.isTyping});
}

class ChatMarkAsRead extends ChatEvent {
  final String chatId;
  ChatMarkAsRead(this.chatId);
}
