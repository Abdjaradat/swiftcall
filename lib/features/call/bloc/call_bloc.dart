import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/call_model.dart';
import '../../../data/models/token_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/livekit_service.dart';
import '../../../data/services/token_service.dart';
import '../../../services/call_manager.dart';

part 'call_event.dart';
part 'call_state.dart';

class CallBloc extends Bloc<CallEvent, CallState> {
  Timer? _durationTimer;

  /// Fires after [AppConstants.callTimeout] when the callee never answers.
  /// Writes `status: "missed"` to Firestore so the receiver sees a missed-call
  /// entry in their history.  cancelCallNotification Cloud Function then sends
  /// call_cancelled FCM to both parties, dismissing their UIs.
  Timer? _ringTimer;

  StreamSubscription? _callStatusSub;
  EventsListener<RoomEvent>? _roomListener;
  Duration _elapsed = Duration.zero;
  String?  _activeCallId;

  /// True once the remote participant joins LiveKit and the call goes active.
  bool _wasActive = false;

  /// Stored at session start so token charging works correctly after the
  /// BLoC emits CallEnded (at which point state.isVideo is unavailable).
  bool _isVideo = false;

  /// True when the remote side already wrote a terminal status (rejected /
  /// missed).  Prevents _onEnd from overwriting it with "cancelled"/"ended".
  bool _skipFirestoreWrite = false;

  /// Reason to pass to [CallEnded] so the UI can show a dismissal message.
  CallEndReason _endReason = CallEndReason.normal;

  CallBloc() : super(CallIdle()) {
    on<CallStart>(_onStart);
    on<CallAccept>(_onAccept);
    on<CallReject>(_onReject);
    on<CallEnd>(_onEnd);
    on<CallToggleMic>(_onToggleMic);
    on<CallToggleCamera>(_onToggleCamera);
    on<CallSwitchCamera>(_onSwitchCamera);
    on<CallToggleSpeaker>(_onToggleSpeaker);
    on<_CallTick>(_onTick);
    on<_CallSessionStarted>(_onSessionStarted);
  }

  void _onTick(_CallTick event, Emitter<CallState> emit) {
    if (state is CallActive) {
      emit((state as CallActive).copyWith(duration: event.elapsed));
    }
  }

  void _onSessionStarted(_CallSessionStarted event, Emitter<CallState> emit) {
    _startSession(emit, event.isVideo, event.roomName);
  }

  Future<void> _onStart(CallStart event, Emitter<CallState> emit) async {
    emit(CallConnecting());
    await _requestCallPermissions(event.isVideo);

    final me = await AuthService.instance.getCurrentUserModel();
    if (me == null) {
      emit(CallFailed('لم يتم التعرف على المستخدم'));
      return;
    }

    final roomName = const Uuid().v4().replaceAll('-', '').substring(0, 12);
    final callId   = const Uuid().v4();

    final call = CallModel(
      id: callId,
      callerId: me.uid,
      callerName: me.name,
      callerPhoto: me.photoUrl,
      receiverId: event.targetUserId,
      receiverName: event.targetUserName,
      receiverPhoto: event.targetUserPhoto,
      type: event.isVideo ? CallType.video : CallType.audio,
      status: CallStatus.ringing,
      timestamp: DateTime.now(),
      roomName: roomName,
    );

    try {
      await FirebaseFirestore.instance
          .collection('calls')
          .doc(callId)
          .set(call.toMap());
      _activeCallId = callId;
    } catch (e) {
      emit(CallFailed('فشل إنشاء المكالمة: تحقق من قواعد Firestore'));
      return;
    }

    final room = await LiveKitService.instance.connectToRoom(
      roomName: roomName,
      identity: me.uid,
      videoEnabled: event.isVideo,
    );
    if (room == null) {
      emit(CallFailed('فشل الاتصال بالغرفة'));
      return;
    }

    // ── Firestore listener: remote rejected / missed / ended → dismiss caller UI ──
    _callStatusSub?.cancel();
    _callStatusSub = FirebaseFirestore.instance
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((doc) {
      print('🟢 CALLER Listener: doc.exists=${doc.exists}, status=${doc.data()?['status']}');
      if (!doc.exists || _activeCallId == null) return;
      final status = doc.data()?['status'] as String?;
      if (status == 'rejected') {
        print('🟢 CALLER detected rejected');
        _skipFirestoreWrite = true;
        _endReason = CallEndReason.rejected;
        add(CallEnd());
      } else if (status == 'missed') {
        print('🟢 CALLER detected missed');
        _skipFirestoreWrite = true;
        _endReason = CallEndReason.noAnswer;
        add(CallEnd());
      } else if (status == 'ended') {
        print('🟢 CALLER detected ended');
        _skipFirestoreWrite = true;
        _endReason = CallEndReason.normal;
        add(CallEnd());
      }
    });

    // ── Local ring timer: write "missed" after 45 s if unanswered ─────────
    // Complements the Cloud Function timeout (every ~1 min) so the caller's
    // UI closes after exactly 45 s with a "لا يرد" message.
    _ringTimer?.cancel();
    _ringTimer = Timer(AppConstants.callTimeout, () async {
      if (_activeCallId == null || _wasActive) return;
      _skipFirestoreWrite = true;
      _endReason = CallEndReason.noAnswer;
      try {
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(_activeCallId)
            .update({'status': 'missed'});
      } catch (_) {}
      // The Firestore listener above will see 'missed' and fire add(CallEnd()).
      // Belt-and-suspenders: fire directly too in case the stream is slow.
      if (!isClosed) add(CallEnd());
    });

    _watchForRemoteParticipant(room, event.isVideo, roomName);
  }

