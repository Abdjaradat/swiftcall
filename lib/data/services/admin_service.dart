import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  static AdminService get instance => _instance;
  static final AdminService _instance = AdminService._();
  AdminService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> isAdmin(String uid) async {
    try {
      final snap = await _db.collection('admins').doc(uid).get();
      return snap.exists;
    } catch (e, stack) {
      print('AdminService.isAdmin ERROR: $e');
      print('STACK: $stack');
      return false;
    }
  }

  Future<String?> currentUid() async {
    return FirebaseAuth.instance.currentUser?.uid;
  }
}
