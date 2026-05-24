import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/call_model.dart';
import '../../../data/services/auth_service.dart';

part 'call_history_event.dart';
part 'call_history_state.dart';

class CallHistoryBloc extends Bloc<CallHistoryEvent, CallHistoryState> {
  StreamSubscription? _s1;
  StreamSubscription? _s2;
  List<CallModel> _asCaller   = [];
  List<CallModel> _asReceiver = [];

  CallHistoryBloc() : super(CallHistoryInitial()) {
    on<CallHistoryLoad>(_onLoad);
    on<_CallHistoryUpdated>(_onUpdated);
    on<CallHistoryDeleteEntry>(_onDelete);
    on<CallHistoryClearAll>(_onClearAll);
  }

  void _onUpdated(_CallHistoryUpdated event, Emitter<CallHistoryState> emit) {
    emit(CallHistoryLoaded(event.calls));
  }

  Future<void> _onLoad(
    CallHistoryLoad event,
    Emitter<CallHistoryState> emit,
  ) async {
    emit(CallHistoryLoading());

    final uid = AuthService.instance.currentUserId;
    if (uid == null) {
      emit(CallHistoryError('غير مسجل الدخول'));
      return;
    }

    // Cancel any previous subscriptions
    _s1?.cancel();
    _s2?.cancel();
    _asCaller   = [];
    _asReceiver = [];

    List<CallModel> _parse(QuerySnapshot snap) => snap.docs
        .map((d) => CallModel.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();

    void _push() {
      final seen   = <String>{};
      final merged = <CallModel>[];
      for (final c in [..._asCaller, ..._asReceiver]) {
        if (seen.add(c.id)) merged.add(c);
      }
      merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      add(_CallHistoryUpdated(merged));
    }

    _s1 = FirebaseFirestore.instance
        .collection('calls')
        .where('callerId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .listen((snap) {
      _asCaller = _parse(snap);
      _push();
    }, onError: (_) {});

    _s2 = FirebaseFirestore.instance
        .collection('calls')
        .where('receiverId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(200)
        .snapshots()
        .listen((snap) {
      _asReceiver = _parse(snap);
      _push();
    }, onError: (_) {});
  }

  Future<void> _onDelete(
    CallHistoryDeleteEntry event,
    Emitter<CallHistoryState> emit,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('calls')
          .doc(event.callId)
          .delete();
    } catch (_) {}
  }

  Future<void> _onClearAll(
    CallHistoryClearAll event,
    Emitter<CallHistoryState> emit,
  ) async {
    final uid = AuthService.instance.currentUserId;
    if (uid == null) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      final q1 = await FirebaseFirestore.instance
          .collection('calls')
          .where('callerId', isEqualTo: uid)
          .get();
      for (final d in q1.docs) batch.delete(d.reference);

      final q2 = await FirebaseFirestore.instance
          .collection('calls')
          .where('receiverId', isEqualTo: uid)
          .get();
      for (final d in q2.docs) batch.delete(d.reference);

      await batch.commit();
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _s1?.cancel();
    _s2?.cancel();
    return super.close();
  }
}
