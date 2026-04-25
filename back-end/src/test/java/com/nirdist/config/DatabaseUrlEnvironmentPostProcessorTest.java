package com.nirdist.config;

import static org.assertj.core.api.Assertions.assertThat;
import org.junit.jupiter.api.Test;
import org.springframework.boot.SpringApplication;
import org.springframework.mock.env.MockEnvironment;

class DatabaseUrlEnvironmentPostProcessorTest {

    private final DatabaseUrlEnvironmentPostProcessor postProcessor = new DatabaseUrlEnvironmentPostProcessor();

    @Test
    void usesCredentialsEmbeddedInNeonConnectionString() {
        MockEnvironment environment = new MockEnvironment()
                .withProperty(
                        "NEON_CONNECTION_STRING",
                        "postgresql://neondb_owner:npg_secret@ep-dry-breeze-aot9a9gh-pooler.c-2.ap-southeast-1.aws.neon.tech/neondb"
                );

        postProcessor.postProcessEnvironment(environment, new SpringApplication(Object.class));

        assertThat(environment.getProperty("spring.datasource.url"))
                .isEqualTo(
                        "jdbc:postgresql://ep-dry-breeze-aot9a9gh-pooler.c-2.ap-southeast-1.aws.neon.tech/neondb?sslmode=require&channelBinding=disable"
                );
        assertThat(environment.getProperty("spring.datasource.username")).isEqualTo("neondb_owner");
        assertThat(environment.getProperty("spring.datasource.password")).isEqualTo("npg_secret");
    }

    @Test
    void prefersNeonConnectionStringOverJdbcDatabaseUrlWhenBothArePresent() {
        MockEnvironment environment = new MockEnvironment()
                .withProperty("JDBC_DATABASE_URL", "postgresql://legacy_user:legacy_pass@legacy.example.com:5432/legacy")
                .withProperty(
                        "NEON_CONNECTION_STRING",
                        "postgresql://neondb_owner:npg_secret@ep-dry-breeze-aot9a9gh.c-2.ap-southeast-1.aws.neon.tech/neondb"
                );

        postProcessor.postProcessEnvironment(environment, new SpringApplication(Object.class));

        assertThat(environment.getProperty("spring.datasource.url"))
                .isEqualTo(
                        "jdbc:postgresql://ep-dry-breeze-aot9a9gh.c-2.ap-southeast-1.aws.neon.tech/neondb?sslmode=require&channelBinding=disable"
                );
        assertThat(environment.getProperty("spring.datasource.username")).isEqualTo("neondb_owner");
        assertThat(environment.getProperty("spring.datasource.password")).isEqualTo("npg_secret");
    }

    @Test
    void ignoresUnresolvedPlaceholderValuesAndFallsBackToConcreteDatasourceUrl() {
        MockEnvironment environment = new MockEnvironment()
                .withProperty("JDBC_DATABASE_URL", "${MISSING_SECRET}")
                .withProperty("SPRING_DATASOURCE_URL", "postgresql://fallback_user:fallback_pass@db.example.com:5432/nirdist");

        postProcessor.postProcessEnvironment(environment, new SpringApplication(Object.class));

        assertThat(environment.getProperty("spring.datasource.url"))
                .isEqualTo("jdbc:postgresql://db.example.com:5432/nirdist?sslmode=require&channelBinding=disable");
        assertThat(environment.getProperty("spring.datasource.username")).isEqualTo("fallback_user");
        assertThat(environment.getProperty("spring.datasource.password")).isEqualTo("fallback_pass");
    }
}
