import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/group_call_model.dart';
import '../../../data/services/auth_service.dart';
import '../bloc/group_call_bloc.dart';

class IncomingGroupCallScreen extends StatelessWidget {
  final GroupCallModel call;
  const IncomingGroupCallScreen({super.key, required this.call});

  @override
  Widget build(BuildContext context) {
    final isVideo = call.callType == GroupCallType.video;
    final others  = call.participants
        .where((p) => p.uid != call.createdBy)
        .take(3)
        .toList();

    return BlocListener<GroupCallBloc, GroupCallState>(
      listener: (ctx, state) {
        if (state is GroupCallActive) {
          ctx.pushReplacement(AppRouter.groupCall);
        } else if (state is GroupCallError) {
          ctx.pop();
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(state.message, style: GoogleFonts.cairo()),
              backgroundColor: AppColors.callRed,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.callBg,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Call type badge ──────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: isVideo
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.callGreen.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVideo
                          ? Icons.videocam_rounded
                          : Icons.call_rounded,
                      color: isVideo
                          ? AppColors.primaryLight
                          : AppColors.callGreen,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isVideo ? 'مكالمة فيديو جماعية' : 'مكالمة صوتية جماعية',
                      style: GoogleFonts.cairo(
                        color: isVideo
                            ? AppColors.primaryLight
                            : AppColors.callGreen,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: -0.3, end: 0),

              const SizedBox(height: 32),

              // ── Creator avatar ──────────────────────────────
              CircleAvatar(
                radius: 52,
                backgroundColor: AppColors.card,
                backgroundImage: call.creatorPhoto != null
                    ? CachedNetworkImageProvider(call.creatorPhoto!)
                    : null,
                child: call.creatorPhoto == null
                    ? Text(
                        _initials(call.creatorName),
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              )
                  .animate()
                  .scale(
                      duration: 500.ms,
                      begin: const Offset(0.7, 0.7),
                      curve: Curves.elasticOut),

              const SizedBox(height: 20),

              // ── Creator name ────────────────────────────────
              Text(
                call.creatorName,
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 8),

              // ── Participant count ───────────────────────────
              Text(
                _participantLabel(call.participants.length),
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: Colors.white60,
                ),
              ).animate().fadeIn(delay: 300.ms),

              // ── Other participant avatars ───────────────────
              if (others.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: others.map((p) {
                    return Container(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 4),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.card,
                        backgroundImage: p.photo != null
                            ? CachedNetworkImageProvider(p.photo!)
                            : null,
                        child: p.photo == null
                            ? Text(
                                _initials(p.name),
                                style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.secondary),
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ).animate().fadeIn(delay: 400.ms),
              ],

              const Spacer(flex: 3),

              // ── Buttons ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Decline
                    _RoundButton(
                      icon: Icons.call_end_rounded,
                      color: AppColors.callRed,
                      label: 'رفض',
                      onTap: () async {
                        await _decline(context);
                        if (context.mounted) context.pop();
                      },
                    ),

                    const SizedBox(width: 40),

                    // Accept
                    BlocBuilder<GroupCallBloc, GroupCallState>(
                      builder: (ctx, state) {
                        if (state is GroupCallConnecting) {
                          return const SizedBox(
                            width: 72,
                            height: 72,
                            child: CircularProgressIndicator(
                                color: AppColors.callGreen),
                          );
                        }
                        return _RoundButton(
                          icon: isVideo
                              ? Icons.videocam_rounded
                              : Icons.call_rounded,
                          color: AppColors.callGreen,
                          label: 'قبول',
                          onTap: () => ctx
                              .read<GroupCallBloc>()
                              .add(GroupCallJoin(call)),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _decline(BuildContext context) async {
    final myUid = AuthService.instance.currentUserId;
    if (myUid == null) return;
    try {
      final ref = FirebaseFirestore.instance
          .collection('group_calls')
          .doc(call.id);
      final doc = await ref.get();
      if (!doc.exists) return;
      final raw = (doc.data()!['participants'] as List<dynamic>)
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();
      final idx = raw.indexWhere((p) => p['uid'] == myUid);
      if (idx != -1) raw[idx] = {...raw[idx], 'status': 'declined'};
      await ref.update({'participants': raw});
    } catch (_) {}
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  static String _participantLabel(int count) {
    if (count <= 1) return 'مكالمة جماعية';
    return 'أنت + ${count - 1} ${count == 2 ? 'شخص آخر' : 'أشخاص آخرين'}';
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _RoundButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: GoogleFonts.cairo(
              color: Colors.white70, fontSize: 13),
        ),
      ],
    )
        .animate()
        .scale(
            duration: 400.ms,
            begin: const Offset(0.6, 0.6),
            curve: Curves.elasticOut)
        .fadeIn();
  }
}
