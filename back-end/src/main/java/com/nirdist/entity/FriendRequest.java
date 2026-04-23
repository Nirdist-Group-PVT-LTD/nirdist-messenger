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
        name = "friend_request",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_friend_request_pair_status", columnNames = {"requester_v_id", "addressee_v_id", "request_status"})
        }
)
public class FriendRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "request_id")
    private Long requestId;

    @Column(name = "requester_v_id", nullable = false)
    private Long requesterVId;

    @Column(name = "addressee_v_id", nullable = false)
    private Long addresseeVId;

    @Column(name = "request_message")
    private String requestMessage;

    @Column(name = "request_status", nullable = false, length = 20)
    private String requestStatus;

    @Column(name = "responded_by_v_id")
    private Long respondedByVId;

    @Column(name = "requested_at", nullable = false, updatable = false)
    private OffsetDateTime requestedAt;

    @Column(name = "responded_at")
    private OffsetDateTime respondedAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    public FriendRequest() {
    }

    public Long getRequestId() {
        return requestId;
    }

    public void setRequestId(Long requestId) {
        this.requestId = requestId;
    }

    public Long getRequesterVId() {
        return requesterVId;
    }

    public void setRequesterVId(Long requesterVId) {
        this.requesterVId = requesterVId;
    }

    public Long getAddresseeVId() {
        return addresseeVId;
    }

    public void setAddresseeVId(Long addresseeVId) {
        this.addresseeVId = addresseeVId;
    }

    public String getRequestMessage() {
        return requestMessage;
    }

    public void setRequestMessage(String requestMessage) {
        this.requestMessage = requestMessage;
    }

    public String getRequestStatus() {
        return requestStatus;
    }

    public void setRequestStatus(String requestStatus) {
        this.requestStatus = requestStatus;
    }

    public Long getRespondedByVId() {
        return respondedByVId;
    }

    public void setRespondedByVId(Long respondedByVId) {
        this.respondedByVId = respondedByVId;
    }

    public OffsetDateTime getRequestedAt() {
        return requestedAt;
    }

    public void setRequestedAt(OffsetDateTime requestedAt) {
        this.requestedAt = requestedAt;
    }

    public OffsetDateTime getRespondedAt() {
        return respondedAt;
    }

    public void setRespondedAt(OffsetDateTime respondedAt) {
        this.respondedAt = respondedAt;
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
        if (requestedAt == null) {
            requestedAt = now;
        }
        updatedAt = now;
        if (requestStatus == null || requestStatus.isBlank()) {
            requestStatus = "PENDING";
        }
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = OffsetDateTime.now();
    }
}