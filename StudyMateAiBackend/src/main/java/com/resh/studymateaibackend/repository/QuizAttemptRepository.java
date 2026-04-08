package com.resh.studymateaibackend.repository;

import com.resh.studymateaibackend.entity.QuizAttempt;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface QuizAttemptRepository extends JpaRepository<QuizAttempt, Long> {
    List<QuizAttempt> findByUserIdOrderByStartedAtDesc(Long userId);
}