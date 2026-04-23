package com.nirdist.controller;

import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Controller;

import com.nirdist.dto.ChatMessageRequest;
import com.nirdist.dto.ChatMessageResponse;
import com.nirdist.service.ChatService;

@Controller
public class ChatSocketController {

    private final ChatService chatService;
    private final SimpMessagingTemplate messagingTemplate;

    public ChatSocketController(ChatService chatService, SimpMessagingTemplate messagingTemplate) {
        this.chatService = chatService;
        this.messagingTemplate = messagingTemplate;
    }

    @MessageMapping("/chat/rooms/{roomId}/send")
    public void sendMessage(@DestinationVariable Long roomId, ChatMessageRequest request) {
        ChatMessageResponse response = chatService.sendMessage(roomId, request);
        messagingTemplate.convertAndSend("/topic/chat/rooms/" + roomId, response);
    }
}