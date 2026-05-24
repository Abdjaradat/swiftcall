part of 'call_history_bloc.dart';

abstract class CallHistoryEvent {}

class CallHistoryLoad extends CallHistoryEvent {}

class CallHistoryDeleteEntry extends CallHistoryEvent {
  final String callId;
  CallHistoryDeleteEntry(this.callId);
}

class CallHistoryClearAll extends CallHistoryEvent {}

class _CallHistoryUpdated extends CallHistoryEvent {
  final List<CallModel> calls;
  _CallHistoryUpdated(this.calls);
}
