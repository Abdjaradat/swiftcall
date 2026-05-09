part of 'chat_bloc.dart';

abstract class ChatState {}

class ChatInitial extends ChatState {}
class ChatLoading extends ChatState {}

class ChatLoaded extends ChatState {
  final List<MessageModel> messages;
  final Map<String, bool> typingUsers;
  final bool isSending;
  final bool isUploading;
  final String? uploadError;

  ChatLoaded({
    required this.messages,
    this.typingUsers = const {},
    this.isSending = false,
    this.isUploading = false,
    this.uploadError,
  });

  ChatLoaded copyWith({
    List<MessageModel>? messages,
    Map<String, bool>? typingUsers,
    bool? isSending,
    bool? isUploading,
    String? uploadError,
    bool clearError = false,
  }) {
    return ChatLoaded(
      messages: messages ?? this.messages,
      typingUsers: typingUsers ?? this.typingUsers,
      isSending: isSending ?? this.isSending,
      isUploading: isUploading ?? this.isUploading,
      uploadError: clearError ? null : (uploadError ?? this.uploadError),
    );
  }
}

class ChatError extends ChatState {
  final String message;
  ChatError(this.message);
}
