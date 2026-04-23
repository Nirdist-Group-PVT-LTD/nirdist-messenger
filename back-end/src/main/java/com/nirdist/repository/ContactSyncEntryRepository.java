package com.nirdist.repository;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.nirdist.entity.ContactSyncEntry;

@Repository
public interface ContactSyncEntryRepository extends JpaRepository<ContactSyncEntry, Long> {

    List<ContactSyncEntry> findByProfileVId(Long profileVId);

    List<ContactSyncEntry> findByProfileVIdAndMatchedProfileVIdIsNotNull(Long profileVId);

    void deleteByProfileVId(Long profileVId);
}