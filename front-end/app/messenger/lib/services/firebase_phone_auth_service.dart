import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebasePhoneAuthService {
  FirebasePhoneAuthService();

  bool _isInitialized = false;

  Future<void> sendVerificationCode({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String idToken) onAutoVerified,
    required void Function(String message) onVerificationFailed,
    void Function(String verificationId)? onTimeout,
  }) async {
    try {
      final auth = await _firebaseAuth();
      await auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final idToken = await _signInAndFetchToken(auth, credential);
            onAutoVerified(idToken);
          } catch (error) {
            onVerificationFailed(_readableErrorMessage(error));
          }
        },
        verificationFailed: (FirebaseAuthException error) {
          onVerificationFailed(_readableErrorMessage(error));
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (onTimeout != null) {
            onTimeout(verificationId);
          }
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (error) {
      onVerificationFailed(_readableErrorMessage(error));
    }
  }

  Future<String> verifySmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final auth = await _firebaseAuth();
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      return _signInAndFetchToken(auth, credential);
    } catch (error) {
      throw FirebasePhoneAuthException(_readableErrorMessage(error));
    }
  }

  Future<FirebaseAuth> _firebaseAuth() async {
    await _ensureInitialized();
    return FirebaseAuth.instance;
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) {
      return;
    }

    await Firebase.initializeApp();
    _isInitialized = true;
  }

  Future<String> _signInAndFetchToken(FirebaseAuth auth, PhoneAuthCredential credential) async {
    final userCredential = await auth.signInWithCredential(credential);
    final user = userCredential.user;
    if (user == null) {
      throw const FirebasePhoneAuthException('Firebase did not return a signed-in user.');
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw const FirebasePhoneAuthException('Firebase did not return an ID token.');
    }

    return idToken;
  }

  String _readableErrorMessage(Object error) {
    if (error is FirebasePhoneAuthException) {
      return error.message;
    }

    if (error is FirebaseAuthException) {
      final errorCode = error.code.toLowerCase();
      final errorMessage = (error.message ?? '').toLowerCase();

      if (errorCode.contains('billing') || errorMessage.contains('billing_not_enabled')) {
        return 'Firebase phone SMS is blocked because this project has no billing account. Use Firebase test phone numbers for free development, or enable Blaze billing for real SMS.';
      }

      return error.message ?? 'Phone verification failed.';
    }

    return 'Phone verification failed.';
  }
}

class FirebasePhoneAuthException implements Exception {
  const FirebasePhoneAuthException(this.message);

  final String message;

  @override
  String toString() => 'FirebasePhoneAuthException: $message';
}