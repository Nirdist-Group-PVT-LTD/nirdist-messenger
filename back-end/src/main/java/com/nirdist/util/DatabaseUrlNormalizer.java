package com.nirdist.util;

import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

public final class DatabaseUrlNormalizer {

    private DatabaseUrlNormalizer() {
    }

    public static NormalizedDatabaseConfig normalize(String value) {
        String trimmed = trimToNull(value);
        if (trimmed == null) {
            return null;
        }

        if (trimmed.startsWith("jdbc:")) {
            return new NormalizedDatabaseConfig(trimmed, null, null);
        }

        URI uri = URI.create(trimmed);
        String scheme = trimToNull(uri.getScheme());
        if (scheme == null || (!scheme.equalsIgnoreCase("postgresql") && !scheme.equalsIgnoreCase("postgres"))) {
            return new NormalizedDatabaseConfig(trimmed, null, null);
        }

        String host = trimToNull(uri.getHost());
        if (host == null) {
            throw new IllegalArgumentException("Database URL is missing a host");
        }

        String path = trimToNull(uri.getRawPath());
        String databasePath = path == null ? "" : path;
        String query = trimToNull(uri.getRawQuery());

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
