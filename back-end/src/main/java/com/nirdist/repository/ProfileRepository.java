package com.nirdist.repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.nirdist.entity.Profile;

@Repository
public interface ProfileRepository extends JpaRepository<Profile, Long> {
    Optional<Profile> findByUsername(String username);

    Optional<Profile> findByPhoneNumber(String phoneNumber);

    List<Profile> findByPhoneNumberIn(Collection<String> phoneNumbers);

    Optional<Profile> findByFirebaseUid(String firebaseUid);

        @Query("""
                        select p from Profile p
                        where (:excludeUserId is null or p.vId <> :excludeUserId)
                            and (
                                lower(p.displayName) like lower(concat('%', :query, '%'))
                                or lower(p.username) like lower(concat('%', :query, '%'))
                                or lower(coalesce(p.email, '')) like lower(concat('%', :query, '%'))
                                or lower(p.phoneNumber) like lower(concat('%', :query, '%'))
                            )
                        order by lower(p.displayName) asc, lower(p.username) asc
                        """)
        List<Profile> searchProfiles(@Param("query") String query, @Param("excludeUserId") Long excludeUserId);
}