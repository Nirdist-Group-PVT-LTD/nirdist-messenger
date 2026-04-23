package com.nirdist.dto;

public record AuthResponse(
        String token,
        ProfileResponse profile,
        String message,
        boolean created
) {
}