package com.nirdist.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.nirdist.dto.ChatMessageRequest;
import com.nirdist.dto.ChatMessageResponse;
import com.nirdist.dto.ChatRoomCreateRequest;
import com.nirdist.dto.ChatRoomResponse;
import com.nirdist.service.ChatService;

@RestController
@RequestMapping("/api/chat")
public class ChatController {

    private final ChatService chatService;

    public ChatController(ChatService chatService) {
        this.chatService = chatService;
    }

    @PostMapping("/rooms")
    public ResponseEntity<ChatRoomResponse> createRoom(@RequestBody ChatRoomCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(chatService.createRoom(request));
    }

    @GetMapping("/rooms")
    public List<ChatRoomResponse> listRooms(@RequestParam("userId") Long userId) {
        return chatService.listRoomsForUser(userId);
    }

    @GetMapping("/rooms/{roomId}/messages")
    public List<ChatMessageResponse> listMessages(@PathVariable Long roomId) {
        return chatService.listMessages(roomId);
    }

    @GetMapping("/rooms/{roomId}/recent")
    public List<ChatMessageResponse> getRecentMessages(@PathVariable Long roomId) {
        return chatService.getRecentCachedMessages(roomId);
    }

    @PostMapping("/rooms/{roomId}/messages")
    public ResponseEntity<ChatMessageResponse> sendMessage(
            @PathVariable Long roomId,
            @RequestBody ChatMessageRequest request
    ) {
        return ResponseEntity.status(HttpStatus.CREATED).body(chatService.sendMessage(roomId, request));
    }
}