import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/ad_service.dart';
import '../../../data/services/livekit_service.dart';
import '../../../data/services/wakelock_service.dart';
import '../bloc/call_bloc.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomName;
  final UserModel? otherUser;

  const VideoCallScreen({super.key, required this.roomName, this.otherUser});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  EventsListener<RoomEvent>? _roomListener;

  @override
  void initState() {
    super.initState();
    WakelockService.instance.enable();
    final other = widget.otherUser;
    if (other != null) {
      context.read<CallBloc>().add(CallStart(
        targetUserId: other.uid,
        targetUserName: other.name,
        targetUserPhoto: other.photoUrl,
        isVideo: true,
      ));
    }
  }

  void _attachRoomListener() {
    if (_roomListener != null) return;
    final room = LiveKitService.instance.room;
    if (room == null) return;
    _roomListener = room.createListener();
    _roomListener!
      ..on<ParticipantConnectedEvent>((_) { if (mounted) setState(() {}); })
      ..on<ParticipantDisconnectedEvent>((_) { if (mounted) setState(() {}); })
      ..on<TrackSubscribedEvent>((_) { if (mounted) setState(() {}); })
      ..on<TrackUnsubscribedEvent>((_) { if (mounted) setState(() {}); })
      ..on<TrackMutedEvent>((_) { if (mounted) setState(() {}); })
      ..on<TrackUnmutedEvent>((_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _roomListener?.dispose();
    WakelockService.instance.disable();
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
        if (state is CallActive) {
          _attachRoomListener();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.callBg,
        body: BlocBuilder<CallBloc, CallState>(
          builder: (_, state) {
            return Stack(
              children: [
                // Remote video (full screen)
                _RemoteVideoView(room: LiveKitService.instance.room),

                // Dark gradient overlay at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 220,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC000000)],
                      ),
                    ),
                  ),
                ),

                // Local video (PiP)
                Positioned(
                  top: 60,
                  right: 16,
                  child: _LocalVideoView(room: LiveKitService.instance.room),
                ),

                // Caller info (top)
                Positioned(
                  top: 60,
                  left: 20,
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.otherUser?.name ?? 'مكالمة فيديو',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (state is CallActive)
                          Text(
                            _formatDuration(state.duration),
                            style: GoogleFonts.poppins(
                                color: Colors.white70, fontSize: 14),
                          ),
                        if (state is CallConnecting)
                          Text(
                            'جارٍ الاتصال...',
                            style: GoogleFonts.cairo(
                                color: Colors.white70, fontSize: 14),
                          ),
                        if (state is CallEnded)
                          Text(
                            _endedLabel(state.reason),
                            style: GoogleFonts.cairo(
                              color: _endedColor(state.reason),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ).animate().fadeIn().slideX(begin: -0.3, end: 0),

                // Controls
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: _Controls(state: state, isVideo: true),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _endedLabel(CallEndReason reason) {
    switch (reason) {
      case CallEndReason.noAnswer:  return 'لا يرد';
      case CallEndReason.rejected:  return 'رفض المكالمة';
      default:                      return '';
    }
  }

  Color _endedColor(CallEndReason reason) {
    switch (reason) {
      case CallEndReason.noAnswer:  return Colors.orangeAccent;
      case CallEndReason.rejected:  return Colors.redAccent;
      default:                      return Colors.white70;
    }
  }
}

class _RemoteVideoView extends StatelessWidget {
  final Room? room;
  const _RemoteVideoView({this.room});

  @override
  Widget build(BuildContext context) {
    if (room == null || room!.remoteParticipants.isEmpty) {
      return Container(
        color: AppColors.callBg,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    final participant = room!.remoteParticipants.values.first;
    final videoTracks = participant.videoTrackPublications
        .where((t) => !t.muted && t.track != null);

    if (videoTracks.isEmpty) {
      return Container(
        color: AppColors.callBg,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 56,
                backgroundColor: AppColors.card,
                child: Icon(Icons.videocam_off_rounded,
                    size: 36, color: AppColors.textHint),
              ),
              const SizedBox(height: 16),
              Text(
                'الكاميرا متوقفة',
                style: GoogleFonts.cairo(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return VideoTrackRenderer(videoTracks.first.track as VideoTrack);
  }
}

class _LocalVideoView extends StatelessWidget {
  final Room? room;
  const _LocalVideoView({this.room});

  @override
  Widget build(BuildContext context) {
    if (room == null) return const SizedBox();
    final localVideo = room!.localParticipant?.videoTrackPublications
        .where((t) => !t.muted && t.track != null)
        .firstOrNull;

    return Container(
      width: 100,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white30, width: 1.5),
        color: AppColors.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: localVideo != null
          ? VideoTrackRenderer(localVideo.track as VideoTrack)
          : const Center(
              child: Icon(Icons.person_rounded, color: Colors.white54, size: 36),
            ),
    ).animate().scale(duration: 400.ms, curve: Curves.elasticOut);
  }
}

class _Controls extends StatelessWidget {
  final CallState state;
  final bool isVideo;
  const _Controls({required this.state, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    final isMicOn = state is CallActive ? (state as CallActive).isMicOn : true;
    final isCamOn = state is CallActive ? (state as CallActive).isCameraOn : true;
    final isSpeakerOn = state is CallActive ? (state as CallActive).isSpeakerOn : false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlBtn(
          icon: isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded,
          color: isMicOn ? Colors.white24 : AppColors.accent.withValues(alpha: 0.3),
          iconColor: isMicOn ? Colors.white : AppColors.accent,
          onTap: () => context.read<CallBloc>().add(CallToggleMic()),
        ),
        const SizedBox(width: 20),
        _ControlBtn(
          icon: isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          color: isSpeakerOn ? AppColors.primary.withValues(alpha: 0.3) : Colors.white24,
          iconColor: isSpeakerOn ? AppColors.primary : Colors.white,
          onTap: () => context.read<CallBloc>().add(CallToggleSpeaker()),
        ),
        const SizedBox(width: 20),
        if (isVideo)
          _ControlBtn(
            icon: isCamOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            color: isCamOn ? Colors.white24 : AppColors.accent.withValues(alpha: 0.3),
            iconColor: isCamOn ? Colors.white : AppColors.accent,
            onTap: () => context.read<CallBloc>().add(CallToggleCamera()),
          ),
        if (isVideo) const SizedBox(width: 20),
        // End call
        GestureDetector(
          onTap: () => context.read<CallBloc>().add(CallEnd()),
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.callRed,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.callRed.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
          ),
        ),
        if (isVideo) ...[
          const SizedBox(width: 20),
          _ControlBtn(
            icon: Icons.flip_camera_ios_rounded,
            color: Colors.white24,
            iconColor: Colors.white,
            onTap: () => context.read<CallBloc>().add(CallSwitchCamera()),
          ),
        ],
      ],
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.4, end: 0);
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _ControlBtn({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}
