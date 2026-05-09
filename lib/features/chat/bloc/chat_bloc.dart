import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/message_model.dart';
import '../../../data/services/chat_service.dart';
import '../../../data/services/storage_service.dart';

part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  StreamSubscription? _typingSub;
  Timer? _typingTimer;

  ChatBloc() : super(ChatInitial()) {
    on<ChatLoadMessages>(_onLoadMessages);
    on<ChatSendText>(_onSendText);
    on<ChatSendImage>(_onSendImage);
    on<ChatSendFile>(_onSendFile);
    on<ChatSendAudio>(_onSendAudio);
    on<ChatSendVideo>(_onSendVideo);
    on<ChatDeleteMessage>(_onDeleteMessage);
    on<ChatTypingChanged>(_onTypingChanged);
    on<ChatMarkAsRead>(_onMarkAsRead);
  }

  Future<void> _onLoadMessages(
    ChatLoadMessages event,
    Emitter<ChatState> emit,
  ) async {
    emit(ChatLoading());

    _typingSub?.cancel();
    _typingSub = ChatService.instance
        .watchTyping(event.chatId)
        .listen((typing) {
      if (state is ChatLoaded) {
        final current = state as ChatLoaded;
        final updated = current.copyWith(typingUsers: typing);
        emit(updated);
      }
    });

    await emit.forEach<List<MessageModel>>(
      ChatService.instance.watchMessages(event.chatId),
      onData: (msgs) {
        final current = state is ChatLoaded ? state as ChatLoaded : null;
        return ChatLoaded(
          messages: msgs,
          typingUsers: current?.typingUsers ?? {},
          isUploading: current?.isUploading ?? false,
        );
      },
      onError: (_, __) => ChatError('فشل تحميل الرسائل'),
    );
  }

  Future<void> _onSendText(
    ChatSendText event,
    Emitter<ChatState> emit,
  ) async {
    await ChatService.instance.sendMessage(
      chatId: event.chatId,
      content: event.content,
      type: MessageType.text,
      replyToId: event.replyToId,
      replyToContent: event.replyToContent,
      replyToSenderName: event.replyToSenderName,
    );
    await ChatService.instance.setTyping(event.chatId, false);
  }

  Future<void> _onSendImage(
    ChatSendImage event,
    Emitter<ChatState> emit,
  ) async {
    _setUploading(emit, true);
    final url = await StorageService.instance.uploadChatImage(
      File(event.filePath),
      event.chatId,
    );
    if (url == null) {
      _setUploading(emit, false, error: 'فشل رفع الصورة، تحقق من إعدادات Firebase Storage');
      return;
    }
    await ChatService.instance.sendMessage(
      chatId: event.chatId,
      content: url,
      type: MessageType.image,
      fileUrl: url,
    );
    _setUploading(emit, false);
  }

  Future<void> _onSendFile(
    ChatSendFile event,
    Emitter<ChatState> emit,
  ) async {
    _setUploading(emit, true);
    final file = File(event.filePath);
    final url = await StorageService.instance.uploadChatFile(file, event.chatId);
    if (url == null) {
      _setUploading(emit, false, error: 'فشل رفع الملف، تحقق من إعدادات Firebase Storage');
      return;
    }
    final size = await file.length();
    await ChatService.instance.sendMessage(
      chatId: event.chatId,
      content: event.fileName,
      type: MessageType.file,
      fileUrl: url,
      fileName: event.fileName,
      fileSize: size,
    );
    _setUploading(emit, false);
  }

  Future<void> _onSendAudio(
    ChatSendAudio event,
    Emitter<ChatState> emit,
  ) async {
    _setUploading(emit, true);
    final url = await StorageService.instance.uploadChatAudio(
      File(event.filePath),
      event.chatId,
    );
    if (url == null) {
      _setUploading(emit, false, error: 'فشل رفع الصوت');
      return;
    }
    await ChatService.instance.sendMessage(
      chatId: event.chatId,
      content: 'رسالة صوتية',
      type: MessageType.audio,
      fileUrl: url,
      audioDuration: event.duration,
    );
    _setUploading(emit, false);
  }

  Future<void> _onSendVideo(
    ChatSendVideo event,
    Emitter<ChatState> emit,
  ) async {
    _setUploading(emit, true);
    final url = await StorageService.instance.uploadChatVideo(
      File(event.filePath),
      event.chatId,
    );
    if (url == null) {
      _setUploading(emit, false, error: 'فشل رفع الفيديو');
      return;
    }
    final file = File(event.filePath);
    final size = await file.length();
    await ChatService.instance.sendMessage(
      chatId: event.chatId,
      content: event.fileName,
      type: MessageType.video,
      fileUrl: url,
      fileName: event.fileName,
      fileSize: size,
    );
    _setUploading(emit, false);
  }

  void _setUploading(Emitter<ChatState> emit, bool uploading, {String? error}) {
    if (state is ChatLoaded) {
      emit((state as ChatLoaded).copyWith(
        isUploading: uploading,
        uploadError: error,
        clearError: error == null && !uploading,
      ));
    }
  }

  Future<void> _onDeleteMessage(
    ChatDeleteMessage event,
    Emitter<ChatState> emit,
  ) async {
    await ChatService.instance.deleteMessage(event.chatId, event.messageId);
  }

  void _onTypingChanged(ChatTypingChanged event, Emitter<ChatState> emit) {
    _typingTimer?.cancel();
    ChatService.instance.setTyping(event.chatId, event.isTyping);
    if (event.isTyping) {
      _typingTimer = Timer(AppConstants.typingTimeout, () {
        ChatService.instance.setTyping(event.chatId, false);
      });
    }
  }

  Future<void> _onMarkAsRead(
    ChatMarkAsRead event,
    Emitter<ChatState> emit,
  ) async {
    await ChatService.instance.markAsRead(event.chatId);
  }

  @override
  Future<void> close() {
    _typingSub?.cancel();
    _typingTimer?.cancel();
    return super.close();
  }
}
