import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:record/record.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/message_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/chat_service.dart';
import '../bloc/chat_bloc.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel? otherUser;

  const ChatScreen({super.key, required this.chatId, this.otherUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _recorder = AudioRecorder();
  final _imagePicker = ImagePicker();

  bool _showEmoji = false;
  bool _isRecording = false;
  MessageModel? _replyTo;
  String? _resolvedChatId;

  @override
  void initState() {
    super.initState();
    _resolveChatId();
  }

  Future<void> _resolveChatId() async {
    String chatId = widget.chatId;
    if (chatId.startsWith('new_') && widget.otherUser != null) {
      final otherUid = chatId.replaceFirst('new_', '');
      chatId = await ChatService.instance.getOrCreateChat(otherUid);
    }
    setState(() => _resolvedChatId = chatId);
    if (mounted) {
      context.read<ChatBloc>()
        ..add(ChatLoadMessages(chatId))
        ..add(ChatMarkAsRead(chatId));
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _recorder.dispose();
    if (_resolvedChatId != null) {
      ChatService.instance.setTyping(_resolvedChatId!, false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final other = widget.otherUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(other),
      body: BlocListener<ChatBloc, ChatState>(
        listener: (ctx, state) {
          if (state is ChatLoaded && state.uploadError != null) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(state.uploadError!, style: GoogleFonts.cairo()),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Column(
        children: [
          Expanded(child: _MessagesList(
            chatId: _resolvedChatId,
            onReplyMessage: (m) => setState(() => _replyTo = m),
          )),
          _UploadProgressBar(),
          _TypingIndicatorBand(chatId: _resolvedChatId),
          if (_replyTo != null) _ReplyPreview(msg: _replyTo!, onCancel: () => setState(() => _replyTo = null)),
          _InputBar(
            controller: _inputCtrl,
            showEmoji: _showEmoji,
            isRecording: _isRecording,
            onSend: _sendText,
            onEmojiToggle: () => setState(() => _showEmoji = !_showEmoji),
            onAttach: _showAttachSheet,
            onRecordToggle: _toggleRecording,
            onChanged: (v) {
              if (_resolvedChatId != null) {
                context.read<ChatBloc>().add(
                  ChatTypingChanged(chatId: _resolvedChatId!, isTyping: v.isNotEmpty),
                );
              }
            },
          ),
          if (_showEmoji)
            SizedBox(
              height: 280,
              child: EmojiPicker(
                textEditingController: _inputCtrl,
                config: const Config(
                  emojiViewConfig: EmojiViewConfig(emojiSizeMax: 28),
                  skinToneConfig: SkinToneConfig(enabled: false),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: AppColors.surface,
                    iconColor: AppColors.textHint,
                    iconColorSelected: AppColors.primary,
                    indicatorColor: AppColors.primary,
                  ),
                  bottomActionBarConfig: BottomActionBarConfig(
                    backgroundColor: AppColors.surface,
                    buttonColor: AppColors.card,
                    buttonIconColor: AppColors.textSecondary,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: AppColors.surface,
                    buttonIconColor: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(UserModel? other) {
    return AppBar(
      backgroundColor: AppColors.surface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded),
        onPressed: () => context.pop(),
      ),
      title: GestureDetector(
        onTap: () {},
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.card,
              backgroundImage: other?.photoUrl != null
                  ? CachedNetworkImageProvider(other!.photoUrl!)
                  : null,
              child: other?.photoUrl == null
                  ? Text(other?.initials ?? '?',
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary))
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  other?.name ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (other != null)
                  StreamBuilder<UserModel?>(
                    stream: AuthService.instance.watchUser(other.uid),
                    builder: (_, snap) {
                      final u = snap.data ?? other;
                      return Text(
                        u.isOnline ? 'متصل الآن' : 'غير متصل',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: u.isOnline ? AppColors.online : AppColors.textHint,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (other != null) ...[
          IconButton(
            icon: const Icon(Icons.call_rounded, color: AppColors.callGreen),
            onPressed: () => context.push(
              '${AppRouter.voiceCall}/call_${other.uid}',
              extra: other,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: AppColors.primary),
            onPressed: () => context.push(
              '${AppRouter.videoCall}/call_${other.uid}',
              extra: other,
            ),
          ),
        ],
        const SizedBox(width: 4),
      ],
    );
  }

  void _sendText() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _resolvedChatId == null) return;
    context.read<ChatBloc>().add(ChatSendText(
      chatId: _resolvedChatId!,
      content: text,
      replyToId: _replyTo?.id,
      replyToContent: _replyTo?.content,
      replyToSenderName: _replyTo?.senderName,
    ));
    _inputCtrl.clear();
    setState(() => _replyTo = null);
    _scrollToBottom();
  }

  void _showAttachSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachOption(icon: '🖼️', label: 'صورة', onTap: () { Navigator.pop(ctx); _pickImage(); }),
                _AttachOption(icon: '📷', label: 'كاميرا', onTap: () { Navigator.pop(ctx); _takePhoto(); }),
                _AttachOption(icon: '🎥', label: 'فيديو', onTap: () { Navigator.pop(ctx); _pickVideo(); }),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachOption(icon: '📁', label: 'ملف', onTap: () { Navigator.pop(ctx); _pickFile(); }),
                _AttachOption(icon: '👤', label: 'جهة اتصال', onTap: () { Navigator.pop(ctx); _pickContact(); }),
                _AttachOption(icon: '🎤', label: 'تسجيل', onTap: () { Navigator.pop(ctx); _toggleRecording(); }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final xFile = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (xFile == null || _resolvedChatId == null) return;
    context.read<ChatBloc>().add(ChatSendImage(chatId: _resolvedChatId!, filePath: xFile.path));
  }

  Future<void> _takePhoto() async {
    final xFile = await _imagePicker.pickImage(source: ImageSource.camera);
    if (xFile == null || _resolvedChatId == null) return;
    context.read<ChatBloc>().add(ChatSendImage(chatId: _resolvedChatId!, filePath: xFile.path));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || _resolvedChatId == null) return;
    final file = result.files.first;
    if (file.path == null) return;
    context.read<ChatBloc>().add(ChatSendFile(
      chatId: _resolvedChatId!,
      filePath: file.path!,
      fileName: file.name,
    ));
  }

  Future<void> _pickVideo() async {
    final xFile = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (xFile == null || _resolvedChatId == null) return;
    context.read<ChatBloc>().add(ChatSendVideo(
      chatId: _resolvedChatId!,
      filePath: xFile.path,
      fileName: xFile.name,
    ));
  }

  Future<void> _pickContact() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['vcf'],
    );
    if (result == null || _resolvedChatId == null) return;
    final file = result.files.first;
    if (file.path == null) return;
    context.read<ChatBloc>().add(ChatSendFile(
      chatId: _resolvedChatId!,
      filePath: file.path!,
      fileName: file.name,
    ));
  }

  DateTime? _recordingStartedAt;

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      final duration = _recordingStartedAt != null
          ? DateTime.now().difference(_recordingStartedAt!).inSeconds
          : 0;
      _recordingStartedAt = null;
      setState(() => _isRecording = false);
      if (path != null && _resolvedChatId != null) {
        context.read<ChatBloc>().add(ChatSendAudio(
          chatId: _resolvedChatId!,
          filePath: path,
          duration: duration,
        ));
      }
    } else {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) return;
      final dir = await path_provider.getTemporaryDirectory();
      final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      _recordingStartedAt = DateTime.now();
      setState(() => _isRecording = true);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

// ── Messages List ──────────────────────────────────────────

class _MessagesList extends StatelessWidget {
  final String? chatId;
  final void Function(MessageModel msg)? onReplyMessage;
  const _MessagesList({this.chatId, this.onReplyMessage});

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.instance.currentUserId ?? '';
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (_, state) {
        if (state is ChatLoading || chatId == null) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (state is ChatLoaded) {
          if (state.messages.isEmpty) {
            return Center(
              child: Text('ابدأ المحادثة! 👋',
                  style: GoogleFonts.cairo(color: AppColors.textHint, fontSize: 16)),
            );
          }
          return ListView.builder(
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: state.messages.length,
            itemBuilder: (ctx, i) {
              final msg = state.messages[i];
              final isMine = msg.senderId == myUid;
              return MessageBubble(
                message: msg,
                isMine: isMine,
                onReply: (m) {
                  onReplyMessage?.call(m);
                },
                onDelete: (m) {
                  if (chatId != null) {
                    context.read<ChatBloc>().add(
                      ChatDeleteMessage(chatId: chatId!, messageId: m.id),
                    );
                  }
                },
              ).animate(delay: (i * 20).ms).fadeIn().slideY(begin: 0.1, end: 0);
            },
          );
        }
        return const SizedBox();
      },
    );
  }
}

// ── Typing Indicator ───────────────────────────────────────

class _TypingIndicatorBand extends StatelessWidget {
  final String? chatId;
  const _TypingIndicatorBand({this.chatId});

  @override
  Widget build(BuildContext context) {
    if (chatId == null) return const SizedBox();
    final myUid = AuthService.instance.currentUserId ?? '';
    return StreamBuilder<Map<String, bool>>(
      stream: ChatService.instance.watchTyping(chatId!),
      builder: (_, snap) {
        final typing = snap.data ?? {};
        final othersTyping = typing.entries
            .where((e) => e.key != myUid && e.value)
            .isNotEmpty;
        if (!othersTyping) return const SizedBox();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _TypingDots(),
              const SizedBox(width: 8),
              Text('يكتب...',
                  style: GoogleFonts.cairo(
                      color: AppColors.typing, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final delay = i * 0.3;
            final t = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            final size = 6.0 + (Curves.easeInOut.transform(
                  t < 0.5 ? t * 2 : (1 - t) * 2,
                ) * 3);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: AppColors.typing,
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}

// ── Reply Preview ──────────────────────────────────────────

class _ReplyPreview extends StatelessWidget {
  final MessageModel msg;
  final VoidCallback onCancel;
  const _ReplyPreview({required this.msg, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.card,
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg.senderName,
                    style: GoogleFonts.cairo(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Text(
                  msg.type == MessageType.image ? '📷 صورة' : msg.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.textHint),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

// ── Input Bar ──────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool showEmoji;
  final bool isRecording;
  final VoidCallback onSend;
  final VoidCallback onEmojiToggle;
  final VoidCallback onAttach;
  final VoidCallback onRecordToggle;
  final ValueChanged<String> onChanged;

  const _InputBar({
    required this.controller,
    required this.showEmoji,
    required this.isRecording,
    required this.onSend,
    required this.onEmojiToggle,
    required this.onAttach,
    required this.onRecordToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      color: AppColors.surface,
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              showEmoji ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
              color: AppColors.textSecondary,
            ),
            onPressed: onEmojiToggle,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textDirection: TextDirection.rtl,
              style: GoogleFonts.cairo(color: AppColors.textPrimary, fontSize: 15),
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'اكتب رسالة...',
                hintStyle: GoogleFonts.cairo(color: AppColors.textHint),
                fillColor: AppColors.card,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.attach_file_rounded, color: AppColors.textSecondary),
            onPressed: onAttach,
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              final hasText = value.text.trim().isNotEmpty;
              return GestureDetector(
                onTap: hasText ? onSend : onRecordToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isRecording ? AppColors.accent : AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isRecording ? AppColors.accent : AppColors.primary)
                            .withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    hasText
                        ? Icons.send_rounded
                        : isRecording
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;
  const _AttachOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 28))),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: GoogleFonts.cairo(
                  color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _UploadProgressBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (_, state) {
        if (state is! ChatLoaded || !state.isUploading) return const SizedBox();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: AppColors.card,
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'جاري الرفع...',
                style: GoogleFonts.cairo(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
