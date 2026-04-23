package com.nirdist.dto;

import jakarta.validation.constraints.NotBlank;

public record ContactSyncItem(
        String contactName,
        @NotBlank String phoneNumber
) {
}