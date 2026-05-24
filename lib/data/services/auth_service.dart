import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'token_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '1082599622155-4gakg5bv8q1gtibljpuh1snc00ncnf62.apps.googleusercontent.com',
  );

  static AuthService get instance => _instance;
  static final AuthService _instance = AuthService._();
  AuthService._();

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) return null;

    final fcmToken = await FirebaseMessaging.instance.getToken();

    final userModel = UserModel(
      uid: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      photoUrl: user.photoURL,
      isOnline: true,
      lastSeen: DateTime.now(),
      fcmToken: fcmToken,
      phoneNumber: null,
    );

    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .set(userModel.toMap(), SetOptions(merge: true));
      await TokenService.instance.initWallet(user.uid);
    } catch (_) {}

    return userModel;
  }

  Future<UserModel?> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    final user = cred.user;
    if (user == null) return null;

    final doc = await _db.collection('users').doc(user.uid).get();
    if (doc.exists) {
      await _db.collection('users').doc(user.uid).update({
        'isOnline': true,
        'lastSeen': Timestamp.now(),
      });
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  Future<UserModel?> registerWithEmail(
      String email, String password, String displayName) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    final user = cred.user;
    if (user == null) return null;

    await user.updateDisplayName(displayName);

    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (_) {}

    final userModel = UserModel(
      uid: user.uid,
      displayName: displayName,
      email: email,
      photoUrl: null,
      isOnline: true,
      lastSeen: DateTime.now(),
      fcmToken: fcmToken,
      phoneNumber: null,
    );

    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .set(userModel.toMap(), SetOptions(merge: true));
      await TokenService.instance.initWallet(user.uid);
    } catch (_) {}

    return userModel;
  }

  Future<void> sendPasswordReset(String email) async {
    _auth.setLanguageCode('ar');
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    final uid = currentUserId;
    if (uid != null) {
      await _db.collection('users').doc(uid).update({
        'isOnline': false,
        'lastSeen': Timestamp.now(),
      });
    }
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<UserModel?> getCurrentUserModel() async {
    final uid = currentUserId;
    if (uid == null) return null;

    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    return UserModel.fromMap(doc.data()!);
  }

  Future<void> setOnlineStatus(bool isOnline) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _db.collection('users').doc(uid).update({
      'isOnline': isOnline,
      'lastSeen': Timestamp.now(),
    });
  }

  Future<void> updateFcmToken(String token) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({'fcmToken': token});
  }

  /// Saves the iOS PushKit VoIP token to Firestore so the backend can
  /// send VoIP push notifications to wake the app from a killed state.
  Future<void> updateVoipToken(String token) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({'voipToken': token});
  }

  Future<void> updatePhoneNumber(String phone) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({'phoneNumber': phone});
  }

  Future<void> hideContact(String otherUid) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({
      'hiddenContacts': FieldValue.arrayUnion([otherUid]),
    });
  }

  Future<void> unhideContact(String otherUid) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _db.collection('users').doc(uid).update({
      'hiddenContacts': FieldValue.arrayRemove([otherUid]),
    });
  }

  Stream<UserModel?> watchUser(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromMap(doc.data()!) : null);
  }

  Future<List<UserModel>> getAllUsers() async {
    final uid = currentUserId;
    final snap = await _db
        .collection('users')
        .where('uid', isNotEqualTo: uid)
        .get();
    return snap.docs.map((d) => UserModel.fromMap(d.data())).toList();
  }

  Future<UserModel?> getUserById(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }

  Future<List<UserModel>> getUsersByPhones(List<String> normalizedPhones) async {
    if (normalizedPhones.isEmpty) return [];
    final snap = await _db
        .collection('users')
        .where('phoneNumber', whereIn: normalizedPhones)
        .get();
    return snap.docs.map((d) => UserModel.fromMap(d.data())).toList();
  }
}
