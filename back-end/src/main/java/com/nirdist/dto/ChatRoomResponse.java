package com.nirdist.dto;

import java.time.OffsetDateTime;
import java.util.List;

public record ChatRoomResponse(
        Long roomId,
        String roomName,
        String roomType,
        Long createdBy,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt,
        List<Long> participantIds
) {
}