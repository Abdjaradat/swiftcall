import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/group_call_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/livekit_service.dart';

part 'group_call_event.dart';
part 'group_call_state.dart';

class GroupCallBloc extends Bloc<GroupCallEvent, GroupCallState> {
  Timer?              _durationTimer;
  StreamSubscription? _callStatusSub;
  Duration            _elapsed    = Duration.zero;
  String?             _activeCallId;
  bool                _isCreator  = false;

  GroupCallBloc() : super(GroupCallIdle()) {
    on<GroupCallCreate>(_onCreate);
    on<GroupCallJoin>(_onJoin);
    on<GroupCallLeave>(_onLeave);
    on<GroupCallToggleMic>(_onToggleMic);
    on<GroupCallToggleCamera>(_onToggleCamera);
    on<GroupCallSwitchCamera>(_onSwitchCamera);
    on<GroupCallToggleSpeaker>(_onToggleSpeaker);
    on<_GroupCallTick>(_onTick);
  }

  void _onTick(_GroupCallTick event, Emitter<GroupCallState> emit) {
    if (state is GroupCallActive) {
      emit((state as GroupCallActive).copyWith(duration: event.elapsed));
    }
  }

  Future<void> _onCreate(
    GroupCallCreate event,
    Emitter<GroupCallState> emit,
  ) async {
    emit(GroupCallConnecting());
    await _requestPermissions(event.isVideo);

    final me = await AuthService.instance.getCurrentUserModel();
    if (me == null) {
      emit(GroupCallError('لم يتم التعرف على المستخدم'));
      return;
    }

    final callId   = const Uuid().v4();
    final roomName = const Uuid().v4().replaceAll('-', '').substring(0, 12);

    final participantsList = [
      GroupCallParticipant(
        uid: me.uid, name: me.name, photo: me.photoUrl, status: 'joined'),
      ...event.participants.map((u) => GroupCallParticipant(
          uid: u.uid, name: u.name, photo: u.photoUrl, status: 'invited')),
    ];

    final groupCall = GroupCallModel(
      id:           callId,
      roomName:     roomName,
      createdBy:    me.uid,
      creatorName:  me.name,
      creatorPhoto: me.photoUrl,
      participants: participantsList,
      status:       GroupCallStatus.ringing,
      callType:     event.isVideo ? GroupCallType.video : GroupCallType.audio,
      timestamp:    DateTime.now(),
    );

    try {
      await FirebaseFirestore.instance
          .collection('group_calls')
          .doc(callId)
          .set(groupCall.toMap());
      _activeCallId = callId;
      _isCreator    = true;
    } catch (e) {
      emit(GroupCallError('فشل إنشاء المكالمة'));
      return;
    }

    final room = await LiveKitService.instance.connectToRoom(
      roomName:     roomName,
      identity:     me.uid,
      videoEnabled: event.isVideo,
    );
    if (room == null) {
      emit(GroupCallError('فشل الاتصال بالغرفة'));
      return;
    }

    _watchCallStatus(callId);
    LiveKitService.instance.enableSpeaker(event.isVideo);
    _elapsed = Duration.zero;
    _startDurationTimer();

    emit(GroupCallActive(
      isMicOn:     true,
      isCameraOn:  event.isVideo,
      isSpeakerOn: event.isVideo,
      isVideo:     event.isVideo,
      duration:    Duration.zero,
      roomName:    roomName,
      callId:      callId,
      isCreator:   true,
    ));
  }

