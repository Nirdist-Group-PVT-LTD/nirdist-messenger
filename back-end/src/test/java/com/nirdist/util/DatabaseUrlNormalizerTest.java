package com.nirdist.util;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class DatabaseUrlNormalizerTest {

    @Test
    void normalizesNeonStylePostgresUrlAndExtractsCredentials() {
        DatabaseUrlNormalizer.NormalizedDatabaseConfig config = DatabaseUrlNormalizer.normalize(
                "postgresql://neondb_owner:npg_secret@ep-dry-breeze-aot9a9gh.c-2.ap-southeast-1.aws.neon.tech/neondb?sslmode=require"
        );

        assertThat(config).isNotNull();
        assertThat(config.jdbcUrl())
                .isEqualTo("jdbc:postgresql://ep-dry-breeze-aot9a9gh.c-2.ap-southeast-1.aws.neon.tech/neondb?sslmode=require");
        assertThat(config.username()).isEqualTo("neondb_owner");
        assertThat(config.password()).isEqualTo("npg_secret");
    }

    @Test
    void leavesJdbcUrlsUntouched() {
        DatabaseUrlNormalizer.NormalizedDatabaseConfig config = DatabaseUrlNormalizer.normalize(
                "jdbc:postgresql://localhost:5432/nirdist"
        );

        assertThat(config).isNotNull();
        assertThat(config.jdbcUrl()).isEqualTo("jdbc:postgresql://localhost:5432/nirdist");
        assertThat(config.username()).isNull();
        assertThat(config.password()).isNull();
    }
}
