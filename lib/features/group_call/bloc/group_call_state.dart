part of 'group_call_bloc.dart';

abstract class GroupCallState {}

class GroupCallIdle       extends GroupCallState {}
class GroupCallConnecting extends GroupCallState {}

class GroupCallActive extends GroupCallState {
  final bool     isMicOn;
  final bool     isCameraOn;
  final bool     isSpeakerOn;
  final bool     isVideo;
  final Duration duration;
  final String   roomName;
  final String   callId;
  final bool     isCreator;

  GroupCallActive({
    required this.isMicOn,
    required this.isCameraOn,
    required this.isSpeakerOn,
    required this.isVideo,
    required this.duration,
    required this.roomName,
    required this.callId,
    required this.isCreator,
  });

  GroupCallActive copyWith({
    bool?     isMicOn,
    bool?     isCameraOn,
    bool?     isSpeakerOn,
    Duration? duration,
  }) =>
      GroupCallActive(
        isMicOn:     isMicOn     ?? this.isMicOn,
        isCameraOn:  isCameraOn  ?? this.isCameraOn,
        isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
        isVideo:     isVideo,
        duration:    duration    ?? this.duration,
        roomName:    roomName,
        callId:      callId,
        isCreator:   isCreator,
      );
}

class GroupCallEnded extends GroupCallState {
  final Duration duration;
  GroupCallEnded(this.duration);
}

class GroupCallError extends GroupCallState {
  final String message;
  GroupCallError(this.message);
}
