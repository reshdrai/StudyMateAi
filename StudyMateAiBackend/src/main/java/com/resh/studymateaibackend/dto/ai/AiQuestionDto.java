package com.resh.studymateaibackend.dto.ai;

import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AiQuestionDto {
    private String question;
    private String answer;
    private String difficulty;
}