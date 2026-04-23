package com.nirdist.chat.cache;

import java.util.List;

public interface ChatCacheService {

    void put(ChatMessageSnapshot message);

    List<ChatMessageSnapshot> getRecentMessages(Long roomId);

    void clearRoom(Long roomId);
}