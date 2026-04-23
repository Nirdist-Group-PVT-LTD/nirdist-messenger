CREATE TABLE IF NOT EXISTS profile (
    v_id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone_number VARCHAR(20) NOT NULL UNIQUE,
    firebase_uid VARCHAR(128) NOT NULL UNIQUE,
    password_hash TEXT,
    avatar_url TEXT,
    bio TEXT,
    phone_verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chat_room (
    room_id BIGSERIAL PRIMARY KEY,
    room_name VARCHAR(100),
    room_type VARCHAR(20) NOT NULL CHECK (room_type IN ('private', 'group')),
    created_by BIGINT REFERENCES profile(v_id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chat_message (
    message_id BIGSERIAL PRIMARY KEY,
    room_id BIGINT NOT NULL REFERENCES chat_room(room_id) ON DELETE CASCADE,
    sender_v_id BIGINT NOT NULL REFERENCES profile(v_id) ON DELETE CASCADE,
    message_text TEXT NOT NULL,
    media_url TEXT,
    message_type VARCHAR(20) NOT NULL DEFAULT 'TEXT' CHECK (message_type IN ('TEXT', 'IMAGE', 'VIDEO', 'AUDIO', 'FILE', 'SYSTEM')),
    reply_to_id BIGINT REFERENCES chat_message(message_id) ON DELETE SET NULL,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chat_participant (
    participant_id BIGSERIAL PRIMARY KEY,
    room_id BIGINT NOT NULL REFERENCES chat_room(room_id) ON DELETE CASCADE,
    v_id BIGINT NOT NULL REFERENCES profile(v_id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'admin', 'owner')),
    last_read_msg_id BIGINT,
    is_muted BOOLEAN NOT NULL DEFAULT FALSE,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (room_id, v_id)
);

ALTER TABLE chat_participant
    ADD CONSTRAINT fk_chat_participant_last_read_msg
    FOREIGN KEY (last_read_msg_id) REFERENCES chat_message(message_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_chat_room_created_by ON chat_room(created_by);
CREATE INDEX IF NOT EXISTS idx_chat_message_room_id ON chat_message(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_message_sender_v_id ON chat_message(sender_v_id);
CREATE INDEX IF NOT EXISTS idx_chat_message_created_at ON chat_message(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_participant_room_id ON chat_participant(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_participant_v_id ON chat_participant(v_id);