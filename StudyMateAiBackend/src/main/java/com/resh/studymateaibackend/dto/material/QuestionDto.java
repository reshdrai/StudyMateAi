package com.resh.studymateaibackend.dto.material;

import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class QuestionDto {
    private String question;
    private String answer;
    private String difficulty;
}