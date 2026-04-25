package com.nirdist.config;

import java.util.LinkedHashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.Ordered;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.MapPropertySource;
import org.springframework.core.env.PropertySource;

import com.nirdist.util.DatabaseUrlNormalizer;

public class DatabaseUrlEnvironmentPostProcessor implements EnvironmentPostProcessor, Ordered {

    private static final Logger log = LoggerFactory.getLogger(DatabaseUrlEnvironmentPostProcessor.class);

    @Override
    public void postProcessEnvironment(ConfigurableEnvironment environment, SpringApplication application) {
        String explicitDatabaseUrlSource = firstConfiguredDatabaseUrlSource(environment);
        String explicitDatabaseUrl = resolvePlaceholders(environment,
                explicitDatabaseUrlSource == null ? null : rawProperty(environment, explicitDatabaseUrlSource));
        String configuredUrl = resolvePlaceholders(environment, firstNonBlank(
            explicitDatabaseUrl,
            rawProperty(environment, "SPRING_DATASOURCE_URL")
        ));

        DatabaseUrlNormalizer.NormalizedDatabaseConfig normalizedConfig;
        try {
            normalizedConfig = DatabaseUrlNormalizer.normalize(configuredUrl);
        } catch (IllegalArgumentException ignored) {
            log.warn("Skipping database URL normalization because the configured URL could not be parsed");
            return;
        }
        if (normalizedConfig == null) {
            log.info("No database URL normalization applied because no datasource URL was configured");
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
            log.info(
                    "Normalized datasource URL from {} to {} (username provided: {}, password provided: {})",
                    explicitDatabaseUrlSource == null ? "SPRING_DATASOURCE_URL/defaults" : explicitDatabaseUrlSource,
                    describeJdbcUrl(normalizedConfig.jdbcUrl()),
                    normalizedConfig.username() != null || hasConfiguredUsername(environment),
                    normalizedConfig.password() != null || hasConfiguredPassword(environment)
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

    private String firstConfiguredDatabaseUrlSource(ConfigurableEnvironment environment) {
        if (firstNonBlank(rawProperty(environment, "NEON_CONNECTION_STRING")) != null) {
            return "NEON_CONNECTION_STRING";
        }
        if (firstNonBlank(rawProperty(environment, "JDBC_DATABASE_URL")) != null) {
            return "JDBC_DATABASE_URL";
        }
        if (firstNonBlank(rawProperty(environment, "DATABASE_URL")) != null) {
            return "DATABASE_URL";
        }
        return null;
    }

    private String rawProperty(ConfigurableEnvironment environment, String name) {
        for (PropertySource<?> propertySource : environment.getPropertySources()) {
            Object value = propertySource.getProperty(name);
            if (value != null) {
                return value.toString();
            }
        }

        return null;
    }

    private boolean hasConfiguredUsername(ConfigurableEnvironment environment) {
        return firstNonBlank(
                environment.getProperty("spring.datasource.username"),
                environment.getProperty("DB_USER"),
                environment.getProperty("PGUSER")
        ) != null;
    }

    private boolean hasConfiguredPassword(ConfigurableEnvironment environment) {
        return firstNonBlank(
                environment.getProperty("spring.datasource.password"),
                environment.getProperty("DB_PASSWORD"),
                environment.getProperty("PGPASSWORD")
        ) != null;
    }

    private String describeJdbcUrl(String jdbcUrl) {
        if (jdbcUrl == null) {
            return "n/a";
        }

        int queryIndex = jdbcUrl.indexOf('?');
        return queryIndex >= 0 ? jdbcUrl.substring(0, queryIndex) : jdbcUrl;
    }

    private String resolvePlaceholders(ConfigurableEnvironment environment, String value) {
        if (value == null) {
            return null;
        }

        try {
            String resolved = environment.resolvePlaceholders(value);
            if (resolved.contains("${")) {
                // Skip unresolved placeholders (for example when a Render secret is missing).
                return null;
            }

            return resolved;
        } catch (IllegalArgumentException ignored) {
            // Spring throws on unresolved placeholders when no fallback exists.
            return null;
        }
    }
}
