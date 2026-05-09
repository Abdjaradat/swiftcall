part of 'call_bloc.dart';

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
  CallEnded(this.duration);
}

class CallFailed extends CallState {
  final String reason;
  CallFailed(this.reason);
}
