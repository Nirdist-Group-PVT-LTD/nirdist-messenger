package com.nirdist.chat.cache;

import java.time.Instant;
import java.util.Objects;

public record ChatMessageSnapshot(
        Long messageId,
        Long roomId,
        Long senderVId,
        String messageText,
        String mediaUrl,
        String messageType,
        Instant createdAt
) {
    public ChatMessageSnapshot {
        Objects.requireNonNull(roomId, "roomId is required");
        Objects.requireNonNull(senderVId, "senderVId is required");
        messageText = messageText == null ? "" : messageText.trim();
        mediaUrl = mediaUrl == null || mediaUrl.isBlank() ? null : mediaUrl.trim();
        messageType = (messageType == null || messageType.isBlank()) ? "TEXT" : messageType.trim().toUpperCase();
        createdAt = createdAt == null ? Instant.now() : createdAt;
    }
}