  Future<void> _onJoin(
    GroupCallJoin event,
    Emitter<GroupCallState> emit,
  ) async {
    emit(GroupCallConnecting());
    final call    = event.call;
    final isVideo = call.callType == GroupCallType.video;
    await _requestPermissions(isVideo);

    final me = await AuthService.instance.getCurrentUserModel();
    if (me == null) {
      emit(GroupCallError('لم يتم التعرف على المستخدم'));
      return;
    }

    // Update participant status to 'joined'
    try {
      final ref = FirebaseFirestore.instance
          .collection('group_calls')
          .doc(call.id);
      final doc  = await ref.get();
      if (!doc.exists) {
        emit(GroupCallError('انتهت المكالمة'));
        return;
      }
      final raw = (doc.data()!['participants'] as List<dynamic>)
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();
      final idx = raw.indexWhere((p) => p['uid'] == me.uid);
      if (idx != -1) raw[idx] = {...raw[idx], 'status': 'joined'};
      await ref.update({'participants': raw, 'status': 'active'});
      _activeCallId = call.id;
      _isCreator    = false;
    } catch (e) {
      emit(GroupCallError('فشل تحديث حالة المكالمة'));
      return;
    }

    final room = await LiveKitService.instance.connectToRoom(
      roomName:     call.roomName,
      identity:     me.uid,
      videoEnabled: isVideo,
    );
    if (room == null) {
      emit(GroupCallError('فشل الاتصال'));
      return;
    }

    _watchCallStatus(call.id);
    LiveKitService.instance.enableSpeaker(isVideo);
    _elapsed = Duration.zero;
    _startDurationTimer();

    emit(GroupCallActive(
      isMicOn:     true,
      isCameraOn:  isVideo,
      isSpeakerOn: isVideo,
      isVideo:     isVideo,
      duration:    Duration.zero,
      roomName:    call.roomName,
      callId:      call.id,
      isCreator:   false,
    ));
  }

  Future<void> _onLeave(
    GroupCallLeave event,
    Emitter<GroupCallState> emit,
  ) async {
    _durationTimer?.cancel();
    _durationTimer = null;
    _callStatusSub?.cancel();
    _callStatusSub = null;

    final elapsed   = _elapsed;
    _elapsed        = Duration.zero;
    final callId    = _activeCallId;
    final isCreator = _isCreator;
    _activeCallId   = null;
    _isCreator      = false;

    await LiveKitService.instance.disconnect();

    if (callId != null) {
      try {
        if (isCreator) {
          await FirebaseFirestore.instance
              .collection('group_calls')
              .doc(callId)
              .update({'status': 'ended', 'duration': elapsed.inSeconds});
        } else {
          final myUid = AuthService.instance.currentUserId;
          final ref   = FirebaseFirestore.instance.collection('group_calls').doc(callId);
          final doc   = await ref.get();
          if (doc.exists) {
            final raw = (doc.data()!['participants'] as List<dynamic>)
                .map((p) => Map<String, dynamic>.from(p as Map))
                .toList();
            final idx = raw.indexWhere((p) => p['uid'] == myUid);
            if (idx != -1) raw[idx] = {...raw[idx], 'status': 'left'};
            await ref.update({'participants': raw});
          }
        }
      } catch (_) {}
    }

    emit(GroupCallEnded(elapsed));
  }

  void _watchCallStatus(String callId) {
    _callStatusSub?.cancel();
    _callStatusSub = FirebaseFirestore.instance
        .collection('group_calls')
        .doc(callId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || _activeCallId == null) return;
      final status = doc.data()?['status'] as String?;
      if (status == 'ended' && !isClosed) add(GroupCallLeave());
    });
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      if (!isClosed) add(_GroupCallTick(_elapsed));
    });
  }

  Future<void> _onToggleMic(
    GroupCallToggleMic event, Emitter<GroupCallState> emit) async {
    await LiveKitService.instance.toggleMicrophone();
    if (state is GroupCallActive) {
      emit((state as GroupCallActive)
          .copyWith(isMicOn: LiveKitService.instance.isMicEnabled));
    }
  }

  Future<void> _onToggleCamera(
    GroupCallToggleCamera event, Emitter<GroupCallState> emit) async {
    await LiveKitService.instance.toggleCamera();
    if (state is GroupCallActive) {
      emit((state as GroupCallActive)
          .copyWith(isCameraOn: LiveKitService.instance.isCameraEnabled));
    }
  }

  Future<void> _onSwitchCamera(
    GroupCallSwitchCamera event, Emitter<GroupCallState> emit) async {
    await LiveKitService.instance.switchCamera();
  }

  Future<void> _onToggleSpeaker(
    GroupCallToggleSpeaker event, Emitter<GroupCallState> emit) async {
    if (state is GroupCallActive) {
      final cur = state as GroupCallActive;
      await LiveKitService.instance.enableSpeaker(!cur.isSpeakerOn);
      emit(cur.copyWith(isSpeakerOn: !cur.isSpeakerOn));
    }
  }

  Future<void> _requestPermissions(bool withVideo) async {
    await Permission.microphone.request();
    if (withVideo) await Permission.camera.request();
  }

  @override
  Future<void> close() {
    _durationTimer?.cancel();
    _callStatusSub?.cancel();
    return super.close();
  }
}
