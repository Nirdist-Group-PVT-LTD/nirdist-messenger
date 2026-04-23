package com.nirdist.entity;

import java.time.OffsetDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

@Entity
@Table(
        name = "chat_participant",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_chat_participant_room_v_id", columnNames = {"room_id", "v_id"})
        }
)
public class ChatParticipant {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "participant_id")
    private Long participantId;

    @Column(name = "room_id", nullable = false)
    private Long roomId;

    @Column(name = "v_id", nullable = false)
    private Long participantVId;

    @Column(name = "role", nullable = false, length = 20)
    private String role;

    @Column(name = "last_read_msg_id")
    private Long lastReadMsgId;

    @Column(name = "is_muted", nullable = false)
    private Boolean isMuted;

    @Column(name = "joined_at", nullable = false, updatable = false)
    private OffsetDateTime joinedAt;

    public ChatParticipant() {
    }

    public Long getParticipantId() {
        return participantId;
    }

    public void setParticipantId(Long participantId) {
        this.participantId = participantId;
    }

    public Long getRoomId() {
        return roomId;
    }

    public void setRoomId(Long roomId) {
        this.roomId = roomId;
    }

    public Long getParticipantVId() {
        return participantVId;
    }

    public void setParticipantVId(Long participantVId) {
        this.participantVId = participantVId;
    }

    public String getRole() {
        return role;
    }

    public void setRole(String role) {
        this.role = role;
    }

    public Long getLastReadMsgId() {
        return lastReadMsgId;
    }

    public void setLastReadMsgId(Long lastReadMsgId) {
        this.lastReadMsgId = lastReadMsgId;
    }

    public Boolean getIsMuted() {
        return isMuted;
    }

    public void setIsMuted(Boolean muted) {
        isMuted = muted;
    }

    public OffsetDateTime getJoinedAt() {
        return joinedAt;
    }

    public void setJoinedAt(OffsetDateTime joinedAt) {
        this.joinedAt = joinedAt;
    }

    @PrePersist
    protected void onCreate() {
        if (role == null || role.isBlank()) {
            role = "member";
        }
        if (isMuted == null) {
            isMuted = Boolean.FALSE;
        }
        if (joinedAt == null) {
            joinedAt = OffsetDateTime.now();
        }
    }
}