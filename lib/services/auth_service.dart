import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thrown when an authentication operation fails.
class AuthException implements Exception {
  /// The Firebase error code (e.g. "user-not-found", "wrong-password").
  final String code;

  /// A human-readable message.
  final String message;

  AuthException(this.code, this.message);

  @override
  String toString() => 'AuthException($code): $message';
}

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthService({
    FirebaseAuth? authInstance,
    GoogleSignIn? googleSignIn,
  })  : _auth = authInstance ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  /// Signs in with Google OAuth.
  /// Throws [AuthException] on failure.
  Future<UserCredential> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw AuthException('cancelled', 'Google sign‐in was cancelled.');
      }

      final auth = await account.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      return await _auth.signInWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.code, e.message ?? 'Google sign‐in failed.');
    } catch (e) {
      throw AuthException('unknown', e.toString());
    }
  }

  /// Signs in with email & password.
  /// Throws [AuthException] on failure.
  Future<UserCredential> signInWithEmailPassword(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
          email: email, password: password);
    } on FirebaseAuthException catch (e) {
      // Map specific codes to friendly messages if you like:
      final msg = switch (e.code) {
        'user-not-found' => 'No account found for that email.',
        'wrong-password' => 'Incorrect password.',
        'invalid-email' => 'Invalid email address.',
        _ => e.message ?? 'Sign‐in failed.',
      };
      throw AuthException(e.code, msg);
    } catch (e) {
      throw AuthException('unknown', e.toString());
    }
  }

  /// Creates a new account with email & password.
  /// Throws [AuthException] on failure.
  Future<UserCredential> signUpWithEmailPassword(
      String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'email-already-in-use' => 'That email is already registered.',
        'weak-password' => 'Password is too weak.',
        'invalid-email' => 'Invalid email address.',
        _ => e.message ?? 'Sign‐up failed.',
      };
      throw AuthException(e.code, msg);
    } catch (e) {
      throw AuthException('unknown', e.toString());
    }
  }

  /// Sends a password‐reset email. Throws [AuthException] on failure.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'user-not-found' => 'No account found for that email.',
        'invalid-email' => 'Invalid email address.',
        _ => e.message ?? 'Failed to send reset email.',
      };
      throw AuthException(e.code, msg);
    } catch (e) {
      throw AuthException('unknown', e.toString());
    }
  }

  /// Signs out from both Firebase and Google.
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}
