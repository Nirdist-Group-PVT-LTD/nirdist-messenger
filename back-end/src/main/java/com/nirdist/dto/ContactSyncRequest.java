package com.nirdist.dto;

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

public record ContactSyncRequest(
        @NotNull Long userId,
        List<@Valid ContactSyncItem> contacts
) {
}