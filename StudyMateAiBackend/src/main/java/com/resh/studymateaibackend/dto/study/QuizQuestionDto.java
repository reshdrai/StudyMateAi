package com.resh.studymateaibackend.dto.study;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class QuizQuestionDto {
    private String question;
    private String answer;
    private String topic;
    private List<String> options;
}