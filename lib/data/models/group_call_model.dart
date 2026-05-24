import 'package:cloud_firestore/cloud_firestore.dart';

enum GroupCallStatus { ringing, active, ended }
enum GroupCallType   { video, audio }

class GroupCallParticipant {
  final String  uid;
  final String  name;
  final String? photo;
  final String  status; // 'invited' | 'joined' | 'declined' | 'left'

  const GroupCallParticipant({
    required this.uid,
    required this.name,
    this.photo,
    required this.status,
  });

  GroupCallParticipant copyWith({String? status}) => GroupCallParticipant(
        uid:    uid,
        name:   name,
        photo:  photo,
        status: status ?? this.status,
      );

  factory GroupCallParticipant.fromMap(Map<String, dynamic> m) =>
      GroupCallParticipant(
        uid:    m['uid']    as String? ?? '',
        name:   m['name']   as String? ?? '',
        photo:  m['photo']  as String?,
        status: m['status'] as String? ?? 'invited',
      );

  Map<String, dynamic> toMap() => {
        'uid':    uid,
        'name':   name,
        'photo':  photo,
        'status': status,
      };
}

class GroupCallModel {
  final String                   id;
  final String                   roomName;
  final String                   createdBy;
  final String                   creatorName;
  final String?                  creatorPhoto;
  final List<GroupCallParticipant> participants;
  final GroupCallStatus          status;
  final GroupCallType            callType;
  final DateTime                 timestamp;
  final int?                     duration;

  const GroupCallModel({
    required this.id,
    required this.roomName,
    required this.createdBy,
    required this.creatorName,
    this.creatorPhoto,
    required this.participants,
    required this.status,
    required this.callType,
    required this.timestamp,
    this.duration,
  });

  List<GroupCallParticipant> get joined =>
      participants.where((p) => p.status == 'joined').toList();

  List<GroupCallParticipant> get invited =>
      participants.where((p) => p.status == 'invited').toList();

  bool isParticipant(String uid) =>
      participants.any((p) => p.uid == uid);

  factory GroupCallModel.fromMap(Map<String, dynamic> map, String id) =>
      GroupCallModel(
        id:           id,
        roomName:     map['roomName']    as String? ?? '',
        createdBy:    map['createdBy']   as String? ?? '',
        creatorName:  map['creatorName'] as String? ?? '',
        creatorPhoto: map['creatorPhoto'] as String?,
        participants: (map['participants'] as List<dynamic>? ?? [])
            .map((p) => GroupCallParticipant.fromMap(p as Map<String, dynamic>))
            .toList(),
        status:    _statusFromString(map['status'] as String?),
        callType:  (map['callType'] as String?) == 'video'
            ? GroupCallType.video
            : GroupCallType.audio,
        timestamp: map['timestamp'] is Timestamp
            ? (map['timestamp'] as Timestamp).toDate()
            : DateTime.now(),
        duration: map['duration'] as int?,
      );

  Map<String, dynamic> toMap() => {
        'roomName':       roomName,
        'createdBy':      createdBy,
        'creatorName':    creatorName,
        'creatorPhoto':   creatorPhoto,
        'participants':   participants.map((p) => p.toMap()).toList(),
        'participantUids': participants.map((p) => p.uid).toList(),
        'status':         _statusToString(status),
        'callType':       callType == GroupCallType.video ? 'video' : 'audio',
        'timestamp':      Timestamp.fromDate(timestamp),
        if (duration != null) 'duration': duration,
      };

  static GroupCallStatus _statusFromString(String? s) {
    switch (s) {
      case 'active': return GroupCallStatus.active;
      case 'ended':  return GroupCallStatus.ended;
      default:       return GroupCallStatus.ringing;
    }
  }

  static String _statusToString(GroupCallStatus s) {
    switch (s) {
      case GroupCallStatus.ringing: return 'ringing';
      case GroupCallStatus.active:  return 'active';
      case GroupCallStatus.ended:   return 'ended';
    }
  }
}
