import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  final void Function(MessageModel) onReply;
  final void Function(MessageModel) onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.onReply,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeleted) return _DeletedBubble(isMine: isMine);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showOptions(context),
        child: Container(
          margin: EdgeInsets.only(
            top: 2,
            bottom: 2,
            left: isMine ? 60 : 8,
            right: isMine ? 8 : 60,
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Reply preview
              if (message.replyToContent != null)
                _ReplyChip(
                  senderName: message.replyToSenderName ?? '',
                  content: message.replyToContent!,
                  isMine: isMine,
                ),
              _buildBody(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (message.type) {
      case MessageType.image:
        return _ImageBubble(message: message, isMine: isMine);
      case MessageType.video:
        return _VideoBubble(message: message, isMine: isMine);
      case MessageType.audio:
        return _AudioBubble(message: message, isMine: isMine);
      case MessageType.file:
        return _FileBubble(message: message, isMine: isMine);
      case MessageType.location:
        return _LocationBubble(message: message, isMine: isMine);
      default:
        return _TextBubble(message: message, isMine: isMine);
    }
  }

  void _showOptions(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: AppColors.primary),
              title: Text('رد', style: GoogleFonts.cairo(color: AppColors.textPrimary)),
              onTap: () { Navigator.pop(context); onReply(message); },
            ),
            if (message.type == MessageType.text)
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: AppColors.secondary),
                title: Text('نسخ', style: GoogleFonts.cairo(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: message.content));
                },
              ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: AppColors.accent),
                title: Text('حذف', style: GoogleFonts.cairo(color: AppColors.accent)),
                onTap: () { Navigator.pop(context); onDelete(message); },
              ),
          ],
        ),
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  const _TextBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMine ? AppColors.sentBubble : AppColors.receivedBubble,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMine ? 18 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            message.content,
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 14, height: 1.5),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(message.timestamp),
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
              if (isMine) ...[
                const SizedBox(width: 4),
                Icon(
                  message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                  size: 14,
                  color: message.isRead ? AppColors.secondary : Colors.white60,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _ImageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  const _ImageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(backgroundColor: Colors.black, elevation: 0),
              body: PhotoView(imageProvider: CachedNetworkImageProvider(message.fileUrl!)),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: message.fileUrl ?? message.content,
          width: 220,
          height: 220,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 220,
            height: 220,
            color: AppColors.card,
            child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ),
          errorWidget: (_, __, ___) => Container(
            width: 220,
            height: 220,
            color: AppColors.card,
            child: const Icon(Icons.broken_image_rounded, color: AppColors.textHint),
          ),
        ),
      ),
    );
  }
}

class _VideoBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  const _VideoBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final url = message.fileUrl ?? message.content;
        final uri = Uri.parse(url);
        launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CachedNetworkImage(
              imageUrl: message.fileUrl ?? message.content,
              width: 220,
              height: 220,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 220,
                height: 220,
                color: AppColors.card,
                child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 220,
                height: 220,
                color: AppColors.card,
                child: const Icon(Icons.videocam_off_rounded, color: AppColors.textHint),
              ),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  const _AudioBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      width: 220,
      decoration: BoxDecoration(
        color: isMine ? AppColors.sentBubble : AppColors.receivedBubble,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${message.audioDuration ?? 0}s',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  const _FileBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFile(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        width: 220,
        decoration: BoxDecoration(
          color: isMine ? AppColors.sentBubble : AppColors.receivedBubble,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.insert_drive_file_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.fileName ?? 'ملف',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                  if (message.fileSize != null)
                    Text(
                      _formatSize(message.fileSize!),
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                ],
              ),
            ),
            const Icon(Icons.download_rounded, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }

  void _openFile(BuildContext context) async {
    final url = message.fileUrl;
    if (url != null) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

class _LocationBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMine;
  const _LocationBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(message.content);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        width: 230,
        decoration: BoxDecoration(
          color: isMine ? AppColors.sentBubble : AppColors.receivedBubble,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'موقع جغرافي',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'اضغط للفتح على الخريطة',
                    style: GoogleFonts.cairo(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeletedBubble extends StatelessWidget {
  final bool isMine;
  const _DeletedBubble({required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block_rounded, size: 14, color: AppColors.textHint),
            const SizedBox(width: 6),
            Text(
              'تم حذف هذه الرسالة',
              style: GoogleFonts.cairo(
                  color: AppColors.textHint,
                  fontSize: 13,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyChip extends StatelessWidget {
  final String senderName;
  final String content;
  final bool isMine;
  const _ReplyChip({
    required this.senderName,
    required this.content,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMine
            ? AppColors.primaryDark.withValues(alpha: 0.6)
            : AppColors.card.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          right: BorderSide(color: AppColors.secondary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: GoogleFonts.cairo(
                color: AppColors.secondary,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
          Text(
            content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
