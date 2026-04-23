package com.nirdist.dto;

import jakarta.validation.constraints.NotBlank;

public record PhoneAuthExchangeRequest(
        @NotBlank String phoneNumber,
        String username,
        String displayName,
        String email,
        String avatarUrl
) {
}