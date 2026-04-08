package com.resh.studymateaibackend.repository;

import com.resh.studymateaibackend.entity.AiTip;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface AiTipRepository extends JpaRepository<AiTip, Long> {
    Optional<AiTip> findFirstByUserIdOrderByCreatedAtDesc(Long userId);
}