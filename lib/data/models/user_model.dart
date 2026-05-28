import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? fcmToken;
  final String? status;
  final String? phoneNumber;
  final List<String> contacts;
  final List<String> incomingRequests;
  final List<String> outgoingRequests;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.isOnline = false,
    this.lastSeen,
    this.fcmToken,
    this.status,
    this.phoneNumber,
    this.contacts = const [],
    this.incomingRequests = const [],
    this.outgoingRequests = const [],
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      isOnline: map['isOnline'] as bool? ?? false,
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate(),
      fcmToken: map['fcmToken'] as String?,
      status: map['status'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      contacts: map['contacts'] != null
          ? List<String>.from(map['contacts'] as List)
          : const [],
      incomingRequests: map['incomingRequests'] != null
          ? List<String>.from(map['incomingRequests'] as List)
          : const [],
      outgoingRequests: map['outgoingRequests'] != null
          ? List<String>.from(map['outgoingRequests'] as List)
          : const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'fcmToken': fcmToken,
      'status': status,
      'phoneNumber': phoneNumber,
      'contacts': contacts,
      'incomingRequests': incomingRequests,
      'outgoingRequests': outgoingRequests,
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    bool? isOnline,
    DateTime? lastSeen,
    String? fcmToken,
    String? status,
    String? phoneNumber,
    List<String>? contacts,
    List<String>? incomingRequests,
    List<String>? outgoingRequests,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      fcmToken: fcmToken ?? this.fcmToken,
      status: status ?? this.status,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      contacts: contacts ?? this.contacts,
      incomingRequests: incomingRequests ?? this.incomingRequests,
      outgoingRequests: outgoingRequests ?? this.outgoingRequests,
    );
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
