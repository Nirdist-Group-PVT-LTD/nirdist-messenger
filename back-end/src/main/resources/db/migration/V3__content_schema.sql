CREATE TABLE IF NOT EXISTS story (
    story_id BIGSERIAL PRIMARY KEY,
    v_id BIGINT NOT NULL REFERENCES profile(v_id) ON DELETE CASCADE,
    caption TEXT,
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    mentions JSONB NOT NULL DEFAULT '[]'::jsonb,
    sound_url TEXT,
    media_url TEXT NOT NULL,
    media_type VARCHAR(20) NOT NULL CHECK (media_type IN ('image', 'video')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    status SMALLINT NOT NULL DEFAULT 1 CHECK (status IN (0, 1))
);

CREATE INDEX IF NOT EXISTS idx_story_v_id ON story(v_id);
CREATE INDEX IF NOT EXISTS idx_story_created_at ON story(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_story_expires_at ON story(expires_at);

CREATE TABLE IF NOT EXISTS note (
    note_id BIGSERIAL PRIMARY KEY,
    v_id BIGINT NOT NULL REFERENCES profile(v_id) ON DELETE CASCADE,
    body_text TEXT,
    tags JSONB NOT NULL DEFAULT '[]'::jsonb,
    mentions JSONB NOT NULL DEFAULT '[]'::jsonb,
    sound_url TEXT,
    media_url TEXT,
    media_type VARCHAR(20) NOT NULL DEFAULT 'text' CHECK (media_type IN ('text', 'image', 'video')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    status SMALLINT NOT NULL DEFAULT 1 CHECK (status IN (0, 1)),
    CHECK (media_type <> 'text' OR body_text IS NOT NULL),
    CHECK (media_type = 'text' OR media_url IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_note_v_id ON note(v_id);
CREATE INDEX IF NOT EXISTS idx_note_created_at ON note(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_note_expires_at ON note(expires_at);

CREATE TABLE IF NOT EXISTS content_comment (
    comment_id BIGSERIAL PRIMARY KEY,
    v_id BIGINT NOT NULL REFERENCES profile(v_id) ON DELETE CASCADE,
    target_type VARCHAR(20) NOT NULL CHECK (target_type IN ('story', 'note')),
    target_id BIGINT NOT NULL,
    parent_comment_id BIGINT REFERENCES content_comment(comment_id) ON DELETE CASCADE,
    comment_text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status SMALLINT NOT NULL DEFAULT 1 CHECK (status IN (0, 1))
);

CREATE INDEX IF NOT EXISTS idx_content_comment_target ON content_comment(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_content_comment_parent ON content_comment(parent_comment_id);
CREATE INDEX IF NOT EXISTS idx_content_comment_v_id ON content_comment(v_id);
CREATE INDEX IF NOT EXISTS idx_content_comment_created_at ON content_comment(created_at DESC);

CREATE TABLE IF NOT EXISTS reaction (
    reaction_id BIGSERIAL PRIMARY KEY,
    v_id BIGINT NOT NULL REFERENCES profile(v_id) ON DELETE CASCADE,
    target_type VARCHAR(20) NOT NULL CHECK (target_type IN ('story', 'note', 'comment')),
    target_id BIGINT NOT NULL,
    reaction_type VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_reaction_user_target UNIQUE (v_id, target_type, target_id)
);

CREATE INDEX IF NOT EXISTS idx_reaction_target ON reaction(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_reaction_v_id ON reaction(v_id);
CREATE INDEX IF NOT EXISTS idx_reaction_created_at ON reaction(created_at DESC);