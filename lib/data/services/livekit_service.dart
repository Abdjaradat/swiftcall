import 'package:dio/dio.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../core/constants/app_constants.dart';

class LiveKitService {
  Room? _room;

  static LiveKitService get instance => _instance;
  static final LiveKitService _instance = LiveKitService._();
  LiveKitService._();

  Room? get room => _room;
  bool get isConnected => _room?.connectionState == ConnectionState.connected;

  Future<String?> getToken({
    required String roomName,
    required String identity,
  }) async {
    try {
      final response = await Dio().get(
        '${AppConstants.livekitTokenServer}/getToken',
        queryParameters: {'roomName': roomName, 'identity': identity},
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is String) return data;
        if (data is Map) return data['token'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<Room?> connectToRoom({
    required String roomName,
    required String identity,
    bool videoEnabled = true,
    bool audioEnabled = true,
  }) async {
    try {
      final token = await getToken(roomName: roomName, identity: identity);
      if (token == null) return null;

      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultVideoPublishOptions: VideoPublishOptions(
            simulcast: true,
          ),
        ),
      );
      await _room!.connect(
        AppConstants.livekitUrl,
        token,
      );

      if (videoEnabled) {
        await _room!.localParticipant?.setCameraEnabled(true);
      }
      if (audioEnabled) {
        await _room!.localParticipant?.setMicrophoneEnabled(true);
      }

      return _room;
    } catch (_) {
      await disconnect();
      return null;
    }
  }

  Future<void> disconnect() async {
    await _room?.disconnect();
    _room?.dispose();
    _room = null;
  }

  Future<void> toggleMicrophone() async {
    final enabled = _room?.localParticipant?.isMicrophoneEnabled() ?? false;
    await _room?.localParticipant?.setMicrophoneEnabled(!enabled);
  }

  Future<void> toggleCamera() async {
    final enabled = _room?.localParticipant?.isCameraEnabled() ?? false;
    await _room?.localParticipant?.setCameraEnabled(!enabled);
  }

  Future<void> switchCamera() async {
    final pubs = _room?.localParticipant?.videoTrackPublications;
    if (pubs == null || pubs.isEmpty) return;
    final track = pubs.first.track;
    if (track == null) return;
    final opts = track.currentOptions;
    final current = opts is CameraCaptureOptions
        ? opts.cameraPosition
        : CameraPosition.front;
    await track.setCameraPosition(
      current == CameraPosition.front ? CameraPosition.back : CameraPosition.front,
    );
  }

  Future<void> enableSpeaker(bool enabled) async {
    await Hardware.instance.setSpeakerphoneOn(enabled);
  }

  bool get isMicEnabled =>
      _room?.localParticipant?.isMicrophoneEnabled() ?? false;
  bool get isCameraEnabled =>
      _room?.localParticipant?.isCameraEnabled() ?? false;

  List<RemoteParticipant> get remoteParticipants =>
      _room?.remoteParticipants.values.toList() ?? [];
}
