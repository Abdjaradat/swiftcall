part of 'group_call_bloc.dart';

abstract class GroupCallEvent {}

class GroupCallCreate extends GroupCallEvent {
  final List<UserModel> participants;
  final bool isVideo;
  GroupCallCreate({required this.participants, required this.isVideo});
}

class GroupCallJoin extends GroupCallEvent {
  final GroupCallModel call;
  GroupCallJoin(this.call);
}

class GroupCallLeave extends GroupCallEvent {}

class GroupCallToggleMic     extends GroupCallEvent {}
class GroupCallToggleCamera  extends GroupCallEvent {}
class GroupCallSwitchCamera  extends GroupCallEvent {}
class GroupCallToggleSpeaker extends GroupCallEvent {}

class _GroupCallTick extends GroupCallEvent {
  final Duration elapsed;
  _GroupCallTick(this.elapsed);
}