  void _watchForRemoteParticipant(Room room, bool isVideo, String roomName) {
    _roomListener?.dispose();
    _roomListener = room.createListener();

    // Race: receiver might have joined before we set up the listener
    if (room.remoteParticipants.isNotEmpty) {
      _roomListener!.dispose();
      _roomListener = null;
      add(_CallSessionStarted(isVideo: isVideo, roomName: roomName));
      return;
    }

    _roomListener!.on<ParticipantConnectedEvent>((_) {
      _roomListener?.dispose();
      _roomListener = null;
      add(_CallSessionStarted(isVideo: isVideo, roomName: roomName));
    });
  }

  Future<void> _onAccept(CallAccept event, Emitter<CallState> emit) async {
    emit(CallConnecting());
    _ringTimer?.cancel();
    _ringTimer = null;

    await _requestCallPermissions(event.call.type == CallType.video);

    final me = await AuthService.instance.getCurrentUserModel();
    if (me == null || event.call.roomName == null) {
      emit(CallFailed('بيانات المكالمة غير مكتملة'));
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('calls')
          .doc(event.call.id)
          .update({'status': 'accepted'});
      _activeCallId = event.call.id;
    } catch (_) {
      // Permission failure — continue connecting anyway
    }

    final room = await LiveKitService.instance.connectToRoom(
      roomName: event.call.roomName!,
      identity: me.uid,
      videoEnabled: event.call.type == CallType.video,
    );
    if (room == null) {
      emit(CallFailed('فشل الاتصال'));
      return;
    }

    // ── Firestore listener: caller ended / cancelled → dismiss receiver UI ──
    _callStatusSub?.cancel();
    _callStatusSub = FirebaseFirestore.instance
        .collection('calls')
        .doc(event.call.id)
        .snapshots()
        .listen(
      (doc) {
        print('🔵 RECEIVER Listener: doc.exists=${doc.exists}, status=${doc.data()?['status']}, activeCallId=$_activeCallId');
        if (!doc.exists) {
          print('🔵 RECEIVER: doc deleted - ending call');
          _skipFirestoreWrite = true;
          _endReason = CallEndReason.normal;
          if (!isClosed) add(CallEnd());
          return;
        }
        if (_activeCallId == null) {
          print('🔵 RECEIVER: activeCallId is null, ignoring');
          return;
        }
        final status = doc.data()?['status'] as String?;
        print('🔵 RECEIVER: checking status=$status');
        if (status == 'ended' || status == 'cancelled') {
          print('🔵 RECEIVER detected ended/cancelled - ending call');
          _skipFirestoreWrite = true;
          _endReason = CallEndReason.normal;
          if (!isClosed) add(CallEnd());
        }
      },
      onError: (error) {
        print('🔴 RECEIVER Listener ERROR: $error');
      },
      cancelOnError: false,
    );

    _watchForRemoteParticipant(
      room,
      event.call.type == CallType.video,
      event.call.roomName!,
    );
  }

  Future<void> _onReject(CallReject event, Emitter<CallState> emit) async {
    // Stop native ringtone service
    CallManager().stopCallForegroundService();

    try {
      await FirebaseFirestore.instance
          .collection('calls')
          .doc(event.callId)
          .update({'status': 'rejected'});
    } catch (_) {}
    emit(CallEnded(Duration.zero));
  }

