part of 'call_bloc.dart';

abstract class CallEvent {}

class CallStart extends CallEvent {
  final String targetUserId;
  final String targetUserName;
  final String? targetUserPhoto;
  final bool isVideo;
  CallStart({
    required this.targetUserId,
    required this.targetUserName,
    this.targetUserPhoto,
    required this.isVideo,
  });
}

class CallAccept extends CallEvent {
  final CallModel call;
  CallAccept(this.call);
}

class CallReject extends CallEvent {
  final String callId;
  CallReject(this.callId);
}

class CallEnd extends CallEvent {}
class CallToggleMic extends CallEvent {}
class CallToggleCamera extends CallEvent {}
class CallSwitchCamera extends CallEvent {}
class CallToggleSpeaker extends CallEvent {}

class _CallTick extends CallEvent {
  final Duration elapsed;
  _CallTick(this.elapsed);
}

class _CallSessionStarted extends CallEvent {
  final bool isVideo;
  final String roomName;
  _CallSessionStarted({required this.isVideo, required this.roomName});
}
