package com.nirdist.dto;

public record CommunicationPermissionResponse(
        boolean allowed,
        String reason
) {
}