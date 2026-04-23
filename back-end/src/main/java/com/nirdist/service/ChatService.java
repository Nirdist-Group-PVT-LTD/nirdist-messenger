package com.nirdist.service;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.nirdist.chat.cache.ChatCacheService;
import com.nirdist.chat.cache.ChatMessageSnapshot;
import com.nirdist.dto.ChatMessageRequest;
import com.nirdist.dto.ChatMessageResponse;
import com.nirdist.dto.ChatRoomCreateRequest;
import com.nirdist.dto.ChatRoomResponse;
import com.nirdist.entity.ChatMessage;
import com.nirdist.entity.ChatParticipant;
import com.nirdist.entity.ChatRoom;
import com.nirdist.entity.Profile;
import com.nirdist.repository.ChatMessageRepository;
import com.nirdist.repository.ChatParticipantRepository;
import com.nirdist.repository.ChatRoomRepository;
import com.nirdist.repository.ProfileRepository;

@Service
@Transactional
public class ChatService {

    private final ProfileRepository profileRepository;
    private final ChatRoomRepository chatRoomRepository;
    private final ChatParticipantRepository chatParticipantRepository;
    private final ChatMessageRepository chatMessageRepository;
    private final ChatCacheService chatCacheService;
    private final SocialGraphService socialGraphService;

    public ChatService(
            ProfileRepository profileRepository,
            ChatRoomRepository chatRoomRepository,
            ChatParticipantRepository chatParticipantRepository,
            ChatMessageRepository chatMessageRepository,
            ChatCacheService chatCacheService,
            SocialGraphService socialGraphService
    ) {
        this.profileRepository = profileRepository;
        this.chatRoomRepository = chatRoomRepository;
        this.chatParticipantRepository = chatParticipantRepository;
        this.chatMessageRepository = chatMessageRepository;
        this.chatCacheService = chatCacheService;
        this.socialGraphService = socialGraphService;
    }

    public ChatRoomResponse createRoom(ChatRoomCreateRequest request) {
        if (request == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "request body is required");
        }

        Long createdBy = requirePositiveId(request.createdBy(), "createdBy");
        Profile creator = getProfileOrThrow(createdBy);

        LinkedHashSet<Long> participantIds = normalizeParticipantIds(request.participantIds(), createdBy);
        for (Long participantId : participantIds) {
            getProfileOrThrow(participantId);
        }

        ChatRoom room = new ChatRoom();
        room.setRoomName(trimToNull(request.roomName()));
        room.setRoomType(normalizeRoomType(request.roomType(), participantIds.size()));
        room.setCreatedBy(creator.getVId());

        socialGraphService.requireRoomParticipantsAreFriends(creator.getVId(), participantIds, room.getRoomType());

        ChatRoom savedRoom = chatRoomRepository.save(room);

        for (Long participantId : participantIds) {
            ChatParticipant participant = new ChatParticipant();
            participant.setRoomId(savedRoom.getRoomId());
            participant.setParticipantVId(participantId);
            participant.setRole(Objects.equals(participantId, createdBy) ? "owner" : "member");
            chatParticipantRepository.save(participant);
        }

