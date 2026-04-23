package com.nirdist.entity;

import java.time.OffsetDateTime;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

@Entity
@Table(
        name = "contact_sync_entry",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_contact_sync_profile_phone", columnNames = {"profile_v_id", "normalized_phone"})
        }
)
public class ContactSyncEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "sync_entry_id")
    private Long syncEntryId;

    @Column(name = "profile_v_id", nullable = false)
    private Long profileVId;

    @Column(name = "contact_name")
    private String contactName;

    @Column(name = "contact_phone", nullable = false, length = 100)
    private String contactPhone;

    @Column(name = "normalized_phone", nullable = false, length = 40)
    private String normalizedPhone;

    @Column(name = "matched_profile_v_id")
    private Long matchedProfileVId;

    @Column(name = "source", nullable = false, length = 20)
    private String source;

    @Column(name = "created_at", nullable = false, updatable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    public ContactSyncEntry() {
    }

    public Long getSyncEntryId() {
        return syncEntryId;
    }

    public void setSyncEntryId(Long syncEntryId) {
        this.syncEntryId = syncEntryId;
    }

    public Long getProfileVId() {
        return profileVId;
    }

    public void setProfileVId(Long profileVId) {
        this.profileVId = profileVId;
    }

    public String getContactName() {
        return contactName;
    }

    public void setContactName(String contactName) {
        this.contactName = contactName;
    }

    public String getContactPhone() {
        return contactPhone;
    }

    public void setContactPhone(String contactPhone) {
        this.contactPhone = contactPhone;
    }

    public String getNormalizedPhone() {
        return normalizedPhone;
    }

    public void setNormalizedPhone(String normalizedPhone) {
        this.normalizedPhone = normalizedPhone;
    }

    public Long getMatchedProfileVId() {
        return matchedProfileVId;
    }

    public void setMatchedProfileVId(Long matchedProfileVId) {
        this.matchedProfileVId = matchedProfileVId;
    }

    public String getSource() {
        return source;
    }

    public void setSource(String source) {
        this.source = source;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(OffsetDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public OffsetDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(OffsetDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    @PrePersist
    protected void onCreate() {
        OffsetDateTime now = OffsetDateTime.now();
        if (createdAt == null) {
            createdAt = now;
        }
        updatedAt = now;
        if (source == null || source.isBlank()) {
            source = "PHONEBOOK";
        }
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = OffsetDateTime.now();
    }
}