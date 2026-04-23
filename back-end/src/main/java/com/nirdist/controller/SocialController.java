package com.nirdist.controller;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.nirdist.dto.CommunicationPermissionResponse;
import com.nirdist.dto.ContactSyncRequest;
import com.nirdist.dto.ContactSyncResponse;
import com.nirdist.dto.FriendRequestActionRequest;
import com.nirdist.dto.FriendRequestCreateRequest;
import com.nirdist.dto.FriendRequestResponse;
import com.nirdist.dto.ProfileResponse;
import com.nirdist.service.SocialGraphService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/social")
@CrossOrigin(origins = "*")
public class SocialController {

    private final SocialGraphService socialGraphService;

    public SocialController(SocialGraphService socialGraphService) {
        this.socialGraphService = socialGraphService;
    }

    @PostMapping("/friend-requests")
    public ResponseEntity<FriendRequestResponse> sendFriendRequest(@Valid @RequestBody FriendRequestCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(socialGraphService.sendFriendRequest(request));
    }

    @PostMapping("/friend-requests/{requestId}/accept")
    public FriendRequestResponse acceptFriendRequest(@PathVariable Long requestId, @Valid @RequestBody FriendRequestActionRequest request) {
        return socialGraphService.acceptFriendRequest(requestId, request);
    }

    @PostMapping("/friend-requests/{requestId}/reject")
    public FriendRequestResponse rejectFriendRequest(@PathVariable Long requestId, @Valid @RequestBody FriendRequestActionRequest request) {
        return socialGraphService.rejectFriendRequest(requestId, request);
    }

    @GetMapping("/friends/{userId}")
    public List<ProfileResponse> listFriends(@PathVariable Long userId) {
        return socialGraphService.listFriends(userId);
    }

    @PostMapping("/contacts/sync")
    public ResponseEntity<ContactSyncResponse> syncContacts(@Valid @RequestBody ContactSyncRequest request) {
        return ResponseEntity.ok(socialGraphService.syncContacts(request));
    }

    @GetMapping("/suggestions/{userId}")
    public List<ProfileResponse> getSuggestions(@PathVariable Long userId) {
        return socialGraphService.getSuggestions(userId);
    }

    @GetMapping("/profiles")
    public List<ProfileResponse> listProfiles(@RequestParam(required = false) Long excludeUserId) {
        return socialGraphService.listProfiles(excludeUserId);
    }

    @GetMapping("/profiles/search")
    public List<ProfileResponse> searchProfiles(
            @RequestParam String q,
            @RequestParam(required = false) Long excludeUserId
    ) {
        return socialGraphService.searchProfiles(q, excludeUserId);
    }

    @GetMapping("/permissions/message")
    public CommunicationPermissionResponse canMessage(
            @RequestParam Long userId,
            @RequestParam Long otherUserId
    ) {
        return socialGraphService.canMessage(userId, otherUserId);
    }

    @GetMapping("/permissions/call")
    public CommunicationPermissionResponse canCall(
            @RequestParam Long userId,
            @RequestParam Long otherUserId
    ) {
        return socialGraphService.canCall(userId, otherUserId);
    }
}