        return toRoomResponse(savedRoom, new ArrayList<>(participantIds));
    }

    public List<ChatRoomResponse> listRoomsForUser(Long userId) {
        Long normalizedUserId = requirePositiveId(userId, "userId");
        getProfileOrThrow(normalizedUserId);

        List<ChatParticipant> memberships = chatParticipantRepository.findByParticipantVId(normalizedUserId);
        if (memberships.isEmpty()) {
            return List.of();
        }

        Map<Long, ChatRoom> roomsById = chatRoomRepository.findAllById(
                memberships.stream().map(ChatParticipant::getRoomId).distinct().toList()
        ).stream().collect(Collectors.toMap(ChatRoom::getRoomId, Function.identity()));

        return memberships.stream()
                .map(ChatParticipant::getRoomId)
                .distinct()
                .map(roomsById::get)
                .filter(Objects::nonNull)
                .sorted(Comparator.comparing(ChatRoom::getCreatedAt, Comparator.nullsLast(Comparator.naturalOrder())).reversed())
                .map(room -> toRoomResponse(room, getParticipantIds(room.getRoomId())))
                .toList();
    }

    public List<ChatMessageResponse> listMessages(Long roomId) {
        Long normalizedRoomId = requirePositiveId(roomId, "roomId");
        getRoomOrThrow(normalizedRoomId);

        return chatMessageRepository.findByRoomIdOrderByCreatedAtAsc(normalizedRoomId)
                .stream()
                .map(this::toMessageResponse)
                .toList();
    }

    public List<ChatMessageResponse> getRecentCachedMessages(Long roomId) {
        Long normalizedRoomId = requirePositiveId(roomId, "roomId");
        getRoomOrThrow(normalizedRoomId);

        return chatCacheService.getRecentMessages(normalizedRoomId)
                .stream()
                .map(this::toMessageResponse)
                .toList();
    }

    public ChatMessageResponse sendMessage(Long roomId, ChatMessageRequest request) {
        Long normalizedRoomId = requirePositiveId(roomId, "roomId");
        if (request == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "request body is required");
        }

        getRoomOrThrow(normalizedRoomId);

        Long senderVId = requirePositiveId(request.senderVId(), "senderVId");
        getProfileOrThrow(senderVId);

        if (!chatParticipantRepository.existsByRoomIdAndParticipantVId(normalizedRoomId, senderVId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "sender is not a participant of this room");
        }

        Long replyToId = request.replyToId();
        if (replyToId != null && !chatMessageRepository.existsById(replyToId)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "replyToId does not exist");
        }

        String messageType = normalizeMessageType(request.messageType());
        String messageText = trimToNull(request.messageText());
        String mediaUrl = trimToNull(request.mediaUrl());

        if (messageText == null && mediaUrl == null && !"SYSTEM".equals(messageType)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "messageText or mediaUrl is required");
        }

        ChatMessage message = new ChatMessage();
        message.setRoomId(normalizedRoomId);
        message.setSenderVId(senderVId);
        message.setMessageText(messageText == null ? "" : messageText);
        message.setMediaUrl(mediaUrl);
        message.setMessageType(messageType);
        message.setReplyToId(replyToId);

        ChatMessage savedMessage = chatMessageRepository.save(message);
        chatCacheService.put(toSnapshot(savedMessage));

        return toMessageResponse(savedMessage);
    }

    private Profile getProfileOrThrow(Long vId) {
        return profileRepository.findById(vId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "profile not found: " + vId));
    }

    private ChatRoom getRoomOrThrow(Long roomId) {
        return chatRoomRepository.findById(roomId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "chat room not found: " + roomId));
    }

    private LinkedHashSet<Long> normalizeParticipantIds(List<Long> participantIds, Long createdBy) {
        LinkedHashSet<Long> normalized = new LinkedHashSet<>();
        if (participantIds != null) {
            for (Long participantId : participantIds) {
                Long normalizedId = requirePositiveId(participantId, "participantId");
                normalized.add(normalizedId);
            }
        }
        normalized.add(createdBy);
        return normalized;
    }

    private String normalizeRoomType(String roomType, int participantCount) {
        if (roomType == null || roomType.isBlank()) {
            return participantCount > 2 ? "group" : "private";
        }

        String normalized = roomType.trim().toLowerCase();
        if (!"private".equals(normalized) && !"group".equals(normalized)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "roomType must be private or group");
        }

        if ("private".equals(normalized) && participantCount != 2) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "private rooms must contain exactly two users");
        }

        if ("group".equals(normalized) && participantCount < 3) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "group rooms must contain at least three users");
        }

        return normalized;
    }

    private String normalizeMessageType(String messageType) {
        if (messageType == null || messageType.isBlank()) {
            return "TEXT";
        }

        return messageType.trim().toUpperCase();
    }

    private Long requirePositiveId(Long value, String fieldName) {
        if (value == null || value <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, fieldName + " is required");
        }

        return value;
    }

    private String trimToNull(String value) {
        if (value == null) {
            return null;
        }

        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private List<Long> getParticipantIds(Long roomId) {
        return chatParticipantRepository.findByRoomId(roomId)
                .stream()
            .map(ChatParticipant::getParticipantVId)
                .toList();
    }

    private ChatRoomResponse toRoomResponse(ChatRoom room, List<Long> participantIds) {
        return new ChatRoomResponse(
                room.getRoomId(),
                room.getRoomName(),
                room.getRoomType(),
                room.getCreatedBy(),
                room.getCreatedAt(),
                room.getUpdatedAt(),
                List.copyOf(participantIds)
        );
    }

    private ChatMessageResponse toMessageResponse(ChatMessage message) {
        return new ChatMessageResponse(
                message.getMessageId(),
                message.getRoomId(),
                message.getSenderVId(),
                message.getMessageText(),
                message.getMediaUrl(),
                message.getMessageType(),
                message.getReplyToId(),
                message.getIsDeleted(),
                message.getCreatedAt()
        );
    }

    private ChatMessageResponse toMessageResponse(ChatMessageSnapshot snapshot) {
        return new ChatMessageResponse(
                snapshot.messageId(),
                snapshot.roomId(),
                snapshot.senderVId(),
                snapshot.messageText(),
                snapshot.mediaUrl(),
                snapshot.messageType(),
                null,
                Boolean.FALSE,
                OffsetDateTime.ofInstant(snapshot.createdAt(), ZoneOffset.UTC)
        );
    }

    private ChatMessageSnapshot toSnapshot(ChatMessage message) {
        return new ChatMessageSnapshot(
                message.getMessageId(),
                message.getRoomId(),
                message.getSenderVId(),
                message.getMessageText(),
                message.getMediaUrl(),
                message.getMessageType(),
                message.getCreatedAt().toInstant()
        );
    }
}