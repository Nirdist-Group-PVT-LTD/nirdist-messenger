package com.nirdist.dto;

import jakarta.validation.constraints.NotNull;

public record FriendRequestActionRequest(
        @NotNull Long actorVId
) {
}