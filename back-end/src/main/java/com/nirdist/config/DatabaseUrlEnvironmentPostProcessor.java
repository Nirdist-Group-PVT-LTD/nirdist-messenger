package com.nirdist.config;

import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.Ordered;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.MapPropertySource;

import com.nirdist.util.DatabaseUrlNormalizer;

public class DatabaseUrlEnvironmentPostProcessor implements EnvironmentPostProcessor, Ordered {

    @Override
    public void postProcessEnvironment(ConfigurableEnvironment environment, SpringApplication application) {
        String explicitDatabaseUrl = resolvePlaceholders(environment, firstNonBlank(
            environment.getProperty("JDBC_DATABASE_URL"),
            environment.getProperty("NEON_CONNECTION_STRING"),
            environment.getProperty("DATABASE_URL")
        ));
        String configuredUrl = resolvePlaceholders(environment, firstNonBlank(
            explicitDatabaseUrl,
            environment.getProperty("SPRING_DATASOURCE_URL")
        ));

        DatabaseUrlNormalizer.NormalizedDatabaseConfig normalizedConfig;
        try {
            normalizedConfig = DatabaseUrlNormalizer.normalize(configuredUrl);
        } catch (IllegalArgumentException ignored) {
            return;
        }
        if (normalizedConfig == null) {
            return;
        }

        Map<String, Object> properties = new LinkedHashMap<>();
        properties.put("spring.datasource.url", normalizedConfig.jdbcUrl());

        if (normalizedConfig.username() != null && explicitDatabaseUrl != null) {
            // Explicit JDBC_DATABASE_URL / DATABASE_URL credentials should win over stale DB_USER values.
            properties.put("spring.datasource.username", normalizedConfig.username());
        } else if (firstNonBlank(
                environment.getProperty("spring.datasource.username"),
                environment.getProperty("DB_USER"),
                environment.getProperty("PGUSER")
        ) == null && normalizedConfig.username() != null) {
            properties.put("spring.datasource.username", normalizedConfig.username());
        }

        if (normalizedConfig.password() != null && explicitDatabaseUrl != null) {
            // Explicit JDBC_DATABASE_URL / DATABASE_URL credentials should win over stale DB_PASSWORD values.
            properties.put("spring.datasource.password", normalizedConfig.password());
        } else if (firstNonBlank(
                environment.getProperty("spring.datasource.password"),
                environment.getProperty("DB_PASSWORD"),
                environment.getProperty("PGPASSWORD")
        ) == null && normalizedConfig.password() != null) {
            properties.put("spring.datasource.password", normalizedConfig.password());
        }

        if (!properties.isEmpty()) {
            environment.getPropertySources().addFirst(
                    new MapPropertySource("normalized-database-url", properties)
            );
        }
    }

    @Override
    public int getOrder() {
        return Ordered.HIGHEST_PRECEDENCE;
    }

    private String firstNonBlank(String... values) {
        if (values == null) {
            return null;
        }

        for (String value : values) {
            if (value == null) {
                continue;
            }

            String trimmed = value.trim();
            if (!trimmed.isEmpty()) {
                return trimmed;
            }
        }

        return null;
    }

    private String resolvePlaceholders(ConfigurableEnvironment environment, String value) {
        if (value == null) {
            return null;
        }

        String resolved = environment.resolvePlaceholders(value);
        if (resolved.contains("${")) {
            // Skip unresolved placeholders (for example when a Render secret is missing).
            return null;
        }

        return resolved;
    }
}
