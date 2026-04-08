package com.resh.studymateaibackend.repository;

import com.resh.studymateaibackend.entity.StudyGoal;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface StudyGoalRepository extends JpaRepository<StudyGoal, Long> {
    List<StudyGoal> findByUserIdAndStatus(Long userId, String status);
}