package com.nirdist.dto;

import java.util.List;

public record ChatRoomCreateRequest(
        Long createdBy,
        String roomName,
        String roomType,
        List<Long> participantIds
) {
}