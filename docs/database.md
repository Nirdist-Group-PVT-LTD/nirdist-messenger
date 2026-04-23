# Database Documentation

## Overview
This document describes the PostgreSQL database schema for Nirdist Messenger, including table structures, relationships, indexing strategies, and migration procedures.

## Schema Migration from MySQL to PostgreSQL

### Key Changes Made
When migrating from the original MySQL schema to PostgreSQL, the following changes were implemented:

1. **Data Type Conversions**
   - `BIGINT UNSIGNED AUTO_INCREMENT` → `BIGSERIAL` or `BIGINT GENERATED ALWAYS AS IDENTITY`
   - `TINYINT` → `SMALLINT` or `BOOLEAN`
   - `ENUM(...)` → PostgreSQL `ENUM type` or `VARCHAR + CHECK constraint`
   - `TEXT` for JSON arrays → `JSONB` (indexable, queryable)
   - `VARCHAR(511)` for media URL → `TEXT` (unlimited, simpler)

2. **Removed MySQL-Specific Syntax**
   - Removed `SET FOREIGN_KEY_CHECKS = 0` (not needed in PostgreSQL)

3. **Expiry Handling**
   - Story/Note expiry handling moved to application scheduler (Spring `@Scheduled`) or `pg_cron`

## Core Tables

### Profile Table (Anchor Table)
The profile table serves as the central user entity in the system.

