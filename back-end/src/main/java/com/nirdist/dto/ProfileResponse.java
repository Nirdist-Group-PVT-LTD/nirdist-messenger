package com.nirdist.dto;

import java.time.OffsetDateTime;

public record ProfileResponse(
        Long vId,
        String username,
        String displayName,
        String email,
        String phoneNumber,
        String firebaseUid,
        String avatarUrl,
        String bio,
        OffsetDateTime phoneVerifiedAt,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
}