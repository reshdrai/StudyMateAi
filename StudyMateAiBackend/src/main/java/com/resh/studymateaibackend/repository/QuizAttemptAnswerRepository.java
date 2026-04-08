package com.resh.studymateaibackend.repository;

import com.resh.studymateaibackend.entity.QuizAttemptAnswer;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface QuizAttemptAnswerRepository extends JpaRepository<QuizAttemptAnswer, Long> {
    List<QuizAttemptAnswer> findByQuizAttemptId(Long quizAttemptId);
}