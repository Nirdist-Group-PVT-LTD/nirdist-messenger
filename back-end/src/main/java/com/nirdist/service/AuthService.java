package com.nirdist.service;

import java.time.OffsetDateTime;
import java.util.Locale;
import java.util.Objects;
import java.util.Optional;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.nirdist.auth.FirebaseTokenVerifier;
import com.nirdist.auth.FirebaseVerifiedUser;
import com.nirdist.dto.AuthResponse;
import com.nirdist.dto.FirebaseAuthExchangeRequest;
import com.nirdist.dto.PhoneAuthExchangeRequest;
import com.nirdist.dto.ProfileResponse;
import com.nirdist.entity.Profile;
import com.nirdist.repository.ProfileRepository;
import com.nirdist.security.JwtTokenProvider;
import com.nirdist.util.PhoneNumberNormalizer;

@Service
@Transactional
public class AuthService {

    private final ProfileRepository profileRepository;
    private final FirebaseTokenVerifier firebaseTokenVerifier;
    private final JwtTokenProvider jwtTokenProvider;

    public AuthService(
            ProfileRepository profileRepository,
            FirebaseTokenVerifier firebaseTokenVerifier,
            JwtTokenProvider jwtTokenProvider
    ) {
        this.profileRepository = profileRepository;
        this.firebaseTokenVerifier = firebaseTokenVerifier;
        this.jwtTokenProvider = jwtTokenProvider;
    }

    public AuthResponse exchangePhoneNumber(PhoneAuthExchangeRequest request) {
        if (request == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "request body is required");
        }

        String phoneNumber = requirePhoneNumber(request.phoneNumber());

        Profile profile = profileRepository.findByPhoneNumber(phoneNumber)
                .orElseGet(Profile::new);
        boolean created = profile.getVId() == null;

        if (created || trimToNull(profile.getFirebaseUid()) == null) {
            profile.setFirebaseUid(buildDirectFirebaseUid(phoneNumber));
        }

        String username = resolveUsername(profile, request.username(), phoneNumber);
        String displayName = resolveDisplayName(request.displayName(), username);
        String email = firstNonBlank(request.email(), profile.getEmail());
        String avatarUrl = firstNonBlank(request.avatarUrl(), profile.getAvatarUrl());

        profile.setUsername(username);
        profile.setDisplayName(displayName);
        profile.setEmail(email);
        profile.setPhoneNumber(phoneNumber);
        profile.setAvatarUrl(avatarUrl);

        Profile savedProfile = profileRepository.saveAndFlush(profile);
        return buildAuthResponse(savedProfile, created);
    }

    public AuthResponse exchangeFirebaseToken(FirebaseAuthExchangeRequest request) {
        if (request == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "request body is required");
        }

        String idToken = trimToNull(request.idToken());
        if (idToken == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "idToken is required");
        }

        FirebaseVerifiedUser firebaseUser = firebaseTokenVerifier.verify(idToken);
        String phoneNumber = requirePhoneNumber(firebaseUser.phoneNumber());
        String firebaseUid = requireVerifiedUid(firebaseUser.uid());

        Profile profile = findExistingProfile(firebaseUid, phoneNumber)
                .orElseGet(Profile::new);
        boolean created = profile.getVId() == null;

        String username = resolveUsername(profile, request.username(), phoneNumber);
        String displayName = resolveDisplayName(request.displayName(), username);
        String email = firstNonBlank(request.email(), profile.getEmail());
        String avatarUrl = firstNonBlank(request.avatarUrl(), profile.getAvatarUrl());

        profile.setUsername(username);
        profile.setDisplayName(displayName);
        profile.setEmail(email);
        profile.setPhoneNumber(phoneNumber);
        profile.setFirebaseUid(firebaseUid);
        profile.setAvatarUrl(avatarUrl);
        profile.setPhoneVerifiedAt(OffsetDateTime.now());

        Profile savedProfile = profileRepository.save(profile);
        return buildAuthResponse(savedProfile, created);
    }

    private Optional<Profile> findExistingProfile(String firebaseUid, String phoneNumber) {
        Profile byFirebaseUid = profileRepository.findByFirebaseUid(firebaseUid).orElse(null);
        if (byFirebaseUid != null) {
            return Optional.of(byFirebaseUid);
        }

        return profileRepository.findByPhoneNumber(phoneNumber);
    }

    private AuthResponse buildAuthResponse(Profile savedProfile, boolean created) {
        String token = jwtTokenProvider.generateToken(savedProfile);

        return new AuthResponse(
                token,
                toProfileResponse(savedProfile),
                created ? "Signup successful" : "Login successful",
                created
        );
    }

    private String requirePhoneNumber(String phoneNumber) {
        String normalizedPhone = PhoneNumberNormalizer.normalize(phoneNumber);
        if (normalizedPhone == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "phone number is required");
        }

        return normalizedPhone;
    }

    private String requireVerifiedUid(String uid) {
        String normalizedUid = trimToNull(uid);
        if (normalizedUid == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Firebase token does not contain a user id");
        }

        return normalizedUid;
    }

    private String resolveUsername(Profile profile, String requestedUsername, String phoneNumber) {
        if (profile.getVId() != null && profile.getUsername() != null && !profile.getUsername().isBlank()) {
            return profile.getUsername();
        }

        String baseUsername = firstNonBlank(requestedUsername, phoneNumber.replaceAll("[^a-zA-Z0-9]", ""), "user");
        String normalizedBase = normalizeUsername(baseUsername);
        return ensureUniqueUsername(normalizedBase, profile.getVId());
    }

    private String resolveDisplayName(String requestedDisplayName, String username) {
        return firstNonBlank(requestedDisplayName, username, "Nirdist User");
    }

    private String buildDirectFirebaseUid(String phoneNumber) {
        return "direct-phone:" + phoneNumber;
    }

    private String normalizeUsername(String value) {
        String normalized = trimToNull(value);
        if (normalized == null) {
            return "user";
        }

        normalized = normalized.toLowerCase(Locale.ROOT).replaceAll("[^a-z0-9._-]", "");
        return normalized.isBlank() ? "user" : normalized;
    }

    private String ensureUniqueUsername(String baseUsername, Long currentProfileId) {
        String candidate = baseUsername;
        int suffix = 1;

        while (true) {
            Profile existing = profileRepository.findByUsername(candidate).orElse(null);
            if (existing == null || Objects.equals(existing.getVId(), currentProfileId)) {
                return candidate;
            }

            candidate = baseUsername + "_" + suffix++;
        }
    }

    private String firstNonBlank(String... values) {
        if (values == null) {
            return null;
        }

        for (String value : values) {
            String trimmed = trimToNull(value);
            if (trimmed != null) {
                return trimmed;
            }
        }

        return null;
    }

    private String trimToNull(String value) {
        if (value == null) {
            return null;
        }

        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
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
}