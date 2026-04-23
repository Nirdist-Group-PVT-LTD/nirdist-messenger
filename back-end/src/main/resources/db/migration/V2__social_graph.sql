CREATE TABLE IF NOT EXISTS friend_request (
    request_id BIGSERIAL PRIMARY KEY,
    requester_v_id BIGINT NOT NULL REFERENCES profile(v_id) ON DELETE CASCADE,
    addressee_v_id BIGINT NOT NULL REFERENCES profile(v_id) ON DELETE CASCADE,
    request_message TEXT,
    request_status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (request_status IN ('PENDING', 'ACCEPTED', 'REJECTED', 'CANCELLED')),
    responded_by_v_id BIGINT REFERENCES profile(v_id) ON DELETE SET NULL,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_friend_request_not_self CHECK (requester_v_id <> addressee_v_id),
    CONSTRAINT uq_friend_request_pair_status UNIQUE (requester_v_id, addressee_v_id, request_status)
);

CREATE INDEX IF NOT EXISTS idx_friend_request_requester ON friend_request(requester_v_id);
CREATE INDEX IF NOT EXISTS idx_friend_request_addressee ON friend_request(addressee_v_id);
CREATE INDEX IF NOT EXISTS idx_friend_request_status ON friend_request(request_status);
CREATE INDEX IF NOT EXISTS idx_friend_request_requested_at ON friend_request(requested_at DESC);

CREATE TABLE IF NOT EXISTS contact_sync_entry (
    sync_entry_id BIGSERIAL PRIMARY KEY,
    profile_v_id BIGINT NOT NULL REFERENCES profile(v_id) ON DELETE CASCADE,
    contact_name VARCHAR(255),
    contact_phone VARCHAR(100) NOT NULL,
    normalized_phone VARCHAR(40) NOT NULL,
    matched_profile_v_id BIGINT REFERENCES profile(v_id) ON DELETE SET NULL,
    source VARCHAR(20) NOT NULL DEFAULT 'PHONEBOOK',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_contact_sync_profile_phone UNIQUE (profile_v_id, normalized_phone)
);

CREATE INDEX IF NOT EXISTS idx_contact_sync_profile_v_id ON contact_sync_entry(profile_v_id);
CREATE INDEX IF NOT EXISTS idx_contact_sync_normalized_phone ON contact_sync_entry(normalized_phone);
CREATE INDEX IF NOT EXISTS idx_contact_sync_matched_profile_v_id ON contact_sync_entry(matched_profile_v_id);