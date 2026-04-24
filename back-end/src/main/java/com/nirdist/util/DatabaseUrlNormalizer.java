package com.nirdist.util;

import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.StringJoiner;

public final class DatabaseUrlNormalizer {

    private DatabaseUrlNormalizer() {
    }

    public static NormalizedDatabaseConfig normalize(String value) {
        String trimmed = trimToNull(value);
        if (trimmed == null) {
            return null;
        }

        if (trimmed.startsWith("jdbc:postgresql://") || trimmed.startsWith("jdbc:postgres://")) {
            String rawUrl = trimmed.substring("jdbc:".length());
            NormalizedDatabaseConfig normalizedConfig = normalize(rawUrl);
            if (normalizedConfig == null) {
                return null;
            }

            // Keep explicit JDBC URL compatibility while still sanitizing query parameters.
            return new NormalizedDatabaseConfig(normalizedConfig.jdbcUrl(), null, null);
        }

        if (trimmed.startsWith("jdbc:")) {
            return new NormalizedDatabaseConfig(trimmed, null, null);
        }

        URI uri = URI.create(trimmed);
        String scheme = trimToNull(uri.getScheme());
        if (scheme == null || (!scheme.equalsIgnoreCase("postgresql") && !scheme.equalsIgnoreCase("postgres"))) {
            return new NormalizedDatabaseConfig(trimmed, null, null);
        }

        String host = normalizeHost(trimToNull(uri.getHost()));
        if (host == null) {
            throw new IllegalArgumentException("Database URL is missing a host");
        }

        String path = trimToNull(uri.getRawPath());
        String databasePath = path == null ? "" : path;
        String query = sanitizeQueryForJdbc(trimToNull(uri.getRawQuery()));

        String jdbcUrl = buildJdbcUrl(host, uri.getPort(), databasePath, query);
        Credentials credentials = parseCredentials(uri.getRawUserInfo());
        return new NormalizedDatabaseConfig(jdbcUrl, credentials.username(), credentials.password());
    }

    private static String buildJdbcUrl(String host, int port, String databasePath, String query) {
        StringBuilder builder = new StringBuilder("jdbc:postgresql://").append(host);
        if (port > 0) {
            builder.append(':').append(port);
        }

        if (!databasePath.isEmpty()) {
            builder.append(databasePath);
        }

        if (query != null) {
            builder.append('?').append(query);
        }

        return builder.toString();
    }

    private static Credentials parseCredentials(String rawUserInfo) {
        String userInfo = trimToNull(rawUserInfo);
        if (userInfo == null) {
            return new Credentials(null, null);
        }

        String[] parts = userInfo.split(":", 2);
        String username = decode(parts[0]);
        String password = parts.length > 1 ? decode(parts[1]) : null;
        return new Credentials(trimToNull(username), trimToNull(password));
    }

    private static String sanitizeQueryForJdbc(String rawQuery) {
        Map<String, String> params = new LinkedHashMap<>();
        if (rawQuery != null) {
            String[] pairs = rawQuery.split("&");
            for (String pair : pairs) {
                String token = trimToNull(pair);
                if (token == null) {
                    continue;
                }

                int separator = token.indexOf('=');
                String rawKey = separator >= 0 ? token.substring(0, separator) : token;
                String rawValue = separator >= 0 ? token.substring(separator + 1) : "";
                String key = trimToNull(rawKey);
                if (key == null) {
                    continue;
                }

                String normalizedKey = key.toLowerCase();
                if ("channel_binding".equals(normalizedKey) || "channelbinding".equals(normalizedKey)) {
                    continue;
                }

                params.put(key, rawValue);
            }
        }

        boolean hasSslMode = params.keySet().stream().anyMatch(k -> "sslmode".equalsIgnoreCase(k));
        if (!hasSslMode) {
            params.put("sslmode", "require");
        }

        // Explicitly disable channel binding for compatibility with pooled PostgreSQL endpoints.
        params.put("channelBinding", "disable");

        if (params.isEmpty()) {
            return null;
        }

        StringJoiner joiner = new StringJoiner("&");
        params.forEach((k, v) -> joiner.add(v.isEmpty() ? k : k + "=" + v));
        return joiner.toString();
    }

    private static String normalizeHost(String host) {
        if (host == null) {
            return null;
        }

        // Some Neon pooled hosts can fail SCRAM negotiation with the JDBC driver.
        // Prefer direct host when a pooler hostname is provided.
        if (host.endsWith(".neon.tech") && host.contains("-pooler")) {
            // Example:
            // ep-abc-pooler.c-2.ap-southeast-1.aws.neon.tech -> ep-abc.ap-southeast-1.aws.neon.tech
            // ep-abc-pooler.us-east-1.aws.neon.tech         -> ep-abc.us-east-1.aws.neon.tech
            String normalized = host.replaceFirst("-pooler\\.c-\\d+\\.", ".");
            normalized = normalized.replaceFirst("-pooler\\.", ".");
            return normalized;
        }

        return host;
    }

    private static String decode(String value) {
        return URLDecoder.decode(value, StandardCharsets.UTF_8);
    }

    private static String trimToNull(String value) {
        if (value == null) {
            return null;
        }

        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    public record NormalizedDatabaseConfig(String jdbcUrl, String username, String password) {
        public List<String> describe() {
            List<String> values = new ArrayList<>();
            values.add(jdbcUrl);
            if (username != null) {
                values.add(username);
            }
            if (password != null) {
                values.add(password);
            }
            return values;
        }
    }

    private record Credentials(String username, String password) {
    }
}
