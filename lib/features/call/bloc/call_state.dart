part of 'call_bloc.dart';

/// Why a call ended — used by the UI to show a brief dismissal message.
enum CallEndReason {
  /// Normal end: both parties were connected, caller/receiver hung up.
  normal,
  /// Caller gave up / caller cancelled while still ringing.
  cancelled,
  /// Receiver did not answer in time (local 45 s timer or Cloud Function).
  noAnswer,
  /// Receiver explicitly rejected the call.
  rejected,
}

abstract class CallState {}

class CallIdle extends CallState {}
class CallConnecting extends CallState {}

class CallActive extends CallState {
  final bool isMicOn;
  final bool isCameraOn;
  final bool isSpeakerOn;
  final bool isVideo;
  final Duration duration;
  final String roomName;

  CallActive({
    required this.isMicOn,
    required this.isCameraOn,
    required this.isSpeakerOn,
    required this.isVideo,
    required this.duration,
    required this.roomName,
  });

  CallActive copyWith({
    bool? isMicOn,
    bool? isCameraOn,
    bool? isSpeakerOn,
    Duration? duration,
  }) {
    return CallActive(
      isMicOn: isMicOn ?? this.isMicOn,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isVideo: isVideo,
      duration: duration ?? this.duration,
      roomName: roomName,
    );
  }
}

class CallEnded extends CallState {
  final Duration duration;
  final CallEndReason reason;
  CallEnded(this.duration, {this.reason = CallEndReason.normal});
}

class CallFailed extends CallState {
  final String reason;
  CallFailed(this.reason);
}
