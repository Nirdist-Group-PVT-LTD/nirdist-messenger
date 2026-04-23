SET FOREIGN_KEY_CHECKS = 0;

-- 1. USER STORY TABLE
CREATE TABLE IF NOT EXISTS user_story (
    u_s_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    v_id BIGINT UNSIGNED NOT NULL,              -- Link to profile(v_id)
    u_s_tags TEXT NULL,                         -- JSON array for hashtags
    u_s_mention TEXT NULL,                      -- JSON array for user mentions
    u_s_sound VARCHAR(255) NULL,
    u_s_media_url VARCHAR(511) NOT NULL,
    u_s_media_type ENUM('image', 'video') NOT NULL,
    u_s_upload_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    u_s_expiry_time TIMESTAMP NULL,             -- Handled by app logic (e.g., +24hrs)
    u_s_status TINYINT DEFAULT 1,
    CONSTRAINT fk_story_owner FOREIGN KEY (v_id) REFERENCES profile(v_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 2. USER NOTE TABLE
CREATE TABLE IF NOT EXISTS user_note (
    u_n_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    v_id BIGINT UNSIGNED NOT NULL,              -- Link to profile(v_id)
    u_n_tags TEXT NULL,
    u_n_mention TEXT NULL,
    u_n_sound VARCHAR(255) NULL,
    u_n_media_url VARCHAR(511) NULL,
    u_n_media_type ENUM('text', 'image', 'video') DEFAULT 'text',
    u_n_upload_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    u_n_expiry_time TIMESTAMP NULL,
    u_n_status TINYINT DEFAULT 1,
    CONSTRAINT fk_note_owner FOREIGN KEY (v_id) REFERENCES profile(v_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 3. POLYMORPHIC REACTION SYSTEM
-- This table connects to both 'user_story' and 'user_note'
CREATE TABLE IF NOT EXISTS reaction (
    reaction_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    v_id BIGINT UNSIGNED NOT NULL,              -- The user who is reacting
    
    -- Connection Logic
    target_type ENUM('story', 'note', 'comment') NOT NULL, 
    target_id BIGINT UNSIGNED NOT NULL,         -- Stores either u_s_id or u_n_id
    
    reaction_type VARCHAR(50) NOT NULL,         -- 'like', 'fire', '❤️', etc.
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_react_user FOREIGN KEY (v_id) REFERENCES profile(v_id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_reaction (v_id, target_type, target_id)
) ENGINE=InnoDB;

-- 4. COMMENT SYSTEM (Also connected to Stories and Notes)
CREATE TABLE IF NOT EXISTS comment (
    comment_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    v_id BIGINT UNSIGNED NOT NULL,
    target_type ENUM('story', 'note') NOT NULL,
    target_id BIGINT UNSIGNED NOT NULL,         -- Stores either u_s_id or u_n_id
    parent_comment_id BIGINT UNSIGNED NULL,     -- For nested replies
    comment_text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_comment_user FOREIGN KEY (v_id) REFERENCES profile(v_id) ON DELETE CASCADE,
    CONSTRAINT fk_comment_nest FOREIGN KEY (parent_comment_id) REFERENCES comment(comment_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 5. INDEXES FOR SPEED
CREATE INDEX idx_react_lookup ON reaction (target_type, target_id);
CREATE INDEX idx_comment_lookup ON comment (target_type, target_id);

SET FOREIGN_KEY_CHECKS = 1;