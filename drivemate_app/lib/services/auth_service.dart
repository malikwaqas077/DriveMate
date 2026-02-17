import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';

import '../firebase_options.dart';
import 'fcm_service.dart';
import 'role_preference_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Converts a phone number to an email format for Firebase Auth
  /// Example: +1234567890 -> +1234567890@drivemate.local
  static String phoneToEmail(String phone) {
    // Normalize phone number (remove spaces, ensure it starts with +)
    final normalizedPhone = phone.trim().replaceAll(RegExp(r'\s+'), '');
    return '$normalizedPhone@drivemate.local';
  }

  /// Converts an email format back to phone number
  /// Example: +1234567890@drivemate.local -> +1234567890
  static String? emailToPhone(String email) {
    if (email.endsWith('@drivemate.local')) {
      return email.replaceAll('@drivemate.local', '');
    }
    return null;
  }

  /// Generates a random 6-digit password
  static String generateRandomPassword() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign in with phone number (converts to email format internally)
  Future<UserCredential> signInWithPhone({
    required String phone,
    required String password,
  }) {
    final email = phoneToEmail(phone);
    return signIn(email: email, password: password);
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<UserCredential> createStudentLogin({
    String? email,
    String? phone,
    required String password,
  }) async {
    if (phone == null && email == null) {
      throw ArgumentError('Either email or phone must be provided');
    }
    
    final authEmail = phone != null ? phoneToEmail(phone) : email!.trim();
    
    final secondaryApp = await Firebase.initializeApp(
      name: 'student-${DateTime.now().millisecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    try {
      return await secondaryAuth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
    } finally {
      await secondaryApp.delete();
    }
  }

  Future<UserCredential> createInstructorLogin({
    required String email,
    required String password,
  }) async {
    final secondaryApp = await Firebase.initializeApp(
      name: 'instructor-${DateTime.now().millisecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    try {
      return await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } finally {
      await secondaryApp.delete();
    }
  }

  /// Sign in with Google. Returns [UserCredential] or null if user cancels.
  /// On web: uses Firebase's signInWithPopup (obtains id_token correctly).
  /// On mobile: uses google_sign_in plugin.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // On web, use Firebase's native signInWithPopup. This properly obtains
        // the id_token and avoids the deprecated google_sign_in popup flow,
        // which returns access_token but not id_token (causing google-id-token-null).
        return await _auth.signInWithPopup(GoogleAuthProvider());
      }

      // On mobile, use google_sign_in
      final webClientId = DefaultFirebaseOptions.googleSignInWebClientId;
      final googleSignIn = GoogleSignIn(
        serverClientId: webClientId?.isNotEmpty == true ? webClientId : null,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'google-id-token-null',
          message: 'Google Sign-In did not return an ID token.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      // User closed popup or cancelled
      if (e.code == 'auth/popup-closed-by-user' ||
          e.code == 'auth/cancelled-popup-request') {
        return null;
      }
      debugPrint('[AuthService] Google Sign-In error: $e');
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] Google Sign-In error: $e');
      rethrow;
    }
  }

  /// Sign in with Apple. Returns [UserCredential] or null if user cancels.
  /// Requires Sign in with Apple capability on iOS and Apple as provider in Firebase Console.
  Future<UserCredential?> signInWithApple() async {
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256ofString(rawNonce);
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'apple-id-token-null',
        message: 'Apple Sign-In did not return an identity token.',
      );
    }
    final credential = OAuthProvider('apple.com').credential(
      idToken: idToken,
      rawNonce: rawNonce,
    );
    return _auth.signInWithCredential(credential);
  }

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Sign out and clear FCM token so this device no longer receives push notifications.
  Future<void> signOut() async {
    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      await FCMService.instance.clearToken(userId);
      await RolePreferenceService.instance.clearPreferredRole(userId);
    }
    await _auth.signOut();
  }
}
