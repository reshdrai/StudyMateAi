package com.resh.studymateaibackend.dto.study;

import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class QuizAnswerDto {
    private String question;
    private String userAnswer;
}