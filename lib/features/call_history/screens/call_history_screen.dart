import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/constants/app_colors.dart';
import '../../../data/models/call_model.dart';
import '../../../data/services/auth_service.dart';
import '../bloc/call_history_bloc.dart';

class CallHistoryTab extends StatelessWidget {
  const CallHistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CallHistoryBloc, CallHistoryState>(
      builder: (ctx, state) {
        if (state is CallHistoryLoading || state is CallHistoryInitial) {
          return _LoadingShimmer();
        }
        if (state is CallHistoryError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.textHint, size: 48),
                const SizedBox(height: 12),
                Text(state.message,
                    style: GoogleFonts.cairo(color: AppColors.textHint)),
              ],
            ),
          );
        }
        if (state is CallHistoryLoaded) {
          if (state.calls.isEmpty) return _Empty();
          return _CallList(calls: state.calls);
        }
        return const SizedBox();
      },
    );
  }
}

// ── Call List ────────────────────────────────────────────────

class _CallList extends StatelessWidget {
  final List<CallModel> calls;
  const _CallList({required this.calls});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: calls.length,
      itemBuilder: (ctx, i) => _CallTile(call: calls[i])
          .animate(delay: (i * 40).ms)
          .fadeIn()
          .slideX(begin: -0.08, end: 0),
    );
  }
}

class _CallTile extends StatelessWidget {
  final CallModel call;
  const _CallTile({required this.call});

  @override
  Widget build(BuildContext context) {
    final myUid     = AuthService.instance.currentUserId ?? '';
    final isOutgoing = call.callerId == myUid;
    final otherName  = isOutgoing ? call.receiverName : call.callerName;
    final otherPhoto = isOutgoing ? call.receiverPhoto : call.callerPhoto;

    final (icon, iconColor) = _statusIcon(call.status, isOutgoing);
    final durationLabel     = _durationLabel(call.duration);
    final timeLabel         = timeago.format(call.timestamp, locale: 'ar');

    return Dismissible(
      key: ValueKey(call.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.callRed.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_rounded, color: AppColors.callRed),
      ),
      onDismissed: (_) =>
          context.read<CallHistoryBloc>().add(CallHistoryDeleteEntry(call.id)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onLongPress: () => _showOptions(context, call),
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.card,
          backgroundImage: otherPhoto != null
              ? CachedNetworkImageProvider(otherPhoto)
              : null,
          child: otherPhoto == null
              ? Text(
                  otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                )
              : null,
        ),
        title: Text(
          otherName.isNotEmpty ? otherName : 'مجهول',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              _statusLabel(call.status, isOutgoing),
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: iconColor,
              ),
            ),
            if (durationLabel != null) ...[
              Text(
                ' · $durationLabel',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(
              call.type == CallType.video
                  ? Icons.videocam_rounded
                  : Icons.call_rounded,
              size: 16,
              color: call.type == CallType.video
                  ? AppColors.primary
                  : AppColors.callGreen,
            ),
            const SizedBox(height: 4),
            Text(
              timeLabel,
              style: GoogleFonts.cairo(
                fontSize: 11,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _statusIcon(CallStatus status, bool isOutgoing) {
    switch (status) {
      case CallStatus.ended:
        return isOutgoing
            ? (Icons.call_made_rounded, AppColors.callGreen)
            : (Icons.call_received_rounded, AppColors.callGreen);
      case CallStatus.missed:
        return (Icons.call_missed_rounded, AppColors.callRed);
      case CallStatus.rejected:
        return (Icons.call_end_rounded, AppColors.callRed);
      case CallStatus.ringing:
      case CallStatus.accepted:
        return (Icons.call_rounded, AppColors.online);
      default:
        return (Icons.call_rounded, AppColors.textHint);
    }
  }

  String _statusLabel(CallStatus status, bool isOutgoing) {
    switch (status) {
      case CallStatus.ended:
        return isOutgoing ? 'صادرة' : 'واردة';
      case CallStatus.missed:
        return 'مكالمة فائتة';
      case CallStatus.rejected:
        return isOutgoing ? 'لم يُجب' : 'رفضت المكالمة';
      case CallStatus.ringing:
        return 'جارٍ الاتصال';
      case CallStatus.accepted:
        return 'مقبولة';
      default:
        return '';
    }
  }

  String? _durationLabel(int? seconds) {
    if (seconds == null || seconds == 0) return null;
    if (seconds < 60) return '${seconds}ث';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s > 0 ? '${m}د ${s}ث' : '${m}د';
  }

  void _showOptions(BuildContext context, CallModel call) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading:
                const Icon(Icons.delete_rounded, color: AppColors.callRed),
            title: Text('حذف من السجل',
                style: GoogleFonts.cairo(color: AppColors.callRed)),
            onTap: () {
              Navigator.pop(context);
              context
                  .read<CallHistoryBloc>()
                  .add(CallHistoryDeleteEntry(call.id));
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📞', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            'لا توجد مكالمات بعد',
            style: GoogleFonts.cairo(
              fontSize: 17,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ستظهر هنا مكالماتك الواردة والصادرة',
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shimmer Loading ───────────────────────────────────────────

class _LoadingShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.card,
      highlightColor: AppColors.surface,
      child: ListView.builder(
        itemCount: 8,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (_, __) => ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: const CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white,
          ),
          title: Container(
            height: 14,
            width: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          subtitle: Container(
            height: 11,
            width: 80,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}
