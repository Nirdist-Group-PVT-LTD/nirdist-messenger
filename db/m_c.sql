-- ======================================================
-- UNIFIED CHAT & PROFILE SCHEMA (MySQL/MariaDB)
-- ======================================================

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS chat_participant;
DROP TABLE IF EXISTS chat_room;
DROP TABLE IF EXISTS profile;
-- ... (other component tables)
SET FOREIGN_KEY_CHECKS = 1;

-- 1. PROFILE TABLE (The Anchor)
CREATE TABLE IF NOT EXISTS profile (
    v_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    p_p_id BIGINT UNSIGNED NULL, 
    p_b_id INT UNSIGNED NULL, -- Standardized to match component PKs
    v_n_id BIGINT UNSIGNED NULL, 
    v_name_id BIGINT UNSIGNED NULL, 
    v_bio_id BIGINT UNSIGNED NULL, 
    v_bl_id BIGINT UNSIGNED NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. CHAT ROOMS
CREATE TABLE IF NOT EXISTS chat_room (
    room_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    room_name VARCHAR(255) NULL,
    room_type ENUM('private', 'group') DEFAULT 'private',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 3. CHAT PARTICIPANTS (Your new table)
CREATE TABLE IF NOT EXISTS chat_participant (
    participant_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    room_id BIGINT UNSIGNED NOT NULL,
    v_id BIGINT UNSIGNED NOT NULL,               -- Link to your 'profile' table
    role ENUM('member', 'admin', 'owner') DEFAULT 'member',
    last_read_msg_id BIGINT UNSIGNED NULL,       -- Essential for 'Unread Message' logic
    is_muted BOOLEAN DEFAULT FALSE,              -- Notification toggle
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_room_p FOREIGN KEY (room_id) REFERENCES chat_room(room_id) ON DELETE CASCADE,
    CONSTRAINT fk_profile_p FOREIGN KEY (v_id) REFERENCES profile(v_id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_room (room_id, v_id)  -- Prevents duplicate entries
) ENGINE=InnoDB;

-- 4. MESSAGES (Optional but recommended for the last_read_msg_id reference)
CREATE TABLE IF NOT EXISTS chat_message (
    message_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    room_id BIGINT UNSIGNED NOT NULL,
    sender_v_id BIGINT UNSIGNED NOT NULL,
    message_text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_msg_room FOREIGN KEY (room_id) REFERENCES chat_room(room_id) ON DELETE CASCADE,
    CONSTRAINT fk_msg_sender FOREIGN KEY (sender_v_id) REFERENCES profile(v_id) ON DELETE CASCADE
) ENGINE=InnoDB;