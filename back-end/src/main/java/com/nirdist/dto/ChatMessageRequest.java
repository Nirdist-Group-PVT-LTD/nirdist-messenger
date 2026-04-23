package com.nirdist.dto;

public record ChatMessageRequest(
        Long senderVId,
        String messageText,
        String mediaUrl,
        String messageType,
        Long replyToId
) {
}