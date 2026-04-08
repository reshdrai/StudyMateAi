package com.resh.studymateaibackend.repository;

import com.resh.studymateaibackend.entity.StudyTask;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface StudyTaskRepository extends JpaRepository<StudyTask, Long> {

    int countByUserIdAndDueDate(Long userId, LocalDate dueDate);

    int countByUserIdAndDueDateAndStatus(Long userId, LocalDate dueDate, String status);

    Optional<StudyTask> findFirstByUserIdAndStatusInOrderByStartTimeAsc(
            Long userId,
            List<String> statuses
    );

    List<StudyTask> findByUserIdOrderByStartTimeAsc(Long userId);
}