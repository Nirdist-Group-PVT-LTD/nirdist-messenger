package com.nirdist.repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.nirdist.entity.FriendRequest;

@Repository
public interface FriendRequestRepository extends JpaRepository<FriendRequest, Long> {

    Optional<FriendRequest> findByRequesterVIdAndAddresseeVIdAndRequestStatus(Long requesterVId, Long addresseeVId, String requestStatus);

  boolean existsByRequesterVIdAndAddresseeVIdAndRequestStatus(Long requesterVId, Long addresseeVId, String requestStatus);

    boolean existsByRequesterVIdAndAddresseeVIdAndRequestStatusIn(Long requesterVId, Long addresseeVId, Collection<String> requestStatuses);

    @Query("""
            select fr from FriendRequest fr
            where (fr.requesterVId = :userId or fr.addresseeVId = :userId)
              and fr.requestStatus = 'ACCEPTED'
            order by fr.updatedAt desc
            """)
    List<FriendRequest> findAcceptedConnectionsForUser(@Param("userId") Long userId);

    @Query("""
            select fr from FriendRequest fr
            where (fr.requesterVId = :userId or fr.addresseeVId = :userId)
              and fr.requestStatus in ('PENDING', 'ACCEPTED')
            order by fr.updatedAt desc
            """)
    List<FriendRequest> findActiveConnectionsForUser(@Param("userId") Long userId);
}