import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

Future<UserCredential?> signInWithGoogle() async {
  try {
    // Sign out any previously signed-in user to force a prompt
    await GoogleSignIn().signOut();
    
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      // The user canceled the sign-in
      return null;
    }
    
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    
    return await FirebaseAuth.instance.signInWithCredential(credential);
  } catch (e) {
    print('Google sign-in error: $e');
    return null;
  }
}
