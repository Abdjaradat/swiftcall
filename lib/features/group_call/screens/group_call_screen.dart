import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/services/livekit_service.dart';
import '../bloc/group_call_bloc.dart';

class GroupCallScreen extends StatefulWidget {
  const GroupCallScreen({super.key});

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  EventsListener<RoomEvent>? _roomListener;

  @override
  void initState() {
    super.initState();
    _attachRoomListener();
  }

  void _attachRoomListener() {
    final room = LiveKitService.instance.room;
    if (room == null || _roomListener != null) return;
    _roomListener = room.createListener()
      ..on<ParticipantConnectedEvent>((_)    { if (mounted) setState(() {}); })
      ..on<ParticipantDisconnectedEvent>((_) { if (mounted) setState(() {}); })
      ..on<TrackSubscribedEvent>((_)         { if (mounted) setState(() {}); })
      ..on<TrackUnsubscribedEvent>((_)       { if (mounted) setState(() {}); })
      ..on<TrackMutedEvent>((_)              { if (mounted) setState(() {}); })
      ..on<TrackUnmutedEvent>((_)            { if (mounted) setState(() {}); })
      ..on<ActiveSpeakersChangedEvent>((_)   { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _roomListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GroupCallBloc, GroupCallState>(
      listener: (ctx, state) {
        if (state is GroupCallEnded || state is GroupCallError) {
          ctx.pop();
        }
        if (state is GroupCallActive) {
          _attachRoomListener();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.callBg,
        body: BlocBuilder<GroupCallBloc, GroupCallState>(
          builder: (_, state) {
            final isActive = state is GroupCallActive;
            final isVideo  = isActive ? state.isVideo  : false;

            return Stack(
              children: [
                // ── Main participant grid ──────────────────────
                Positioned.fill(
                  child: _buildGrid(isVideo),
                ),

                // ── Bottom gradient ────────────────────────────
                Positioned(
                  bottom: 0, left: 0, right: 0, height: 220,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end:   Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xDD000000)],
                      ),
                    ),
                  ),
                ),

                // ── Local PiP (video only) ─────────────────────
                if (isVideo)
                  Positioned(
                    top: 60,
                    right: 16,
                    child: _LocalPip()
                        .animate()
                        .scale(duration: 400.ms, curve: Curves.elasticOut),
                  ),

                // ── Header: title + duration ───────────────────
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          isVideo ? 16 : 16, 16, isVideo ? 140 : 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مكالمة جماعية',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (state is GroupCallActive)
                            Text(
                              _formatDuration(state.duration),
                              style: GoogleFonts.poppins(
                                  color: Colors.white60, fontSize: 13),
                            ),
                          if (state is GroupCallConnecting)
                            Text(
                              'جارٍ الاتصال...',
                              style: GoogleFonts.cairo(
                                  color: Colors.white60, fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn().slideX(begin: -0.2, end: 0),

                // ── Controls ───────────────────────────────────
                Positioned(
                  bottom: 40, left: 0, right: 0,
                  child: _GroupCallControls(
                    state:   state,
                    isVideo: isVideo,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGrid(bool isVideo) {
    final room    = LiveKitService.instance.room;
    final remotes = room?.remoteParticipants.values.toList() ?? [];

    if (remotes.isEmpty) {
      return _WaitingView(isVideo: isVideo);
    }

    if (remotes.length == 1) {
      return _SingleRemote(participant: remotes[0], isVideo: isVideo);
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(4, 80, 4, 200),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:  2,
        childAspectRatio: 3 / 4,
        crossAxisSpacing: 4,
        mainAxisSpacing:  4,
      ),
      itemCount: remotes.length,
      itemBuilder: (_, i) =>
          _ParticipantTile(participant: remotes[i], isVideo: isVideo),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Waiting view ─────────────────────────────────────────────────────────────

class _WaitingView extends StatelessWidget {
  final bool isVideo;
  const _WaitingView({required this.isVideo});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.callBg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
              child: Icon(
                isVideo
                    ? Icons.videocam_rounded
                    : Icons.record_voice_over_rounded,
                color: AppColors.primary,
                size: 36,
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                    duration: 1000.ms,
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.1, 1.1),
                    curve: Curves.easeInOut),
            const SizedBox(height: 20),
            Text(
              'في انتظار الانضمام...',
              style: GoogleFonts.cairo(color: Colors.white60, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Single remote (full screen) ───────────────────────────────────────────────

class _SingleRemote extends StatelessWidget {
  final RemoteParticipant participant;
  final bool isVideo;
  const _SingleRemote({required this.participant, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    if (!isVideo) {
      return _AudioTile(participant: participant, large: true);
    }

    final videoTrack = participant.videoTrackPublications
        .where((t) => !t.muted && t.track != null)
        .firstOrNull;

    if (videoTrack == null) {
      return Container(
        color: AppColors.callBg,
        child: Center(child: _AudioTile(participant: participant, large: true)),
      );
    }
    return VideoTrackRenderer(videoTrack.track as VideoTrack);
  }
}

// ── Grid participant tile ─────────────────────────────────────────────────────

class _ParticipantTile extends StatelessWidget {
  final RemoteParticipant participant;
  final bool isVideo;
  const _ParticipantTile(
      {required this.participant, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    final videoTrack = participant.videoTrackPublications
        .where((t) => !t.muted && t.track != null)
        .firstOrNull;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video or avatar
          if (isVideo && videoTrack != null)
            VideoTrackRenderer(videoTrack.track as VideoTrack)
          else
            Container(
              color: AppColors.card,
              child: Center(
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.surface,
                  child: Text(
                    _initials(participant.name),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),

          // Name + mic indicator
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xBB000000)],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      participant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (!participant.isMicrophoneEnabled())
                    const Icon(Icons.mic_off_rounded,
                        size: 12, color: Colors.redAccent),
                ],
              ),
            ),
          ),

          // Speaking glow
          if (participant.isSpeaking)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.callGreen, width: 2.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ── Audio-only tile (for voice calls) ────────────────────────────────────────

class _AudioTile extends StatelessWidget {
  final RemoteParticipant participant;
  final bool large;
  const _AudioTile({required this.participant, this.large = false});

  @override
  Widget build(BuildContext context) {
    final radius = large ? 52.0 : 28.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: participant.isSpeaking
                ? [
                    BoxShadow(
                        color: AppColors.callGreen.withValues(alpha: 0.6),
                        blurRadius: 20)
                  ]
                : [],
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.surface,
            child: Text(
              _initials(participant.name),
              style: GoogleFonts.poppins(
                fontSize: large ? 26 : 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              participant.name,
              style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: large ? 14 : 11),
            ),
            if (!participant.isMicrophoneEnabled()) ...[
              const SizedBox(width: 4),
              const Icon(Icons.mic_off_rounded,
                  size: 12, color: Colors.redAccent),
            ],
          ],
        ),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ── Local PiP ─────────────────────────────────────────────────────────────────

class _LocalPip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final room       = LiveKitService.instance.room;
    final localVideo = room?.localParticipant?.videoTrackPublications
        .where((t) => !t.muted && t.track != null)
        .firstOrNull;

    return Container(
      width:  100,
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
              child: Icon(Icons.person_rounded,
                  color: Colors.white54, size: 36),
            ),
    );
  }
}

// ── Controls ──────────────────────────────────────────────────────────────────

class _GroupCallControls extends StatelessWidget {
  final GroupCallState state;
  final bool isVideo;
  const _GroupCallControls({required this.state, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    final isMicOn =
        state is GroupCallActive ? (state as GroupCallActive).isMicOn : true;
    final isCamOn =
        state is GroupCallActive ? (state as GroupCallActive).isCameraOn : true;
    final isSpeakerOn =
        state is GroupCallActive ? (state as GroupCallActive).isSpeakerOn : false;
    final isCreator =
        state is GroupCallActive ? (state as GroupCallActive).isCreator : false;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Btn(
              icon: isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded,
              color: isMicOn
                  ? Colors.white24
                  : AppColors.accent.withValues(alpha: 0.3),
              iconColor: isMicOn ? Colors.white : AppColors.accent,
              onTap: () =>
                  context.read<GroupCallBloc>().add(GroupCallToggleMic()),
            ),
            const SizedBox(width: 16),
            _Btn(
              icon: isSpeakerOn
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: isSpeakerOn
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.white24,
              iconColor:
                  isSpeakerOn ? AppColors.primary : Colors.white,
              onTap: () =>
                  context.read<GroupCallBloc>().add(GroupCallToggleSpeaker()),
            ),
            if (isVideo) ...[
              const SizedBox(width: 16),
              _Btn(
                icon: isCamOn
                    ? Icons.videocam_rounded
                    : Icons.videocam_off_rounded,
                color: isCamOn
                    ? Colors.white24
                    : AppColors.accent.withValues(alpha: 0.3),
                iconColor: isCamOn ? Colors.white : AppColors.accent,
                onTap: () =>
                    context.read<GroupCallBloc>().add(GroupCallToggleCamera()),
              ),
            ],
            const SizedBox(width: 16),

            // End / Leave button
            GestureDetector(
              onTap: () =>
                  context.read<GroupCallBloc>().add(GroupCallLeave()),
              child: Container(
                width:  68,
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
                child:
                    const Icon(Icons.call_end_rounded,
                        color: Colors.white, size: 28),
              ),
            ),

            if (isVideo) ...[
              const SizedBox(width: 16),
              _Btn(
                icon: Icons.flip_camera_ios_rounded,
                color: Colors.white24,
                iconColor: Colors.white,
                onTap: () =>
                    context.read<GroupCallBloc>().add(GroupCallSwitchCamera()),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          isCreator ? 'إنهاء للجميع' : 'مغادرة المكالمة',
          style: GoogleFonts.cairo(color: Colors.white38, fontSize: 11),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.4, end: 0);
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;
  const _Btn({
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
        width:  56,
        height: 56,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}
