package com.nirdist.auth;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import com.google.firebase.auth.FirebaseToken;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.server.ResponseStatusException;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

@Component
public class FirebaseAdminTokenVerifier implements FirebaseTokenVerifier {

    private final String serviceAccountJson;
    private final String credentialsPath;
    private final String projectId;

    private volatile FirebaseApp firebaseApp;

    public FirebaseAdminTokenVerifier(
            @Value("${app.firebase.service-account-json:}") String serviceAccountJson,
            @Value("${app.firebase.credentials-path:}") String credentialsPath,
            @Value("${app.firebase.project-id:}") String projectId
    ) {
        this.serviceAccountJson = serviceAccountJson;
        this.credentialsPath = credentialsPath;
        this.projectId = projectId;
    }

    @Override
    public FirebaseVerifiedUser verify(String idToken) {
        try {
            FirebaseToken decodedToken = FirebaseAuth.getInstance(getOrCreateFirebaseApp()).verifyIdToken(idToken);
            return new FirebaseVerifiedUser(
                    decodedToken.getUid(),
                    extractPhoneNumber(decodedToken),
                    decodedToken.getName(),
                    decodedToken.getEmail(),
                    decodedToken.getPicture()
            );
        } catch (FirebaseAuthException | IllegalStateException e) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid Firebase token", e);
        }
    }

    private FirebaseApp getOrCreateFirebaseApp() {
        FirebaseApp existingApp = firebaseApp;
        if (existingApp != null) {
            return existingApp;
        }

        synchronized (this) {
            if (firebaseApp != null) {
                return firebaseApp;
            }

            if (!FirebaseApp.getApps().isEmpty()) {
                firebaseApp = FirebaseApp.getInstance();
                return firebaseApp;
            }

            try (InputStream credentialsStream = openCredentialsStream()) {
                FirebaseOptions.Builder builder = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(credentialsStream));

                if (projectId != null && !projectId.isBlank()) {
                    builder.setProjectId(projectId.trim());
                }

                firebaseApp = FirebaseApp.initializeApp(builder.build());
                return firebaseApp;
            } catch (IOException e) {
                throw new IllegalStateException("Firebase credentials could not be loaded", e);
            }
        }
    }

    private InputStream openCredentialsStream() throws IOException {
        String inlineCredentials = trimToNull(serviceAccountJson);
        if (inlineCredentials != null) {
            return new ByteArrayInputStream(inlineCredentials.getBytes(StandardCharsets.UTF_8));
        }

        String configuredPath = trimToNull(credentialsPath);
        if (configuredPath == null) {
            configuredPath = trimToNull(System.getenv("GOOGLE_APPLICATION_CREDENTIALS"));
        }

        if (configuredPath == null) {
            throw new IllegalStateException("Firebase credentials are not configured");
        }

        return Files.newInputStream(Path.of(configuredPath));
    }

    private String extractPhoneNumber(FirebaseToken decodedToken) {
        Object phoneNumber = decodedToken.getClaims().get("phone_number");
        if (phoneNumber instanceof String value) {
            return trimToNull(value);
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
}