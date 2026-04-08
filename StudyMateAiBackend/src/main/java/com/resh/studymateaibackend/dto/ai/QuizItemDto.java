package com.resh.studymateaibackend.dto.ai;

import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class QuizItemDto {
    private String question;
    private String optionA;
    private String optionB;
    private String optionC;
    private String correctOption;
    private String explanation;
    private String topicLabel;
    private String subtopicLabel;
}