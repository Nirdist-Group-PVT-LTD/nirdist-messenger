package com.nirdist.auth;

public interface FirebaseTokenVerifier {

    FirebaseVerifiedUser verify(String idToken);
}