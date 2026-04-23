package com.nirdist.init;

import java.util.Optional;

import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.nirdist.entity.Profile;
import com.nirdist.repository.ProfileRepository;

/**
 * Initializes test data for development/demo purposes.
 * Creates sample profiles so the People tab feature can be demonstrated immediately.
 * Can be disabled by setting INIT_TEST_DATA=false environment variable.
 */
@Configuration
@org.springframework.context.annotation.Profile("!test")
public class DataInitializer {
    
    @Bean
    @SuppressWarnings("unused")
    CommandLineRunner initTestData(ProfileRepository profileRepository) {
        return args -> {
            // Check if initialization is disabled
            String initEnabled = System.getenv("INIT_TEST_DATA");
            if ("false".equalsIgnoreCase(initEnabled)) {
                System.out.println("Test data initialization disabled (INIT_TEST_DATA=false)");
                return;
            }
            
            // Create test profiles if they don't exist
            createTestProfileIfNotExists(profileRepository, 
                "+1-555-0001", "Alice Johnson", "alice@nirdist.com", "alice_j");
            createTestProfileIfNotExists(profileRepository, 
                "+1-555-0002", "Bob Smith", "bob@nirdist.com", "bob_smith");
            createTestProfileIfNotExists(profileRepository, 
                "+1-555-0003", "Carol White", "carol@nirdist.com", "carol_w");
            createTestProfileIfNotExists(profileRepository, 
                "+1-555-0004", "David Brown", "david@nirdist.com", "david_b");
        };
    }
    
    private void createTestProfileIfNotExists(ProfileRepository profileRepository,
                                          String phoneNumber, String displayName, String email, String username) {
        Optional<Profile> existing = profileRepository.findByPhoneNumber(phoneNumber);
        if (existing.isEmpty()) {
            // Create profile
            Profile profile = new Profile();
            profile.setDisplayName(displayName);
            profile.setUsername(username);
            profile.setEmail(email);
            profile.setPhoneNumber(phoneNumber);
            profile.setAvatarUrl("https://api.dicebear.com/7.x/avataaars/svg?seed=" + username);
            profile.setFirebaseUid("test_uid_" + System.nanoTime()); // Unique ID for test user
            
            profileRepository.save(profile);
            
            System.out.println("Created test profile: " + displayName + " (" + phoneNumber + ")");
        }
    }
}