```sql
CREATE TABLE profile (
    v_id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    avatar_url TEXT,
    bio TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

**Columns:**
- `v_id`: Unique user identifier (primary key)
- `username`: Unique username for login/display
- `email`: Unique email address (used for authentication)
- `password_hash`: Bcrypt-hashed password
- `avatar_url`: URL to user's avatar image (stored in Cloudflare R2)
- `bio`: User biography text
- `created_at`: Timestamp when account was created (timezone-aware)

### User Story Table
Stories are temporary posts that expire after 24 hours.

```sql
CREATE TABLE user_story (
    u_s_id BIGSERIAL PRIMARY KEY,
    v_id BIGINT NOT NULL REFERENCES profile(v_id) ON DELETE CASCADE,
    u_s_tags JSONB,
    u_s_mention JSONB,
    u_s_media_url TEXT,
    u_s_media_type VARCHAR(20) CHECK (u_s_media_type IN ('image', 'video')),
    u_s_expiry_time TIMESTAMPTZ NOT NULL,
    u_s_status BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

**Columns:**
- `u_s_id`: Unique story identifier
- `v_id`: Foreign key to profile table (story author)
- `u_s_tags`: JSONB array of tags associated with the story
- `u_s_mention`: JSONB array of mentioned user IDs
- `u_s_media_url`: URL to media content (image/video)
- `u_s_media_type`: Type of media (image or video)
- `u_s_expiry_time`: Timestamp when story expires
- `u_s_status`: Active/inactive status of story
- `created_at`: Timestamp when story was created

### Chat Message Table
Stores messages sent in chat rooms.

```sql
CREATE TABLE chat_message (
    message_id BIGSERIAL PRIMARY KEY,
    room_id BIGINT NOT NULL REFERENCES chat_room(room_id) ON DELETE CASCADE,
    sender_v_id BIGINT NOT NULL REFERENCES profile(v_id) ON DELETE CASCADE,
    message_text TEXT,
    media_url TEXT,
    reply_to_id BIGINT REFERENCES chat_message(message_id),
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

**Columns:**
- `message_id`: Unique message identifier
- `room_id`: Foreign key to chat_room table
- `sender_v_id`: Foreign key to profile table (message sender)
- `message_text`: Text content of the message
- `media_url`: URL to attached media (if any)
- `reply_to_id`: Reference to parent message for replies (self-referencing foreign key)
- `is_deleted`: Soft delete flag
- `created_at`: Timestamp when message was sent

### Notification Table
Stores notifications for users.

```sql
CREATE TABLE notification (
    notif_id BIGSERIAL PRIMARY KEY,
    v_id BIGINT NOT NULL REFERENCES profile(v_id) ON DELETE CASCADE,
    actor_v_id BIGINT REFERENCES profile(v_id),
    notif_type VARCHAR(50) NOT NULL,  -- 'message','reaction','comment','follow'
    target_type VARCHAR(50),
    target_id BIGINT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

**Columns:**
- `notif_id`: Unique notification identifier
- `v_id`: Foreign key to profile table (notification recipient)
- `actor_v_id`: Foreign key to profile table (user who triggered notification)
- `notif_type`: Type of notification
- `target_type`: Type of entity the notification relates to
- `target_id`: ID of the target entity
- `is_read`: Whether the notification has been read
- `created_at`: Timestamp when notification was created

### Follow Table
Implements the follow/follower social graph.

```sql
CREATE TABLE follow (
    follower_id BIGINT NOT NULL REFERENCES profile(v_id) ON DELETE CASCADE,
    followee_id BIGINT NOT NULL REFERENCES profile(v_id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (follower_id, followee_id)
);
```

**Columns:**
- `follower_id`: Foreign key to profile table (user who is following)
- `followee_id`: Foreign key to profile table (user being followed)
- `created_at`: Timestamp when follow relationship was created
- Composite primary key on (follower_id, followee_id) to prevent duplicate follows

## Additional Tables

### Chat Room Table
```sql
CREATE TABLE chat_room (
    room_id BIGSERIAL PRIMARY KEY,
    room_name VARCHAR(100),
    room_type VARCHAR(20) CHECK (room_type IN ('private', 'group')),
    created_by BIGINT REFERENCES profile(v_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Reaction Table
```sql
CREATE TABLE reaction (
    reaction_id BIGSERIAL PRIMARY KEY,
    v_id BIGINT NOT NULL REFERENCES profile(v_id) ON DELETE CASCADE,
    target_type VARCHAR(50) NOT NULL,  -- 'story','note','comment','message'
    target_id BIGINT NOT NULL,
    reaction_type VARCHAR(20) NOT NULL,  -- 'like','love','laugh','wow','sad','angry'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Comment Table
```sql
CREATE TABLE comment (
    comment_id BIGSERIAL PRIMARY KEY,
    v_id BIGINT NOT NULL REFERENCES profile(v_id) ON DELETE CASCADE,
    target_type VARCHAR(50) NOT NULL,  -- 'story','note'
    target_id BIGINT NOT NULL,
    comment_text TEXT NOT NULL,
    parent_id BIGINT REFERENCES comment(comment_id),  -- For nested comments
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Note Table
```sql
CREATE TABLE note (
    note_id BIGSERIAL PRIMARY KEY,
    v_id BIGINT NOT NULL REFERENCES profile(v_id) ON DELETE CASCADE,
    note_text TEXT,
    media_url TEXT,
    media_type VARCHAR(20) CHECK (media_type IN ('image', 'video')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## Indexing Strategy

### Primary Key Indexes
- Automatically created on all `BIGSERIAL` primary key columns

### Foreign Key Indexes
- Automatically created on all foreign key columns in PostgreSQL

### Additional Indexes
```sql
-- For story feeds and expiry queries
CREATE INDEX idx_user_story_v_id ON user_story(v_id);
CREATE INDEX idx_user_story_expiry_time ON user_story(u_s_expiry_time) WHERE u_s_status = TRUE;
CREATE INDEX idx_user_story_created_at ON user_story(created_at DESC);

-- For message queries
CREATE INDEX idx_chat_message_room_id ON chat_message(room_id);
CREATE INDEX idx_chat_message_sender_v_id ON chat_message(sender_v_id);
CREATE INDEX idx_chat_message_created_at ON chat_message(created_at DESC);

-- For notification queries
CREATE INDEX idx_notification_v_id ON notification(v_id);
CREATE INDEX idx_notification_is_read ON notification(is_read);
CREATE INDEX idx_notification_created_at ON notification(created_at DESC);

-- For follow queries
CREATE INDEX idx_follow_follower_id ON follow(follower_id);
CREATE INDEX idx_follow_followee_id ON follow(followee_id);

-- For reaction queries
CREATE INDEX idx_reaction_v_id ON reaction(v_id);
CREATE INDEX idx_reaction_target ON reaction(target_type, target_id);
CREATE INDEX idx_reaction_created_at ON reaction(created_at DESC);

-- For comment queries
CREATE INDEX idx_comment_v_id ON comment(v_id);
CREATE INDEX idx_comment_target ON comment(target_type, target_id);
CREATE INDEX idx_comment_parent_id ON comment(parent_id);
CREATE INDEX idx_comment_created_at ON comment(created_at DESC);
```

## Connection Pooling Configuration

### HikariCP Settings (Spring Boot)
```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      idle-timeout: 600000
      max-lifetime: 1800000
      connection-timeout: 30000
      pool-name: NirdistHikariCP
```

## Migration Procedures

### Using Flyway
Database migrations are managed using Flyway with versioned SQL scripts.

#### Migration Script Naming Convention
- `V1__initial_schema.sql`: Initial schema creation
- `V2__add_follow_table.sql`: Adding follow table
- `V3__add_notification_table.sql`: Adding notification table
- `V4__add_indexes.sql`: Performance indexes
- `V5__add_check_constraints.sql`: Data validation constraints

#### Running Migrations
```bash
# During development
./mvnw flyway:migrate

# For production deployment
# Handled automatically by CI/CD pipeline
```

### Backup and Recovery

#### Automated Backups (Render.com)
- Daily automatic backups enabled
- Retention period: 30 days
- Point-in-time recovery available

#### Manual Backup Procedure
```bash
# Using pg_dump
pg_dump -h localhost -U nirdist -F c -b -v -f nirdist_backup.dump nirdist

# Using pg_dumpall (includes roles and tablespaces)
pg_dumpall -h localhost -U nirdist -f full_backup.dump
```

#### Recovery Procedure
```bash
# Create new database
createdb -h localhost -U nirdist nirdist_recovery

# Restore from dump
pg_restore -h localhost -U nirdist -d nirdist_recovery nirdist_backup.dump

# Or for full dump
psql -h localhost -U nirdist -d nirdist_recovery -f full_backup.dump
```

## Performance Optimization Guidelines

### Query Optimization
1. Always use EXPLAIN ANALYZE to understand query plans
2. Ensure WHERE clauses use indexed columns
3. Avoid SELECT *; specify only needed columns
4. Use LIMIT for pagination queries
5. Consider materialized views for complex aggregations

### Connection Management
1. Use connection pooling (HikariCP)
2. Close connections promptly after use
3. Monitor connection usage metrics
4. Set appropriate timeouts

### Vacuuming and Maintenance
1. Enable autovacuum (default in PostgreSQL)
2. Monitor bloat with pgstattuple extension
3. Schedule regular VACUUM ANALYZE during low-traffic periods
4. Consider using pg_repack for online table reorganization

## Security Considerations

### Data Protection
1. Passwords stored using bcrypt hashing (via Spring Security)
2. Sensitive fields considered for field-level encryption (planned)
3. Regular security audits of database permissions

### Access Control
1. Database user has limited privileges (no SUPERUSER)
2. Application connects with non-privileged user
3. Row-level security evaluated for future implementation

### GDPR Compliance
1. Right to be implemented via DELETE queries with CASCADE
2. Data export functionality for user data portability
3. Consent tracking for data processing activities

## Future Enhancements

### Planned Improvements
1. **Partitioning**: Large tables (chat_message, notification) partitioned by date
2. **Read Replicas**: For distributing read load
3. **Caching Layer**: Redis integration for frequently accessed data
4. **Full-Text Search**: Using PostgreSQL's built-in full-text search capabilities
5. **JSONB Enhancements**: Advanced indexing on JSONB fields for better query performance
6. **Audit Triggers**: Automatic audit logging for sensitive tables
7. **Column-Level Encryption**: For particularly sensitive fields like email addresses

### Monitoring and Observability
1. **pg_stat_statements**: Track query performance
2. **Custom Metrics**: Export database metrics to Prometheus
3. **Lock Monitoring**: Detect and alert on blocking queries
4. **Replication Lag**: Monitor standby replica lag (when implemented)