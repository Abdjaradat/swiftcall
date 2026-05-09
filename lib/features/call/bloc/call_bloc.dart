import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/call_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/livekit_service.dart';

part 'call_event.dart';
part 'call_state.dart';

class CallBloc extends Bloc<CallEvent, CallState> {
  Timer? _durationTimer;
  StreamSubscription? _callStatusSub;
  Duration _elapsed = Duration.zero;
  String? _activeCallId;

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
  }

  // ── Tick: runs every second, emitted via add() so the emitter is always fresh
  void _onTick(_CallTick event, Emitter<CallState> emit) {
    if (state is CallActive) {
      emit((state as CallActive).copyWith(duration: event.elapsed));
    }
  }

  Future<void> _onStart(CallStart event, Emitter<CallState> emit) async {
    emit(CallConnecting());
    await _requestCallPermissions(event.isVideo);

    final me = await AuthService.instance.getCurrentUserModel();
    if (me == null) { emit(CallFailed('لم يتم التعرف على المستخدم')); return; }

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
    if (room == null) { emit(CallFailed('فشل الاتصال بالغرفة')); return; }

    // Wait for remote participant before starting the session
    _waitForRemoteParticipant(emit, event.isVideo, roomName, room);

    // Watch for receiver rejecting the call
    _callStatusSub?.cancel();
    _callStatusSub = FirebaseFirestore.instance
        .collection('calls')
        .doc(callId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || _activeCallId == null) return;
      final status = doc.data()?['status'] as String?;
      if (status == 'rejected' || status == 'missed') {
        _onEnd(CallEnd(), emit);
      }
    });
  }

  Future<void> _waitForRemoteParticipant(
    Emitter<CallState> emit, bool isVideo, String roomName, Room room,
  ) async {
    // Listen for remote participant joining
    final listener = room.createListener();
    listener.on<ParticipantConnectedEvent>((_) {
      if (state is CallConnecting) {
        _startSession(emit, isVideo, roomName);
      }
    });

    // Also check if already connected (race condition)
    if (room.remoteParticipants.isNotEmpty) {
      listener.dispose();
      _startSession(emit, isVideo, roomName);
      return;
    }

    // Timeout after 45 seconds
    Future.delayed(AppConstants.callTimeout, () {
      listener.dispose();
      if (state is CallConnecting) {
        _onEnd(CallEnd(), emit);
      }
    });
  }

  Future<void> _onAccept(CallAccept event, Emitter<CallState> emit) async {
    emit(CallConnecting());
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
    if (room == null) { emit(CallFailed('فشل الاتصال')); return; }

    // Receiver is the second to join — remote participant should already be there
    _waitForRemoteParticipant(emit, event.call.type == CallType.video, event.call.roomName!, room);
  }

  Future<void> _onReject(CallReject event, Emitter<CallState> emit) async {
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
    final elapsed = _elapsed;
    _elapsed = Duration.zero;

    await LiveKitService.instance.disconnect();

    if (_activeCallId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(_activeCallId)
            .update({'status': 'ended', 'duration': elapsed.inSeconds});
      } catch (_) {}
      _activeCallId = null;
    }

    emit(CallEnded(elapsed));
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

  // ── Helpers ───────────────────────────────────────────────
  Future<void> _requestCallPermissions(bool withVideo) async {
    await Permission.microphone.request();
    if (withVideo) await Permission.camera.request();
  }

  // Emits initial CallActive and starts the periodic tick via add()
  void _startSession(Emitter<CallState> emit, bool isVideo, String roomName) {
    // Speaker ON for video calls, OFF (earpiece) for voice calls
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
      add(_CallTick(_elapsed)); // fires a new event — gets a fresh emitter
    });
  }

  @override
  Future<void> close() {
    _durationTimer?.cancel();
    _callStatusSub?.cancel();
    return super.close();
  }
}
