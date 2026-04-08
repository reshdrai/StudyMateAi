package com.resh.studymateaibackend.dto.study;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class QuizResultDto {
    private int totalQuestions;
    private int correctAnswers;
    private double scorePercent;
    private List<String> weakTopics;
}