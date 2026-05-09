import 'package:cloud_firestore/cloud_firestore.dart';

enum CallType { video, audio }
enum CallStatus { ringing, accepted, rejected, ended, missed, busy }

String _callTypeToStr(CallType t) => t == CallType.video ? 'video' : 'audio';

CallType _callTypeFromStr(String? s) =>
    s == 'video' ? CallType.video : CallType.audio;

String _callStatusToStr(CallStatus s) {
  switch (s) {
    case CallStatus.ringing:  return 'ringing';
    case CallStatus.accepted: return 'accepted';
    case CallStatus.rejected: return 'rejected';
    case CallStatus.ended:    return 'ended';
    case CallStatus.missed:   return 'missed';
    case CallStatus.busy:     return 'busy';
  }
}

CallStatus _callStatusFromStr(String? s) {
  switch (s) {
    case 'accepted': return CallStatus.accepted;
    case 'rejected': return CallStatus.rejected;
    case 'ended':    return CallStatus.ended;
    case 'missed':   return CallStatus.missed;
    case 'busy':     return CallStatus.busy;
    default:         return CallStatus.ringing;
  }
}

class CallModel {
  final String id;
  final String callerId;
  final String callerName;
  final String? callerPhoto;
  final String receiverId;
  final String receiverName;
  final String? receiverPhoto;
  final CallType type;
  final CallStatus status;
  final DateTime timestamp;
  final int? duration;
  final String? roomName;

  const CallModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    this.callerPhoto,
    required this.receiverId,
    required this.receiverName,
    this.receiverPhoto,
    required this.type,
    required this.status,
    required this.timestamp,
    this.duration,
    this.roomName,
  });

  factory CallModel.fromMap(Map<String, dynamic> map, String id) {
    return CallModel(
      id: id,
      callerId: map['callerId'] as String? ?? '',
      callerName: map['callerName'] as String? ?? '',
      callerPhoto: map['callerPhoto'] as String?,
      receiverId: map['receiverId'] as String? ?? '',
      receiverName: map['receiverName'] as String? ?? '',
      receiverPhoto: map['receiverPhoto'] as String?,
      type: _callTypeFromStr(map['type'] as String?),
      status: _callStatusFromStr(map['status'] as String?),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      duration: map['duration'] as int?,
      roomName: map['roomName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerPhoto': callerPhoto,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverPhoto': receiverPhoto,
      'type': _callTypeToStr(type),
      'status': _callStatusToStr(status),
      'timestamp': Timestamp.fromDate(timestamp),
      'duration': duration,
      'roomName': roomName,
    };
  }

  CallModel copyWith({CallStatus? status, int? duration}) {
    return CallModel(
      id: id,
      callerId: callerId,
      callerName: callerName,
      callerPhoto: callerPhoto,
      receiverId: receiverId,
      receiverName: receiverName,
      receiverPhoto: receiverPhoto,
      type: type,
      status: status ?? this.status,
      timestamp: timestamp,
      duration: duration ?? this.duration,
      roomName: roomName,
    );
  }
}
