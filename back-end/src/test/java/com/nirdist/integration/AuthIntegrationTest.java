package com.nirdist.integration;

import java.lang.reflect.Field;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.Test;

import com.nirdist.entity.Profile;
import com.nirdist.security.JwtTokenProvider;

public class AuthIntegrationTest {

    private void setPrivateField(Object target, String fieldName, Object value) throws Exception {
        Field f = target.getClass().getDeclaredField(fieldName);
        f.setAccessible(true);
        f.set(target, value);
    }

    @Test
    public void jwtTokenGenerationAndValidation() throws Exception {
        JwtTokenProvider jwtTokenProvider = new JwtTokenProvider();
        setPrivateField(jwtTokenProvider, "jwtSecret", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
        setPrivateField(jwtTokenProvider, "jwtExpirationMs", 3600000L);

        Profile p = new Profile();
        p.setVId(123L);
        p.setUsername("bob");
        p.setDisplayName("Bob");
        p.setPhoneNumber("+10000000000");
        p.setFirebaseUid("fb-uid");

        String token = jwtTokenProvider.generateToken(p);
        assertNotNull(token);
        assertTrue(jwtTokenProvider.validateToken(token));
        assertEquals(123L, jwtTokenProvider.getUserIdFromToken(token).longValue());
    }
}
