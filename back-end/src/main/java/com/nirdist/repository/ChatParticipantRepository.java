package com.nirdist.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.nirdist.entity.ChatParticipant;

@Repository
public interface ChatParticipantRepository extends JpaRepository<ChatParticipant, Long> {
    List<ChatParticipant> findByRoomId(Long roomId);

    List<ChatParticipant> findByParticipantVId(Long participantVId);

    Optional<ChatParticipant> findByRoomIdAndParticipantVId(Long roomId, Long participantVId);

    boolean existsByRoomIdAndParticipantVId(Long roomId, Long participantVId);
}