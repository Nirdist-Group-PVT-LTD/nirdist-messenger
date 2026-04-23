package com.nirdist.chat.cache;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class InMemoryChatCacheService implements ChatCacheService {

    private final Map<Long, Deque<ChatMessageSnapshot>> roomCache = new ConcurrentHashMap<>();
    private final int maxMessagesPerRoom;

    public InMemoryChatCacheService(@Value("${app.chat.cache.max-messages-per-room:100}") int maxMessagesPerRoom) {
        this.maxMessagesPerRoom = maxMessagesPerRoom;
    }

    @Override
    public void put(ChatMessageSnapshot message) {
        Deque<ChatMessageSnapshot> messages = roomCache.computeIfAbsent(message.roomId(), key -> new ArrayDeque<>());

        synchronized (messages) {
            messages.addLast(message);
            while (messages.size() > maxMessagesPerRoom) {
                messages.removeFirst();
            }
        }
    }

    @Override
    public List<ChatMessageSnapshot> getRecentMessages(Long roomId) {
        Deque<ChatMessageSnapshot> messages = roomCache.get(roomId);
        if (messages == null) {
            return List.of();
        }

        synchronized (messages) {
            return new ArrayList<>(messages);
        }
    }

    @Override
    public void clearRoom(Long roomId) {
        roomCache.remove(roomId);
    }
}