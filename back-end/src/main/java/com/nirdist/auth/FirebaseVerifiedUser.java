package com.nirdist.auth;

public record FirebaseVerifiedUser(
        String uid,
        String phoneNumber,
        String displayName,
        String email,
        String avatarUrl
) {
}