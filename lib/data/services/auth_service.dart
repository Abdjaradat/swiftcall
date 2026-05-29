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

    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (_) {}

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
      await _ensureFriendRequestFields(user.uid);
      await TokenService.instance.initWallet(user.uid);
    } catch (_) {}

    return userModel;
  }

  Future<UserModel?> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    final user = cred.user;
    if (user == null) return null;

    final fcmToken = await FirebaseMessaging.instance.getToken().catchError((_) => null);

    final doc = await _db.collection('users').doc(user.uid).get();
    if (doc.exists) {
      await _db.collection('users').doc(user.uid).update({
        'isOnline': true,
        'lastSeen': Timestamp.now(),
        if (fcmToken != null) 'fcmToken': fcmToken,
      });
      return UserModel.fromMap(doc.data()!);
    }

    // حساب موجود في Firebase Auth لكن ليس في Firestore — أنشئه الآن
    final userModel = UserModel(
      uid: user.uid,
      name: user.displayName ?? email.split('@').first,
      email: email,
      photoUrl: user.photoURL,
      isOnline: true,
      lastSeen: DateTime.now(),
      fcmToken: fcmToken,
    );
    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .set(userModel.toMap(), SetOptions(merge: true));
      await _ensureFriendRequestFields(user.uid);
      await TokenService.instance.initWallet(user.uid);
    } catch (_) {}
    return userModel;
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
      name: displayName,
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
      await _ensureFriendRequestFields(user.uid);
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
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    try {
      final doc = await _db.collection('users').doc(firebaseUser.uid).get();
      if (doc.exists) return UserModel.fromMap(doc.data()!);

      // مستخدم موجود في Firebase Auth بدون Firestore doc — أنشئه تلقائياً
      final fcmToken = await FirebaseMessaging.instance.getToken().catchError((_) => null);
      final userModel = UserModel(
        uid: firebaseUser.uid,
        name: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'مستخدم',
        email: firebaseUser.email ?? '',
        photoUrl: firebaseUser.photoURL,
        isOnline: true,
        lastSeen: DateTime.now(),
        fcmToken: fcmToken,
      );
      await _db.collection('users').doc(firebaseUser.uid)
          .set(userModel.toMap(), SetOptions(merge: true));
      await _ensureFriendRequestFields(firebaseUser.uid);
      await TokenService.instance.initWallet(firebaseUser.uid);
      return userModel;
    } catch (_) {
      // إذا فشل Firestore، أعد UserModel من Firebase Auth مباشرة
      return UserModel(
        uid: firebaseUser.uid,
        name: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'مستخدم',
        email: firebaseUser.email ?? '',
        photoUrl: firebaseUser.photoURL,
        isOnline: true,
        lastSeen: DateTime.now(),
      );
    }
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
    await _db.collection('users').doc(uid).set({
      'phoneNumber': phone,
    }, SetOptions(merge: true));
  }

  Future<void> sendFriendRequest(String targetUid) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      // Ensure both users have the friend request fields initialized
      await _ensureFriendRequestFields(uid);
      await _ensureFriendRequestFields(targetUid);

      final batch = _db.batch();
      batch.update(_db.collection('users').doc(uid), {
        'outgoingRequests': FieldValue.arrayUnion([targetUid]),
      });
      batch.update(_db.collection('users').doc(targetUid), {
        'incomingRequests': FieldValue.arrayUnion([uid]),
      });
      await batch.commit();
      print('AuthService.sendFriendRequest: Success - $uid -> $targetUid');
    } catch (e, stack) {
      print('AuthService.sendFriendRequest ERROR: $e');
      print('STACK: $stack');
      rethrow;
    }
  }

  Future<void> _ensureFriendRequestFields(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final needsUpdate = !data.containsKey('contacts') ||
          !data.containsKey('incomingRequests') ||
          !data.containsKey('outgoingRequests');

      if (needsUpdate) {
        await _db.collection('users').doc(uid).set({
          'contacts': [],
          'incomingRequests': [],
          'outgoingRequests': [],
        }, SetOptions(merge: true));
        print('AuthService._ensureFriendRequestFields: Initialized fields for $uid');
      }
    } catch (e) {
      print('AuthService._ensureFriendRequestFields ERROR: $e');
    }
  }

  Future<void> acceptFriendRequest(String requesterUid) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      final batch = _db.batch();
      batch.update(_db.collection('users').doc(uid), {
        'contacts': FieldValue.arrayUnion([requesterUid]),
        'incomingRequests': FieldValue.arrayRemove([requesterUid]),
      });
      batch.update(_db.collection('users').doc(requesterUid), {
        'contacts': FieldValue.arrayUnion([uid]),
        'outgoingRequests': FieldValue.arrayRemove([uid]),
      });
      await batch.commit();
      print('AuthService.acceptFriendRequest: Success - $uid accepted $requesterUid');
    } catch (e, stack) {
      print('AuthService.acceptFriendRequest ERROR: $e');
      print('STACK: $stack');
      rethrow;
    }
  }

  Future<void> rejectFriendRequest(String requesterUid) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      final batch = _db.batch();
      batch.update(_db.collection('users').doc(uid), {
        'incomingRequests': FieldValue.arrayRemove([requesterUid]),
      });
      batch.update(_db.collection('users').doc(requesterUid), {
        'outgoingRequests': FieldValue.arrayRemove([uid]),
      });
      await batch.commit();
      print('AuthService.rejectFriendRequest: Success - $uid rejected $requesterUid');
    } catch (e, stack) {
      print('AuthService.rejectFriendRequest ERROR: $e');
      print('STACK: $stack');
      rethrow;
    }
  }

  Future<void> cancelFriendRequest(String targetUid) async {
    final uid = currentUserId;
    if (uid == null) return;
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(uid), {
      'outgoingRequests': FieldValue.arrayRemove([targetUid]),
    });
    batch.update(_db.collection('users').doc(targetUid), {
      'incomingRequests': FieldValue.arrayRemove([uid]),
    });
    await batch.commit();
  }

  Future<void> removeFriend(String targetUid) async {
    final uid = currentUserId;
    if (uid == null) return;
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(uid), {
      'contacts': FieldValue.arrayRemove([targetUid]),
    });
    batch.update(_db.collection('users').doc(targetUid), {
      'contacts': FieldValue.arrayRemove([uid]),
    });
    await batch.commit();
  }

  Stream<UserModel?> watchUser(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromMap(doc.data()!) : null);
  }

  Future<List<UserModel>> getUsersExcluding(List<String> excludeUids) async {
    final snap = await _db.collection('users').get();
    return snap.docs
        .map((d) => UserModel.fromMap(d.data()))
        .where((user) => !excludeUids.contains(user.uid))
        .toList();
  }

  Future<List<UserModel>> getAllUsers() async {
    final uid = currentUserId;
    final snap = await _db.collection('users').get();
    return snap.docs
        .map((d) => UserModel.fromMap(d.data()))
        .where((user) => user.uid != uid)
        .toList();
  }

  Future<UserModel?> getUserById(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!);
  }
}
