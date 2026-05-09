import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/call_model.dart';
import '../../../data/services/notification_service.dart';
import '../bloc/call_bloc.dart';

class IncomingCallScreen extends StatefulWidget {
  final CallModel call;
  const IncomingCallScreen({super.key, required this.call});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  final _player = AudioPlayer();
  StreamSubscription? _callStatusSub;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _startRingtone();
    _vibrate();
    _watchCallStatus();
  }

  Future<void> _startRingtone() async {
    try {
      await _player.setAsset('assets/sounds/ringtone.wav');
      await _player.setVolume(1.0);
      await _player.setLoopMode(LoopMode.one);
      await _player.play();
    } catch (_) {
      // Asset not found or audio error — fail silently
    }
  }

  void _vibrate() {
    HapticFeedback.heavyImpact();
  }

  void _watchCallStatus() {
    _callStatusSub = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.call.id)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (!doc.exists) return;
      final status = doc.data()?['status'] as String?;
      // If caller cancelled or call ended while we're waiting
      if (status == 'ended' || status == 'rejected' || status == 'missed') {
        _cleanUpAndPop();
      }
    });
  }

  void _cleanUpAndPop() {
    _player.stop();
    NotificationService.instance.cancelCallNotification();
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _callStatusSub?.cancel();
    _player.stop();
    _player.dispose();
    NotificationService.instance.cancelCallNotification();
    super.dispose();
  }

  void _reject() {
    _player.stop();
    NotificationService.instance.cancelCallNotification();
    context.read<CallBloc>().add(CallReject(widget.call.id));
    context.pop();
  }

  void _accept() {
    _player.stop();
    NotificationService.instance.cancelCallNotification();
    context.read<CallBloc>().add(CallAccept(widget.call));
    final route = widget.call.type == CallType.video
        ? AppRouter.videoCall
        : AppRouter.voiceCall;
    context.go('$route/${widget.call.roomName ?? widget.call.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.callGradient),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 80),

              Text(
                widget.call.type == CallType.video
                    ? 'مكالمة فيديو واردة'
                    : 'مكالمة صوتية واردة',
                style: GoogleFonts.cairo(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ).animate().fadeIn(),

              const SizedBox(height: 24),

              // Pulsing avatar ring
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, child) {
                  final scale = 1.0 + _pulseCtrl.value * 0.12;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.callGreen
                                .withValues(alpha: 0.15 * (1 - _pulseCtrl.value)),
                          ),
                        ),
                      ),
                      child!,
                    ],
                  );
                },
                child: CircleAvatar(
                  radius: 70,
                  backgroundColor: AppColors.card,
                  backgroundImage: widget.call.callerPhoto != null
                      ? CachedNetworkImageProvider(widget.call.callerPhoto!)
                      : null,
                  child: widget.call.callerPhoto == null
                      ? Text(
                          widget.call.callerName.isNotEmpty
                              ? widget.call.callerName[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.poppins(
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

              const SizedBox(height: 24),

              Text(
                widget.call.callerName,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ).animate().fadeIn(delay: 200.ms),

              const Spacer(),

              // Reject / Accept
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CallBtn(
                      icon: Icons.call_end_rounded,
                      label: 'رفض',
                      color: AppColors.callRed,
                      onTap: _reject,
                    ),
                    _CallBtn(
                      icon: widget.call.type == CallType.video
                          ? Icons.videocam_rounded
                          : Icons.call_rounded,
                      label: 'قبول',
                      color: AppColors.callGreen,
                      onTap: _accept,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.5, end: 0),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }
}