  Future<void> _onEnd(CallEnd event, Emitter<CallState> emit) async {
    _durationTimer?.cancel();
    _durationTimer = null;
    _callStatusSub?.cancel();
    _callStatusSub = null;
    _roomListener?.dispose();
    _roomListener = null;
    _ringTimer?.cancel();
    _ringTimer = null;

    // Stop native ringtone service
    CallManager().stopCallForegroundService();

    final elapsed = _elapsed;
    _elapsed = Duration.zero;

    await LiveKitService.instance.disconnect();

    await _chargeCallTokens(elapsed);

    if (_activeCallId != null && !_skipFirestoreWrite) {
      // Determine the correct terminal status:
      //  • Call was active (remote joined)    → "ended" with elapsed duration
      //  • Call was still ringing (caller gave up) → "cancelled"
      final status = _wasActive ? 'ended' : 'cancelled';
      final extra  = _wasActive ? {'duration': elapsed.inSeconds} : <String, dynamic>{};
      if (!_wasActive) _endReason = CallEndReason.cancelled;
      try {
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(_activeCallId)
            .update({'status': status, ...extra});
      } catch (_) {}
    }

    final reason    = _endReason;
    _activeCallId   = null;
    _wasActive      = false;
    _isVideo        = false;
    _skipFirestoreWrite = false;
    _endReason      = CallEndReason.normal;

    emit(CallEnded(elapsed, reason: reason));
  }

  Future<void> _onToggleMic(CallToggleMic event, Emitter<CallState> emit) async {
    await LiveKitService.instance.toggleMicrophone();
    if (state is CallActive) {
      emit((state as CallActive).copyWith(isMicOn: LiveKitService.instance.isMicEnabled));
    }
  }

  Future<void> _onToggleCamera(CallToggleCamera event, Emitter<CallState> emit) async {
    await LiveKitService.instance.toggleCamera();
    if (state is CallActive) {
      emit((state as CallActive).copyWith(isCameraOn: LiveKitService.instance.isCameraEnabled));
    }
  }

  Future<void> _onSwitchCamera(CallSwitchCamera event, Emitter<CallState> emit) async {
    await LiveKitService.instance.switchCamera();
  }

  Future<void> _onToggleSpeaker(CallToggleSpeaker event, Emitter<CallState> emit) async {
    if (state is CallActive) {
      final current = state as CallActive;
      await LiveKitService.instance.enableSpeaker(!current.isSpeakerOn);
      emit(current.copyWith(isSpeakerOn: !current.isSpeakerOn));
    }
  }

  Future<void> _requestCallPermissions(bool withVideo) async {
    await Permission.microphone.request();
    if (withVideo) await Permission.camera.request();
  }

  Future<void> _chargeCallTokens(Duration elapsed) async {
    if (!_wasActive || elapsed.inSeconds <= 0) return;
    final uid = AuthService.instance.currentUserId;
    if (uid == null) return;
    final minutes = ((elapsed.inSeconds + 59) ~/ 60).clamp(1, 999).toInt();
    // Use the stored _isVideo flag — state may already be CallEnded by this point.
    final perMinute = _isVideo
        ? TokenCosts.videoCallPerMinute
        : TokenCosts.voiceCallPerMinute;
    await TokenService.instance.spendTokens(
      uid,
      minutes * perMinute,
      'مكالمة ${_isVideo ? 'فيديو' : 'صوت'} $minutes دقيقة',
    );
  }

  void _startSession(Emitter<CallState> emit, bool isVideo, String roomName) {
    // Call has been answered — cancel ring timer and mark as active
    _ringTimer?.cancel();
    _ringTimer = null;
    _wasActive = true;
    _isVideo = isVideo;

    // Stop native ringtone service
    CallManager().stopCallForegroundService();

    LiveKitService.instance.enableSpeaker(isVideo);
    _elapsed = Duration.zero;

    emit(CallActive(
      isMicOn: true,
      isCameraOn: isVideo,
      isSpeakerOn: isVideo,
      isVideo: isVideo,
      duration: Duration.zero,
      roomName: roomName,
    ));

    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      add(_CallTick(_elapsed));
    });
  }

  @override
  Future<void> close() {
    _durationTimer?.cancel();
    _callStatusSub?.cancel();
    _roomListener?.dispose();
    _ringTimer?.cancel();
    return super.close();
  }
}
