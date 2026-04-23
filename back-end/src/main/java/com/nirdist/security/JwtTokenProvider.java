package com.nirdist.security;

import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;
import java.util.Date;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.nirdist.entity.Profile;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;

@Component
public class JwtTokenProvider {

    @Value("${jwt.secret}")
    private String jwtSecret;

    @Value("${jwt.expiration}")
    private long jwtExpirationMs;

    public String generateToken(Profile profile) {
        return Jwts.builder()
                .setSubject(profile.getVId().toString())
                .claim("username", profile.getUsername())
                .claim("display_name", profile.getDisplayName())
                .claim("phone_number", profile.getPhoneNumber())
                .claim("firebase_uid", profile.getFirebaseUid())
                .setIssuedAt(new Date())
                .setExpiration(new Date(System.currentTimeMillis() + jwtExpirationMs))
                .signWith(getSigningKey(), SignatureAlgorithm.HS512)
                .compact();
    }

    public Long getUserIdFromToken(String token) {
        Claims claims = Jwts.parserBuilder()
                .setSigningKey(getSigningKey())
                .build()
                .parseClaimsJws(token)
                .getBody();

        String subject = claims.getSubject();
        if (subject == null || subject.isBlank()) {
            return null;
        }

        return Long.valueOf(subject);
    }

    public boolean validateToken(String token) {
        try {
            Jwts.parserBuilder()
                    .setSigningKey(getSigningKey())
                    .build()
                    .parseClaimsJws(token);
            return true;
        } catch (RuntimeException e) {
            return false;
        }
    }

    private Key getSigningKey() {
        return Keys.hmacShaKeyFor(resolveSecretBytes(jwtSecret));
    }

    private byte[] resolveSecretBytes(String secret) {
        if (secret == null || secret.isBlank()) {
            throw new IllegalStateException("JWT secret is not configured");
        }

        String trimmedSecret = secret.trim();

        try {
            byte[] decodedSecret = Base64.getDecoder().decode(trimmedSecret);
            if (decodedSecret.length >= 64) {
                return decodedSecret;
            }
        } catch (IllegalArgumentException ignored) {
        }

        byte[] rawSecret = trimmedSecret.getBytes(StandardCharsets.UTF_8);
        if (rawSecret.length >= 64) {
            return rawSecret;
        }

        return digestWithSha512(rawSecret);
    }

    private byte[] digestWithSha512(byte[] input) {
        try {
            MessageDigest messageDigest = MessageDigest.getInstance("SHA-512");
            return messageDigest.digest(input);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-512 algorithm is unavailable", e);
        }
    }
}