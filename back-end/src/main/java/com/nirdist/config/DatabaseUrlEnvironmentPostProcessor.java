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
        String configuredUrl = firstNonBlank(
                environment.getProperty("JDBC_DATABASE_URL"),
            environment.getProperty("SPRING_DATASOURCE_URL"),
                environment.getProperty("DATABASE_URL")
        );

        DatabaseUrlNormalizer.NormalizedDatabaseConfig normalizedConfig = DatabaseUrlNormalizer.normalize(configuredUrl);
        if (normalizedConfig == null) {
            return;
        }

        Map<String, Object> properties = new LinkedHashMap<>();
        properties.put("spring.datasource.url", normalizedConfig.jdbcUrl());

        if (firstNonBlank(
                environment.getProperty("spring.datasource.username"),
                environment.getProperty("DB_USER"),
                environment.getProperty("PGUSER")
        ) == null && normalizedConfig.username() != null) {
            properties.put("spring.datasource.username", normalizedConfig.username());
        }

        if (firstNonBlank(
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
}
