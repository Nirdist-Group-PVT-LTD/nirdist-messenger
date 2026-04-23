package com.nirdist.dto;

import java.time.OffsetDateTime;

public record FriendRequestResponse(
        Long requestId,
        ProfileResponse requester,
        ProfileResponse addressee,
        String requestMessage,
        String requestStatus,
        Long respondedByVId,
        OffsetDateTime requestedAt,
        OffsetDateTime respondedAt
) {
}