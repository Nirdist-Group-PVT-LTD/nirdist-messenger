package com.nirdist.service;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.nirdist.dto.CommunicationPermissionResponse;
import com.nirdist.dto.ContactSyncItem;
import com.nirdist.dto.ContactSyncRequest;
import com.nirdist.dto.ContactSyncResponse;
import com.nirdist.dto.FriendRequestActionRequest;
import com.nirdist.dto.FriendRequestCreateRequest;
import com.nirdist.dto.FriendRequestResponse;
import com.nirdist.dto.ProfileResponse;
import com.nirdist.entity.ContactSyncEntry;
import com.nirdist.entity.FriendRequest;
import com.nirdist.entity.Profile;
import com.nirdist.repository.ContactSyncEntryRepository;
import com.nirdist.repository.FriendRequestRepository;
import com.nirdist.repository.ProfileRepository;
import com.nirdist.util.PhoneNumberNormalizer;

@Service
@Transactional
public class SocialGraphService {

    private static final String STATUS_PENDING = "PENDING";
    private static final String STATUS_ACCEPTED = "ACCEPTED";
    private static final String STATUS_REJECTED = "REJECTED";
    private static final String STATUS_CANCELLED = "CANCELLED";
    private static final List<String> ACTIVE_CONNECTION_STATUSES = List.of(STATUS_PENDING, STATUS_ACCEPTED);

    private final ProfileRepository profileRepository;
    private final FriendRequestRepository friendRequestRepository;
    private final ContactSyncEntryRepository contactSyncEntryRepository;

    public SocialGraphService(
            ProfileRepository profileRepository,
            FriendRequestRepository friendRequestRepository,
            ContactSyncEntryRepository contactSyncEntryRepository
    ) {
        this.profileRepository = profileRepository;
        this.friendRequestRepository = friendRequestRepository;
        this.contactSyncEntryRepository = contactSyncEntryRepository;
    }

    public FriendRequestResponse sendFriendRequest(FriendRequestCreateRequest request) {
        if (request == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "request body is required");
        }

