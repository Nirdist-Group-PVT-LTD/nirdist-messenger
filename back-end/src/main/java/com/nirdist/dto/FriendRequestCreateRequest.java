package com.nirdist.dto;

import jakarta.validation.constraints.NotNull;

public record FriendRequestCreateRequest(
        @NotNull Long requesterVId,
        @NotNull Long addresseeVId,
        String requestMessage
) {
}