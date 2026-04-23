package com.nirdist.dto;

import java.util.List;

public record ContactSyncResponse(
        Long userId,
        int contactCount,
        int matchedCount,
        List<ProfileResponse> matchedUsers,
        List<ProfileResponse> suggestedUsers
) {
}