        Long requesterVId = requirePositiveId(request.requesterVId(), "requesterVId");
        Long addresseeVId = requirePositiveId(request.addresseeVId(), "addresseeVId");
        if (Objects.equals(requesterVId, addresseeVId)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "requester and addressee must be different users");
        }

        Profile requester = getProfileOrThrow(requesterVId);
        Profile addressee = getProfileOrThrow(addresseeVId);

        if (areFriends(requesterVId, addresseeVId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "these users are already friends");
        }

        if (hasActiveConnectionBetween(requesterVId, addresseeVId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "a pending request already exists between these users");
        }

        FriendRequest friendRequest = new FriendRequest();
        friendRequest.setRequesterVId(requesterVId);
        friendRequest.setAddresseeVId(addresseeVId);
        friendRequest.setRequestMessage(trimToNull(request.requestMessage()));
        friendRequest.setRequestStatus(STATUS_PENDING);

        return toFriendRequestResponse(friendRequestRepository.save(friendRequest), requester, addressee);
    }

    public FriendRequestResponse acceptFriendRequest(Long requestId, FriendRequestActionRequest request) {
        FriendRequest friendRequest = getPendingRequestOrThrow(requestId);
        Long actorVId = requirePositiveId(request == null ? null : request.actorVId(), "actorVId");
        if (!Objects.equals(friendRequest.getAddresseeVId(), actorVId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "only the addressee can accept this request");
        }

        Profile requester = getProfileOrThrow(friendRequest.getRequesterVId());
        Profile addressee = getProfileOrThrow(friendRequest.getAddresseeVId());

        friendRequest.setRequestStatus(STATUS_ACCEPTED);
        friendRequest.setRespondedByVId(actorVId);
        friendRequest.setRespondedAt(OffsetDateTime.now());
        FriendRequest savedRequest = friendRequestRepository.save(friendRequest);

        cancelReversePendingRequest(savedRequest);
        return toFriendRequestResponse(savedRequest, requester, addressee);
    }

    public FriendRequestResponse rejectFriendRequest(Long requestId, FriendRequestActionRequest request) {
        FriendRequest friendRequest = getPendingRequestOrThrow(requestId);
        Long actorVId = requirePositiveId(request == null ? null : request.actorVId(), "actorVId");
        if (!Objects.equals(friendRequest.getAddresseeVId(), actorVId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "only the addressee can reject this request");
        }

        Profile requester = getProfileOrThrow(friendRequest.getRequesterVId());
        Profile addressee = getProfileOrThrow(friendRequest.getAddresseeVId());

        friendRequest.setRequestStatus(STATUS_REJECTED);
        friendRequest.setRespondedByVId(actorVId);
        friendRequest.setRespondedAt(OffsetDateTime.now());
        FriendRequest savedRequest = friendRequestRepository.save(friendRequest);

        return toFriendRequestResponse(savedRequest, requester, addressee);
    }

    public List<ProfileResponse> listFriends(Long userId) {
        Long normalizedUserId = requirePositiveId(userId, "userId");
        getProfileOrThrow(normalizedUserId);

        List<FriendRequest> acceptedConnections = friendRequestRepository.findAcceptedConnectionsForUser(normalizedUserId);
        if (acceptedConnections.isEmpty()) {
            return List.of();
        }

        LinkedHashMap<Long, ProfileResponse> friendsById = new LinkedHashMap<>();
        for (FriendRequest connection : acceptedConnections) {
            Long friendId = getOtherUserId(connection, normalizedUserId);
            friendsById.putIfAbsent(friendId, toProfileResponse(getProfileOrThrow(friendId)));
        }

        return new ArrayList<>(friendsById.values());
    }

    public ContactSyncResponse syncContacts(ContactSyncRequest request) {
        if (request == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "request body is required");
        }

        Long userId = requirePositiveId(request.userId(), "userId");
        Profile owner = getProfileOrThrow(userId);

        LinkedHashMap<String, ContactSyncItem> uniqueContacts = new LinkedHashMap<>();
        List<ContactSyncItem> incomingContacts = request.contacts() == null ? List.of() : request.contacts();
        for (ContactSyncItem contact : incomingContacts) {
            if (contact == null) {
                continue;
            }

            String normalizedPhone = PhoneNumberNormalizer.normalize(contact.phoneNumber());
            if (normalizedPhone == null || Objects.equals(normalizedPhone, owner.getPhoneNumber())) {
                continue;
            }

            uniqueContacts.putIfAbsent(normalizedPhone, new ContactSyncItem(trimToNull(contact.contactName()), normalizedPhone));
        }

        contactSyncEntryRepository.deleteByProfileVId(userId);

        Map<String, Profile> matchedProfilesByPhone = profileRepository.findByPhoneNumberIn(new ArrayList<>(uniqueContacts.keySet()))
                .stream()
                .collect(Collectors.toMap(Profile::getPhoneNumber, profile -> profile, (left, right) -> left, LinkedHashMap::new));

        List<ContactSyncEntry> entries = new ArrayList<>();
        LinkedHashMap<Long, Profile> matchedProfiles = new LinkedHashMap<>();
        for (Map.Entry<String, ContactSyncItem> entry : uniqueContacts.entrySet()) {
            String normalizedPhone = entry.getKey();
            ContactSyncItem contact = entry.getValue();
            Profile matchedProfile = matchedProfilesByPhone.get(normalizedPhone);

            ContactSyncEntry syncEntry = new ContactSyncEntry();
            syncEntry.setProfileVId(userId);
            syncEntry.setContactName(contact.contactName());
            syncEntry.setContactPhone(trimToNull(contact.phoneNumber()));
            syncEntry.setNormalizedPhone(normalizedPhone);
            syncEntry.setMatchedProfileVId(matchedProfile == null ? null : matchedProfile.getVId());
            syncEntry.setSource("PHONEBOOK");
            entries.add(syncEntry);

            if (matchedProfile != null && !Objects.equals(matchedProfile.getVId(), userId)) {
                matchedProfiles.putIfAbsent(matchedProfile.getVId(), matchedProfile);
            }
        }

        contactSyncEntryRepository.saveAll(entries);

        List<ProfileResponse> matchedUserResponses = matchedProfiles.values().stream()
                .map(this::toProfileResponse)
                .toList();
        List<ProfileResponse> suggestedUsers = getSuggestions(userId);

        return new ContactSyncResponse(userId, uniqueContacts.size(), matchedUserResponses.size(), matchedUserResponses, suggestedUsers);
    }

    public List<ProfileResponse> getSuggestions(Long userId) {
        Long normalizedUserId = requirePositiveId(userId, "userId");
        getProfileOrThrow(normalizedUserId);

        Set<Long> excludedUserIds = collectExcludedUserIds(normalizedUserId);
        List<ContactSyncEntry> matchedEntries = contactSyncEntryRepository.findByProfileVIdAndMatchedProfileVIdIsNotNull(normalizedUserId);

        LinkedHashMap<Long, ProfileResponse> suggestionsById = new LinkedHashMap<>();
        for (ContactSyncEntry entry : matchedEntries) {
            Long matchedProfileId = entry.getMatchedProfileVId();
            if (matchedProfileId == null || excludedUserIds.contains(matchedProfileId)) {
                continue;
            }

            suggestionsById.putIfAbsent(matchedProfileId, toProfileResponse(getProfileOrThrow(matchedProfileId)));
        }

        return new ArrayList<>(suggestionsById.values());
    }

    public CommunicationPermissionResponse canMessage(Long userId, Long otherUserId) {
        return buildPermissionResponse(userId, otherUserId, "message");
    }

    public CommunicationPermissionResponse canCall(Long userId, Long otherUserId) {
        return buildPermissionResponse(userId, otherUserId, "call");
    }

    public boolean areFriends(Long userA, Long userB) {
        Long normalizedUserA = requirePositiveId(userA, "userA");
        Long normalizedUserB = requirePositiveId(userB, "userB");
        if (Objects.equals(normalizedUserA, normalizedUserB)) {
            return false;
        }

        return friendRequestRepository.existsByRequesterVIdAndAddresseeVIdAndRequestStatus(normalizedUserA, normalizedUserB, STATUS_ACCEPTED)
                || friendRequestRepository.existsByRequesterVIdAndAddresseeVIdAndRequestStatus(normalizedUserB, normalizedUserA, STATUS_ACCEPTED);
    }

    public void requireRoomParticipantsAreFriends(Long creatorVId, Collection<Long> participantIds, String roomType) {
        Long normalizedCreatorId = requirePositiveId(creatorVId, "createdBy");
        Profile creator = getProfileOrThrow(normalizedCreatorId);

        LinkedHashSet<Long> normalizedParticipantIds = new LinkedHashSet<>();
        if (participantIds != null) {
            for (Long participantId : participantIds) {
                Long normalizedParticipantId = requirePositiveId(participantId, "participantId");
                normalizedParticipantIds.add(normalizedParticipantId);
                getProfileOrThrow(normalizedParticipantId);
            }
        }

        normalizedParticipantIds.add(normalizedCreatorId);

        if (roomType == null || roomType.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "roomType is required");
        }

        if ("private".equals(roomType)) {
            if (normalizedParticipantIds.size() != 2) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "private rooms must contain exactly two users");
            }
        } else if ("group".equals(roomType)) {
            if (normalizedParticipantIds.size() < 3) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "group rooms must contain at least three users");
            }
        } else {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "roomType must be private or group");
        }

        for (Long participantId : normalizedParticipantIds) {
            if (Objects.equals(participantId, normalizedCreatorId)) {
                continue;
            }

            if (!areFriends(normalizedCreatorId, participantId)) {
                throw new ResponseStatusException(HttpStatus.FORBIDDEN, "accepted friendship is required before messaging or calling");
            }
        }
    }

    private FriendRequest getPendingRequestOrThrow(Long requestId) {
        FriendRequest friendRequest = friendRequestRepository.findById(requirePositiveId(requestId, "requestId"))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "friend request not found: " + requestId));

        if (!STATUS_PENDING.equals(friendRequest.getRequestStatus())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "friend request is no longer pending");
        }

        return friendRequest;
    }

    private void cancelReversePendingRequest(FriendRequest acceptedRequest) {
        friendRequestRepository.findByRequesterVIdAndAddresseeVIdAndRequestStatus(
                        acceptedRequest.getAddresseeVId(),
                        acceptedRequest.getRequesterVId(),
                        STATUS_PENDING
                )
                .ifPresent(reverseRequest -> {
                    reverseRequest.setRequestStatus(STATUS_CANCELLED);
                    reverseRequest.setRespondedByVId(acceptedRequest.getAddresseeVId());
                    reverseRequest.setRespondedAt(OffsetDateTime.now());
                    friendRequestRepository.save(reverseRequest);
                });
    }

    private FriendRequestResponse toFriendRequestResponse(FriendRequest friendRequest, Profile requester, Profile addressee) {
        return new FriendRequestResponse(
                friendRequest.getRequestId(),
                toProfileResponse(requester),
                toProfileResponse(addressee),
                friendRequest.getRequestMessage(),
                friendRequest.getRequestStatus(),
                friendRequest.getRespondedByVId(),
                friendRequest.getRequestedAt(),
                friendRequest.getRespondedAt()
        );
    }

    private boolean hasActiveConnectionBetween(Long userA, Long userB) {
        return friendRequestRepository.existsByRequesterVIdAndAddresseeVIdAndRequestStatusIn(userA, userB, ACTIVE_CONNECTION_STATUSES)
                || friendRequestRepository.existsByRequesterVIdAndAddresseeVIdAndRequestStatusIn(userB, userA, ACTIVE_CONNECTION_STATUSES);
    }

    private Set<Long> collectExcludedUserIds(Long userId) {
        LinkedHashSet<Long> excludedUserIds = new LinkedHashSet<>();
        excludedUserIds.add(userId);

        for (FriendRequest connection : friendRequestRepository.findActiveConnectionsForUser(userId)) {
            excludedUserIds.add(getOtherUserId(connection, userId));
        }

        return excludedUserIds;
    }

    private CommunicationPermissionResponse buildPermissionResponse(Long userId, Long otherUserId, String actionName) {
        Long normalizedUserId = requirePositiveId(userId, "userId");
        Long normalizedOtherUserId = requirePositiveId(otherUserId, "otherUserId");
        if (Objects.equals(normalizedUserId, normalizedOtherUserId)) {
            return new CommunicationPermissionResponse(false, "cannot " + actionName + " yourself");
        }

        getProfileOrThrow(normalizedUserId);
        getProfileOrThrow(normalizedOtherUserId);

        boolean allowed = areFriends(normalizedUserId, normalizedOtherUserId);
        return new CommunicationPermissionResponse(allowed, allowed ? "allowed" : "accepted friendship required");
    }

    private Long getOtherUserId(FriendRequest friendRequest, Long userId) {
        if (Objects.equals(friendRequest.getRequesterVId(), userId)) {
            return friendRequest.getAddresseeVId();
        }

        return friendRequest.getRequesterVId();
    }

    private Profile getProfileOrThrow(Long vId) {
        return profileRepository.findById(requirePositiveId(vId, "vId"))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "profile not found: " + vId));
    }

    private Long requirePositiveId(Long value, String fieldName) {
        if (value == null || value <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, fieldName + " is required");
        }

        return value;
    }

    private ProfileResponse toProfileResponse(Profile profile) {
        return new ProfileResponse(
                profile.getVId(),
                profile.getUsername(),
                profile.getDisplayName(),
                profile.getEmail(),
                profile.getPhoneNumber(),
                profile.getFirebaseUid(),
                profile.getAvatarUrl(),
                profile.getBio(),
                profile.getPhoneVerifiedAt(),
                profile.getCreatedAt(),
                profile.getUpdatedAt()
        );
    }

    private String normalizePhoneNumber(String value) {
        String trimmed = trimToNull(value);
        if (trimmed == null) {
            return null;
        }

        String digitsOnly = trimmed.replaceAll("[^0-9]", "");
        if (digitsOnly.isBlank()) {
            return null;
        }

        if (trimmed.startsWith("+")) {
            return "+" + digitsOnly;
        }

        return digitsOnly;
    }

    private String trimToNull(String value) {
        if (value == null) {
            return null;
        }

        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}