package com.nirdist.dto;

import jakarta.validation.constraints.NotBlank;

public record FirebaseAuthExchangeRequest(
        @NotBlank String idToken,
        String username,
        String displayName,
        String email,
        String avatarUrl
) {
}