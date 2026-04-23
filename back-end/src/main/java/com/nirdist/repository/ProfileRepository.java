package com.nirdist.repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.nirdist.entity.Profile;

@Repository
public interface ProfileRepository extends JpaRepository<Profile, Long> {
    Optional<Profile> findByUsername(String username);

    Optional<Profile> findByPhoneNumber(String phoneNumber);

    List<Profile> findByPhoneNumberIn(Collection<String> phoneNumbers);

    Optional<Profile> findByFirebaseUid(String firebaseUid);
}