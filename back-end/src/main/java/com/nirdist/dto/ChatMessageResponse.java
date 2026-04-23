package com.nirdist.dto;

import java.time.OffsetDateTime;

public record ChatMessageResponse(
        Long messageId,
        Long roomId,
        Long senderVId,
        String messageText,
        String mediaUrl,
        String messageType,
        Long replyToId,
        Boolean isDeleted,
        OffsetDateTime createdAt
) {
}