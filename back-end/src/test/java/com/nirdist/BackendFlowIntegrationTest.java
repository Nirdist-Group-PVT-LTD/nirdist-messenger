package com.nirdist;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.when;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.nirdist.auth.FirebaseTokenVerifier;
import com.nirdist.auth.FirebaseVerifiedUser;
import com.nirdist.chat.cache.ChatCacheService;
import com.nirdist.dto.AuthResponse;
import com.nirdist.dto.ChatMessageRequest;
import com.nirdist.dto.ChatMessageResponse;
import com.nirdist.dto.ChatRoomCreateRequest;
import com.nirdist.dto.ChatRoomResponse;
import com.nirdist.dto.CommunicationPermissionResponse;
import com.nirdist.dto.ContactSyncItem;
import com.nirdist.dto.ContactSyncRequest;
import com.nirdist.dto.ContactSyncResponse;
import com.nirdist.dto.FirebaseAuthExchangeRequest;
import com.nirdist.dto.FriendRequestActionRequest;
import com.nirdist.dto.FriendRequestCreateRequest;
import com.nirdist.dto.FriendRequestResponse;
import com.nirdist.dto.PhoneAuthExchangeRequest;
import com.nirdist.dto.ProfileResponse;
import com.nirdist.entity.ContactSyncEntry;
import com.nirdist.entity.Profile;
import com.nirdist.repository.ChatMessageRepository;
import com.nirdist.repository.ChatParticipantRepository;
import com.nirdist.repository.ChatRoomRepository;
import com.nirdist.repository.ContactSyncEntryRepository;
import com.nirdist.repository.FriendRequestRepository;
import com.nirdist.repository.ProfileRepository;
import com.nirdist.security.JwtTokenProvider;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class BackendFlowIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private ProfileRepository profileRepository;

    @Autowired
    private FriendRequestRepository friendRequestRepository;

    @Autowired
    private ContactSyncEntryRepository contactSyncEntryRepository;

    @Autowired
    private ChatRoomRepository chatRoomRepository;

    @Autowired
    private ChatMessageRepository chatMessageRepository;

    @Autowired
    private ChatParticipantRepository chatParticipantRepository;

    @Autowired
    private ChatCacheService chatCacheService;

    @MockBean
    private FirebaseTokenVerifier firebaseTokenVerifier;

    @MockBean
    private JwtTokenProvider jwtTokenProvider;

    private final Set<Long> roomIdsToClear = new LinkedHashSet<>();

    @BeforeEach
    void setUp() {
        reset(firebaseTokenVerifier, jwtTokenProvider);
        when(jwtTokenProvider.generateToken(any(Profile.class))).thenAnswer(invocation -> {
            Profile profile = invocation.getArgument(0, Profile.class);
            return "jwt-" + profile.getVId();
        });
    }

    @AfterEach
    void tearDown() {
        for (Long roomId : roomIdsToClear) {
            chatCacheService.clearRoom(roomId);
        }
        roomIdsToClear.clear();

        chatMessageRepository.deleteAll();
        chatParticipantRepository.deleteAll();
        chatRoomRepository.deleteAll();
        contactSyncEntryRepository.deleteAll();
        friendRequestRepository.deleteAll();
        profileRepository.deleteAll();
    }

    @Test
    void authExchangeCreatesAndUpdatesProfile() throws Exception {
        FirebaseVerifiedUser firebaseUser = firebaseUser(
                "firebase-alice",
                " +1 (555) 000-0001 "
        );

        AuthResponse createdResponse = exchangeAuth(
                "alice-token",
                firebaseUser,
                new FirebaseAuthExchangeRequest(
                        "alice-token",
                        "alice",
                        "Alice",
                        "alice@example.com",
                        "https://cdn.example.com/alice.png"
                )
        );

        assertThat(createdResponse.created()).isTrue();
        assertThat(createdResponse.message()).isEqualTo("Signup successful");
        assertThat(createdResponse.token()).isEqualTo("jwt-" + createdResponse.profile().vId());
        assertThat(createdResponse.profile().username()).isEqualTo("alice");
        assertThat(createdResponse.profile().displayName()).isEqualTo("Alice");
        assertThat(createdResponse.profile().phoneNumber()).isEqualTo("+15550000001");

        AuthResponse loginResponse = exchangeAuth(
                "alice-token",
                firebaseUser,
                new FirebaseAuthExchangeRequest(
                        "alice-token",
                        "ignored-username",
                        "Alice Updated",
                        null,
                        null
                )
        );

        assertThat(loginResponse.created()).isFalse();
        assertThat(loginResponse.message()).isEqualTo("Login successful");
        assertThat(loginResponse.profile().vId()).isEqualTo(createdResponse.profile().vId());
        assertThat(loginResponse.profile().username()).isEqualTo("alice");
        assertThat(loginResponse.profile().displayName()).isEqualTo("Alice Updated");
        assertThat(profileRepository.findByFirebaseUid("firebase-alice")).isPresent();
        assertThat(profileRepository.count()).isEqualTo(1);
    }

    @Test
    void phoneExchangeCreatesAndUpdatesProfileWithoutVerification() throws Exception {
        AuthResponse createdResponse = exchangePhoneAuth(
                new PhoneAuthExchangeRequest(
                        " +1 (555) 100-0001 ",
                        "temp.alice",
                        "Temp Alice",
                        "alice@example.com",
                        "https://cdn.example.com/alice.png"
                )
        );

        assertThat(createdResponse.created()).isTrue();
        assertThat(createdResponse.message()).isEqualTo("Signup successful");
        assertThat(createdResponse.token()).isEqualTo("jwt-" + createdResponse.profile().vId());
        assertThat(createdResponse.profile().username()).isEqualTo("temp.alice");
        assertThat(createdResponse.profile().displayName()).isEqualTo("Temp Alice");
        assertThat(createdResponse.profile().phoneNumber()).isEqualTo("+15551000001");
        assertThat(createdResponse.profile().firebaseUid()).isEqualTo("direct-phone:+15551000001");
        assertThat(createdResponse.profile().phoneVerifiedAt()).isNull();

        AuthResponse loginResponse = exchangePhoneAuth(
                new PhoneAuthExchangeRequest(
                        " +1 (555) 100-0001 ",
                        "ignored-username",
                        "Temp Alice Updated",
                        null,
                        null
                )
        );

        assertThat(loginResponse.created()).isFalse();
        assertThat(loginResponse.message()).isEqualTo("Login successful");
        assertThat(loginResponse.profile().vId()).isEqualTo(createdResponse.profile().vId());
        assertThat(loginResponse.profile().username()).isEqualTo("temp.alice");
        assertThat(loginResponse.profile().displayName()).isEqualTo("Temp Alice Updated");
        assertThat(loginResponse.profile().phoneNumber()).isEqualTo("+15551000001");
        assertThat(loginResponse.profile().firebaseUid()).isEqualTo("direct-phone:+15551000001");
        assertThat(loginResponse.profile().phoneVerifiedAt()).isNull();
    }

    @Test
    void contactSyncExposesMatchedAndSuggestedUsers() throws Exception {
        ProfileResponse alice = createUser(
                "alice-token",
                firebaseUser("firebase-alice", "+1 (555) 000-0001"),
                "alice",
                "Alice",
                "alice@example.com"
        ).profile();
        ProfileResponse bob = createUser(
                "bob-token",
                firebaseUser("firebase-bob", "+1 (555) 000-0002"),
                "bob",
                "Bob",
                "bob@example.com"
        ).profile();

        ContactSyncResponse syncResponse = syncContacts(alice.vId(), List.of(
                new ContactSyncItem("Bob Contact", " 1-555-000-0002 "),
                new ContactSyncItem("Self Contact", "+1 (555) 000-0001"),
                new ContactSyncItem("Unknown Contact", "555-000-9999")
        ));

        assertThat(syncResponse.userId()).isEqualTo(alice.vId());
        assertThat(syncResponse.contactCount()).isEqualTo(2);
        assertThat(syncResponse.matchedCount()).isEqualTo(1);
        assertThat(syncResponse.matchedUsers()).extracting(ProfileResponse::vId).containsExactly(bob.vId());
        assertThat(syncResponse.suggestedUsers()).extracting(ProfileResponse::vId).containsExactly(bob.vId());
        assertThat(contactSyncEntryRepository.findByProfileVId(alice.vId()))
                .extracting(ContactSyncEntry::getNormalizedPhone)
                .containsExactlyInAnyOrder("+15550000002", "+5550009999");

        CommunicationPermissionResponse preFriendMessagePermission = getPermission("/api/social/permissions/message", alice.vId(), bob.vId());
        CommunicationPermissionResponse preFriendCallPermission = getPermission("/api/social/permissions/call", alice.vId(), bob.vId());
        assertThat(preFriendMessagePermission.allowed()).isFalse();
        assertThat(preFriendMessagePermission.reason()).isEqualTo("accepted friendship required");
        assertThat(preFriendCallPermission.allowed()).isFalse();
        assertThat(preFriendCallPermission.reason()).isEqualTo("accepted friendship required");

        FriendRequestResponse requestResponse = sendFriendRequest(alice.vId(), bob.vId(), "Let's connect");
        FriendRequestResponse acceptedRequest = acceptFriendRequest(requestResponse.requestId(), bob.vId());
        assertThat(acceptedRequest.requestStatus()).isEqualTo("ACCEPTED");

        CommunicationPermissionResponse postFriendMessagePermission = getPermission("/api/social/permissions/message", alice.vId(), bob.vId());
        CommunicationPermissionResponse postFriendCallPermission = getPermission("/api/social/permissions/call", alice.vId(), bob.vId());
        assertThat(postFriendMessagePermission.allowed()).isTrue();
        assertThat(postFriendCallPermission.allowed()).isTrue();

        List<ProfileResponse> friends = listFriends(alice.vId());
        assertThat(friends).extracting(ProfileResponse::vId).containsExactly(bob.vId());
        assertThat(getSuggestions(alice.vId())).isEmpty();
    }

        @Test
        void profileSearchFindsOtherUsersAndExcludesSelf() throws Exception {
                ProfileResponse alice = createUser(
                                "alice-search-token",
                                firebaseUser("firebase-search-alice", "+1 (555) 200-0001"),
                                "alice-search",
                                "Alice Search",
                                "alice.search@example.com"
                ).profile();
                ProfileResponse bob = createUser(
                                "bob-search-token",
                                firebaseUser("firebase-search-bob", "+1 (555) 200-0002"),
                                "bobby.chat",
                                "Bobby Chat",
                                "bobby.chat@example.com"
                ).profile();

                List<ProfileResponse> matches = searchProfiles("bobby", alice.vId());
                assertThat(matches).extracting(ProfileResponse::vId).containsExactly(bob.vId());
                assertThat(searchProfiles("alice", alice.vId())).isEmpty();
        }

                @Test
                void profileSearchMatchesIdentifiersAndSingleWordQueries() throws Exception {
                        ProfileResponse alice = createUser(
                                        "alice-identifiers-token",
                                        firebaseUser("firebase-identifiers-alice", "+1 (555) 400-0001"),
                                        "alice.identifiers",
                                        "Alice Identifiers",
                                        "alice.identifiers@example.com"
                        ).profile();
                        ProfileResponse bob = createUser(
                                        "bob-identifiers-token",
                                        firebaseUser("firebase-identifiers-bob", "+1 (555) 400-0002"),
                                        "bob.identifiers",
                                        "Bob Identifiers",
                                        "bob.identifiers@example.com"
                        ).profile();

                        assertThat(searchProfiles(alice.vId().toString(), bob.vId()))
                                        .extracting(ProfileResponse::vId)
                                        .containsExactly(alice.vId());

                        assertThat(searchProfiles("4000001", bob.vId()))
                                        .extracting(ProfileResponse::vId)
                                        .containsExactly(alice.vId());

                        assertThat(searchProfiles("alice", bob.vId()))
                                        .extracting(ProfileResponse::vId)
                                        .containsExactly(alice.vId());

                        assertThat(searchProfiles("identifiers", bob.vId()))
                                        .extracting(ProfileResponse::vId)
                                        .containsExactly(alice.vId());
                }

            @Test
            void profileDirectoryListsEveryoneExceptSelf() throws Exception {
                ProfileResponse alice = createUser(
                        "alice-directory-token",
                        firebaseUser("firebase-directory-alice", "+1 (555) 300-0001"),
                        "alice-directory",
                        "Alice Directory",
                        "alice.directory@example.com"
                ).profile();
                ProfileResponse bob = createUser(
                        "bob-directory-token",
                        firebaseUser("firebase-directory-bob", "+1 (555) 300-0002"),
                        "bob-directory",
                        "Bob Directory",
                        "bob.directory@example.com"
                ).profile();
                ProfileResponse cara = createUser(
                        "cara-directory-token",
                        firebaseUser("firebase-directory-cara", "+1 (555) 300-0003"),
                        "cara-directory",
                        "Cara Directory",
                        "cara.directory@example.com"
                ).profile();

                List<ProfileResponse> directory = listProfiles(alice.vId());
                assertThat(directory).extracting(ProfileResponse::vId).containsExactly(bob.vId(), cara.vId());
            }

    @Test
    void chatFlowRequiresAcceptedFriendshipAndCachesRecentMessages() throws Exception {
        ProfileResponse alice = createUser(
                "alice-chat-token",
                firebaseUser("firebase-chat-alice", "+1 (555) 100-0001"),
                "alice-chat",
                "Alice Chat",
                "alice.chat@example.com"
        ).profile();
        ProfileResponse bob = createUser(
                "bob-chat-token",
                firebaseUser("firebase-chat-bob", "+1 (555) 100-0002"),
                "bob-chat",
                "Bob Chat",
                "bob.chat@example.com"
        ).profile();

        mockMvc.perform(post("/api/chat/rooms")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ChatRoomCreateRequest(
                                alice.vId(),
                                "Alice and Bob",
                                "private",
                                List.of(bob.vId())
                        ))))
                .andExpect(status().isForbidden());

        FriendRequestResponse requestResponse = sendFriendRequest(alice.vId(), bob.vId(), "Let's chat");
        acceptFriendRequest(requestResponse.requestId(), bob.vId());

        ChatRoomResponse roomResponse = createRoom(alice.vId(), bob.vId());
        roomIdsToClear.add(roomResponse.roomId());
        assertThat(roomResponse.roomType()).isEqualTo("private");
        assertThat(new LinkedHashSet<>(roomResponse.participantIds())).containsExactlyInAnyOrder(alice.vId(), bob.vId());

        ChatMessageResponse sentMessage = sendMessage(roomResponse.roomId(), alice.vId(), "Hello Bob");
        assertThat(sentMessage.messageText()).isEqualTo("Hello Bob");
        assertThat(sentMessage.messageType()).isEqualTo("TEXT");

        List<ChatMessageResponse> messageHistory = listMessages(roomResponse.roomId());
        List<ChatMessageResponse> recentMessages = listRecentMessages(roomResponse.roomId());
        List<ChatRoomResponse> roomsForAlice = listRooms(alice.vId());

        assertThat(messageHistory).hasSize(1);
        assertThat(messageHistory.get(0).messageText()).isEqualTo("Hello Bob");
        assertThat(recentMessages).hasSize(1);
        assertThat(recentMessages.get(0).messageText()).isEqualTo("Hello Bob");
        assertThat(roomsForAlice).extracting(ChatRoomResponse::roomId).containsExactly(roomResponse.roomId());
    }

    private AuthResponse createUser(String idToken, FirebaseVerifiedUser firebaseUser, String username, String displayName, String email) throws Exception {
        return exchangeAuth(idToken, firebaseUser, new FirebaseAuthExchangeRequest(idToken, username, displayName, email, null));
    }

    private AuthResponse exchangeAuth(String idToken, FirebaseVerifiedUser firebaseUser, FirebaseAuthExchangeRequest request) throws Exception {
        when(firebaseTokenVerifier.verify(idToken)).thenReturn(firebaseUser);

        MvcResult result = mockMvc.perform(post("/api/auth/firebase/exchange")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().is2xxSuccessful())
                .andReturn();

        return objectMapper.readValue(result.getResponse().getContentAsString(), AuthResponse.class);
    }

        private AuthResponse exchangePhoneAuth(PhoneAuthExchangeRequest request) throws Exception {
                MvcResult result = mockMvc.perform(post("/api/auth/phone/exchange")
                                                .contentType(MediaType.APPLICATION_JSON)
                                                .content(objectMapper.writeValueAsString(request)))
                                .andExpect(status().is2xxSuccessful())
                                .andReturn();

                return objectMapper.readValue(result.getResponse().getContentAsString(), AuthResponse.class);
        }

    private FriendRequestResponse sendFriendRequest(Long requesterVId, Long addresseeVId, String message) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/social/friend-requests")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new FriendRequestCreateRequest(requesterVId, addresseeVId, message))))
                .andExpect(status().isCreated())
                .andReturn();

        return objectMapper.readValue(result.getResponse().getContentAsString(), FriendRequestResponse.class);
    }

    private FriendRequestResponse acceptFriendRequest(Long requestId, Long actorVId) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/social/friend-requests/{requestId}/accept", requestId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new FriendRequestActionRequest(actorVId))))
                .andExpect(status().isOk())
                .andReturn();

        return objectMapper.readValue(result.getResponse().getContentAsString(), FriendRequestResponse.class);
    }

    private ContactSyncResponse syncContacts(Long userId, List<ContactSyncItem> contacts) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/social/contacts/sync")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ContactSyncRequest(userId, contacts))))
                .andExpect(status().isOk())
                .andReturn();

        return objectMapper.readValue(result.getResponse().getContentAsString(), ContactSyncResponse.class);
    }

    private List<ProfileResponse> searchProfiles(String query, Long excludeUserId) throws Exception {
        MvcResult result = mockMvc.perform(get("/api/social/profiles/search")
                        .param("q", query)
                        .param("excludeUserId", excludeUserId.toString()))
                .andExpect(status().isOk())
                .andReturn();

        return objectMapper.readerForListOf(ProfileResponse.class)
                .readValue(result.getResponse().getContentAsString());
    }

    private List<ProfileResponse> listProfiles(Long excludeUserId) throws Exception {
        MvcResult result = mockMvc.perform(get("/api/social/profiles")
                        .param("excludeUserId", excludeUserId.toString()))
                .andExpect(status().isOk())
                .andReturn();

        return objectMapper.readerForListOf(ProfileResponse.class)
                .readValue(result.getResponse().getContentAsString());
    }

    private List<ProfileResponse> listFriends(Long userId) throws Exception {
        MvcResult result = mockMvc.perform(get("/api/social/friends/{userId}", userId))
                .andExpect(status().isOk())
                .andReturn();

        return objectMapper.readerForListOf(ProfileResponse.class).readValue(result.getResponse().getContentAsString());
    }

    private List<ProfileResponse> getSuggestions(Long userId) throws Exception {
        MvcResult result = mockMvc.perform(get("/api/social/suggestions/{userId}", userId))
                .andExpect(status().isOk())
                .andReturn();

        return objectMapper.readerForListOf(ProfileResponse.class).readValue(result.getResponse().getContentAsString());
    }

    private CommunicationPermissionResponse getPermission(String path, Long userId, Long otherUserId) throws Exception {
        MvcResult result = mockMvc.perform(get(path)
                        .param("userId", String.valueOf(userId))
                        .param("otherUserId", String.valueOf(otherUserId)))
                .andExpect(status().isOk())
                .andReturn();

        return objectMapper.readValue(result.getResponse().getContentAsString(), CommunicationPermissionResponse.class);
    }

    private ChatRoomResponse createRoom(Long creatorVId, Long otherUserId) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/chat/rooms")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ChatRoomCreateRequest(
                                creatorVId,
                                "Alice and Bob",
                                "private",
                                List.of(otherUserId)
                        ))))
                .andExpect(status().isCreated())
                .andReturn();

        return objectMapper.readValue(result.getResponse().getContentAsString(), ChatRoomResponse.class);
    }

    private ChatMessageResponse sendMessage(Long roomId, Long senderVId, String messageText) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/chat/rooms/{roomId}/messages", roomId)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ChatMessageRequest(senderVId, messageText, null, null, null))))
                .andExpect(status().isCreated())
                .andReturn();

        return objectMapper.readValue(result.getResponse().getContentAsString(), ChatMessageResponse.class);
    }

    private List<ChatMessageResponse> listMessages(Long roomId) throws Exception {
        MvcResult result = mockMvc.perform(get("/api/chat/rooms/{roomId}/messages", roomId))
                .andExpect(status().isOk())
                .andReturn();

        return objectMapper.readerForListOf(ChatMessageResponse.class).readValue(result.getResponse().getContentAsString());
    }

    private List<ChatMessageResponse> listRecentMessages(Long roomId) throws Exception {
        MvcResult result = mockMvc.perform(get("/api/chat/rooms/{roomId}/recent", roomId))
                .andExpect(status().isOk())
                .andReturn();

        return objectMapper.readerForListOf(ChatMessageResponse.class).readValue(result.getResponse().getContentAsString());
    }

        private List<ChatRoomResponse> listRooms(Long userId) throws Exception {
                MvcResult result = mockMvc.perform(get("/api/chat/rooms").param("userId", String.valueOf(userId)))
                                .andExpect(status().isOk())
                                .andReturn();

                return objectMapper.readerForListOf(ChatRoomResponse.class).readValue(result.getResponse().getContentAsString());
        }

        private FirebaseVerifiedUser firebaseUser(String uid, String phoneNumber) {
                return new FirebaseVerifiedUser(uid, phoneNumber);
    }
}