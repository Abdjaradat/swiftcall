import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/ad_service.dart';
import '../bloc/call_bloc.dart';

class VoiceCallScreen extends StatefulWidget {
  final String roomName;
  final UserModel? otherUser;

  const VoiceCallScreen({super.key, required this.roomName, this.otherUser});

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    final other = widget.otherUser;
    if (other != null) {
      context.read<CallBloc>().add(CallStart(
        targetUserId: other.uid,
        targetUserName: other.name,
        targetUserPhoto: other.photoUrl,
        isVideo: false,
      ));
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CallBloc, CallState>(
      listener: (ctx, state) {
        if (state is CallFailed) {
          ctx.pop();
          return;
        }
        if (state is CallEnded) {
          final reason = state.reason;
          if (reason == CallEndReason.normal || reason == CallEndReason.cancelled) {
            ctx.pop();
            AdService.instance.showInterstitialAd();
            return;
          }
          Future.delayed(const Duration(seconds: 2), () {
            if (ctx.mounted) {
              ctx.pop();
              AdService.instance.showInterstitialAd();
            }
          });
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.callGradient),
          child: BlocBuilder<CallBloc, CallState>(
            builder: (_, state) {
              return SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 60),

                    // Avatar with pulse
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer pulse ring
                            Container(
                              width: 160 + _pulseCtrl.value * 20,
                              height: 160 + _pulseCtrl.value * 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withValues(alpha: 
                                  0.1 * (1 - _pulseCtrl.value),
                                ),
                              ),
                            ),
                            // Inner ring
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withValues(alpha: 0.15),
                              ),
                            ),
                            child!,
                          ],
                        );
                      },
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: AppColors.card,
                        backgroundImage: widget.otherUser?.photoUrl != null
                            ? CachedNetworkImageProvider(widget.otherUser!.photoUrl!)
                            : null,
                        child: widget.otherUser?.photoUrl == null
                            ? Text(
                                widget.otherUser?.initials ?? '?',
                                style: GoogleFonts.poppins(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                    ),

                    const SizedBox(height: 32),

                    Text(
                      widget.otherUser?.name ?? 'مكالمة صوتية',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ).animate().fadeIn().slideY(begin: 0.3, end: 0),

                    const SizedBox(height: 8),

                    _StatusText(state: state),

                    const Spacer(),

                    // Controls
                    _VoiceControls(state: state),

                    const SizedBox(height: 60),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  final CallState state;
  const _StatusText({required this.state});

  @override
  Widget build(BuildContext context) {
    String text;
    Color color = Colors.white60;

    if (state is CallConnecting) {
      text = 'جارٍ الاتصال...';
    } else if (state is CallActive) {
      final d = (state as CallActive).duration;
      final m = d.inMinutes.toString().padLeft(2, '0');
      final s = (d.inSeconds % 60).toString().padLeft(2, '0');
      text = '$m:$s';
    } else if (state is CallEnded) {
      switch ((state as CallEnded).reason) {
        case CallEndReason.noAnswer:
          text  = 'لا يرد';
          color = Colors.orangeAccent;
        case CallEndReason.rejected:
          text  = 'رفض المكالمة';
          color = Colors.redAccent;
        default:
          text = '';
      }
    } else {
      text = '';
    }

    return Text(
      text,
      style: GoogleFonts.poppins(color: color, fontSize: 16),
    );
  }
}

class _VoiceControls extends StatelessWidget {
  final CallState state;
  const _VoiceControls({required this.state});

  @override
  Widget build(BuildContext context) {
    final isMicOn = state is CallActive ? (state as CallActive).isMicOn : true;
    final isSpeakerOn = state is CallActive ? (state as CallActive).isSpeakerOn : false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _VoiceBtn(
          icon: isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          label: 'سماعة',
          active: isSpeakerOn,
          onTap: () => context.read<CallBloc>().add(CallToggleSpeaker()),
        ),
        const SizedBox(width: 24),
        // End call
        GestureDetector(
          onTap: () => context.read<CallBloc>().add(CallEnd()),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.callRed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.callRed.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(width: 24),
        _VoiceBtn(
          icon: isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded,
          label: 'ميكروفون',
          active: isMicOn,
          onTap: () => context.read<CallBloc>().add(CallToggleMic()),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.5, end: 0);
  }
}

class _VoiceBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _VoiceBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withValues(alpha: 0.15)
                  : AppColors.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: active ? Colors.white : AppColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(label,
              style:
                  GoogleFonts.cairo(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}
