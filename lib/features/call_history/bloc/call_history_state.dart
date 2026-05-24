part of 'call_history_bloc.dart';

abstract class CallHistoryState {}

class CallHistoryInitial extends CallHistoryState {}

class CallHistoryLoading extends CallHistoryState {}

class CallHistoryLoaded extends CallHistoryState {
  final List<CallModel> calls;
  CallHistoryLoaded(this.calls);
}

class CallHistoryError extends CallHistoryState {
  final String message;
  CallHistoryError(this.message);
}
